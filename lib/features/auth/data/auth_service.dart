import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/notification_service.dart';
import 'registration_draft.dart';

class AuthFlowException implements Exception {
  const AuthFlowException(this.message, {this.verificationRequired = false});

  final String message;
  final bool verificationRequired;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final StreamController<int> _profileChanges =
      StreamController<int>.broadcast();
  int _profileRevision = 0;
  RegistrationDraft? _pendingDraft;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get userChanges => _auth.userChanges();
  Stream<int> get profileChanges => _profileChanges.stream;
  RegistrationDraft? get pendingDraft => _pendingDraft;

  Future<void> createAccount({
    required String email,
    required String password,
    required RegistrationDraft draft,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _pendingDraft = draft;
      await credential.user!.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw AuthFlowException(_authMessage(error));
    } catch (_) {
      rethrow;
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      await user.reload();
      if (!(_auth.currentUser?.emailVerified ?? false)) {
        await _auth.signOut();
        throw const AuthFlowException(
          'Verify your email before signing in. You can resend the verification link below.',
          verificationRequired: true,
        );
      }
    } on FirebaseAuthException catch (error) {
      throw AuthFlowException(_authMessage(error));
    }
  }

  Future<void> resendVerification({
    String? email,
    String? password,
  }) async {
    try {
      if (_auth.currentUser == null && email != null && password != null) {
        await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      }
      final user = _auth.currentUser;
      if (user == null) {
        throw const AuthFlowException(
            'Sign in again to resend the verification email.');
      }
      await user.reload();
      final refreshed = _auth.currentUser!;
      if (refreshed.emailVerified) {
        return;
      }
      await refreshed.sendEmailVerification();
      await _auth.signOut();
    } on FirebaseAuthException catch (error) {
      throw AuthFlowException(_authMessage(error));
    }
  }

  Future<void> completePendingRegistration() async {
    final draft = _pendingDraft;
    if (draft == null) return;
    await completeRegistration(draft);
  }

  Future<void> completeRegistration(RegistrationDraft draft) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFlowException(
          'Your sign-in expired. Please sign in again.');
    }
    await user.reload();
    final verifiedUser = _auth.currentUser!;
    if (!verifiedUser.emailVerified) {
      throw const AuthFlowException(
          'Verify your email before finishing registration.');
    }
    // Firestore rules inspect the email_verified ID-token claim. Reloading the
    // Auth user updates emailVerified locally; force-refresh the token too.
    await verifiedUser.getIdToken(true);

    final profileRef = _firestore.collection('users').doc(verifiedUser.uid);
    final profile = <String, Object?>{
      'userId': verifiedUser.uid,
      'fullName': draft.fullName.trim(),
      'email': verifiedUser.email,
      'mobile': draft.mobile.trim(),
      'role': draft.roleValue,
      'societyId': draft.societyId.trim().toUpperCase(),
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (draft.role == AccountRole.admin) {
        final societyRef = _firestore
            .collection('societies')
            .doc(draft.societyId.trim().toUpperCase());
        await _firestore.runTransaction((transaction) async {
          final existing = await transaction.get(societyRef);
          if (existing.exists) {
            throw const AuthFlowException(
                'That Society ID is already registered.');
          }
          transaction.set(societyRef, {
            'societyId': societyRef.id,
            'name': draft.societyName.trim(),
            'address': draft.address.trim(),
            'contactNumber': draft.contactNumber.trim(),
            'email': verifiedUser.email,
            'createdBy': verifiedUser.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          transaction.set(profileRef, profile);
          final logRef = _firestore.collection('activity_logs').doc();
          transaction.set(logRef, {
            'societyId': societyRef.id,
            'userId': verifiedUser.uid,
            'action': 'society_created',
            'description':
                'Society ${draft.societyName.trim()} was registered.',
            'createdAt': FieldValue.serverTimestamp(),
          });
        });
      } else {
        final flatId = draft.flatId.trim();
        if (flatId.isEmpty) {
          throw const AuthFlowException(
            'Select an available flat before continuing registration.',
          );
        }
        final flatRef = _firestore.collection('flats').doc(flatId);
        await _firestore.runTransaction((transaction) async {
          final existingProfile = await transaction.get(profileRef);
          if (existingProfile.exists) return;
          final flat = await transaction.get(flatRef);
          final flatData = flat.data();
          if (!flat.exists ||
              flatData?['status'] != 'Vacant' ||
              flatData?['societyId'] != draft.societyId.trim().toUpperCase()) {
            throw const AuthFlowException(
              'That flat is no longer available in this society. Refresh the flat list and select another available flat.',
            );
          }
          transaction.set(profileRef, {
            ...profile,
            'flatId': flatRef.id,
            'flatNumber': flatData?['flatNumber'] ?? draft.flatNumber.trim(),
          });
          transaction.update(flatRef, {
            'residentId': verifiedUser.uid,
            'status': 'Occupied',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          final logRef = _firestore.collection('activity_logs').doc();
          transaction.set(logRef, {
            'societyId': draft.societyId.trim().toUpperCase(),
            'userId': verifiedUser.uid,
            'action': 'resident_registered',
            'description':
                '${draft.fullName.trim()} joined flat ${draft.flatNumber.trim()}.',
            'createdAt': FieldValue.serverTimestamp(),
          });
        });
      }
    } on FirebaseException catch (error) {
      throw AuthFlowException(_firestoreMessage(error));
    }
    _pendingDraft = null;
    _profileChanges.add(++_profileRevision);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> profileFor(String uid) =>
      _firestore.collection('users').doc(uid).get();

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      // Keep account existence private and present a neutral confirmation.
      if (error.code == 'user-not-found' || error.code == 'invalid-email') {
        return;
      }
      throw AuthFlowException(_authMessage(error));
    }
  }

  Future<void> signOut() async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      await societyNotificationService.unbindUser(userId);
    }
    await _auth.signOut();
  }

  String _authMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'An account already uses this email. Try signing in instead.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'weak-password':
        return 'Choose a stronger password with at least 8 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'The email or password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a little and try again.';
      case 'network-request-failed':
        return 'Could not connect. Check your internet connection and try again.';
      default:
        return 'Authentication could not be completed. Please try again.';
    }
  }

  String _firestoreMessage(FirebaseException error) {
    if (error.code == 'permission-denied') {
      return 'Registration was blocked by the current Firebase security rules. Deploy the SocietyConnect Firestore rules and try again.';
    }
    if (error.code == 'unavailable') {
      return 'Society data is temporarily unavailable. Check your connection and try again.';
    }
    return 'We could not save your society profile. Please try again.';
  }
}

final authService = AuthService();
