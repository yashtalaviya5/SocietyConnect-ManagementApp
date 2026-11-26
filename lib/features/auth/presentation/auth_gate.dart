import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import '../../../core/theme/app_theme_controller.dart';
import '../../../features/home/presentation/home_screen.dart';
import '../data/auth_service.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';
import 'verification_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authService.userChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen();
        }
        final user = snapshot.data;
        if (user == null) {
          appThemeController.loadSavedMode('system');
          return const LoginScreen();
        }
        if (!user.emailVerified) {
          return VerificationScreen(
            onVerified: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const AuthGate()),
            ),
          );
        }
        return _VerifiedProfileGate(uid: user.uid);
      },
    );
  }
}

class _VerifiedProfileGate extends StatefulWidget {
  const _VerifiedProfileGate({required this.uid});

  final String uid;

  @override
  State<_VerifiedProfileGate> createState() => _VerifiedProfileGateState();
}

class _VerifiedProfileGateState extends State<_VerifiedProfileGate> {
  late Future<Map<String, dynamic>?> _profileFuture;
  StreamSubscription<int>? _profileSubscription;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile(widget.uid);
    _profileSubscription = authService.profileChanges.listen((_) {
      if (mounted) {
        setState(() => _profileFuture = _loadProfile(widget.uid));
      }
    });
  }

  @override
  void didUpdateWidget(covariant _VerifiedProfileGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _profileFuture = _loadProfile(widget.uid);
    }
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState != ConnectionState.done) {
          return const _AuthLoadingScreen();
        }
        if (profileSnapshot.hasError) {
          final message = profileSnapshot.error is AuthFlowException
              ? (profileSnapshot.error as AuthFlowException).message
              : 'We could not load or save your profile. Check your internet connection and make sure the current SocietyConnect Firestore rules are deployed.';
          return _ProfileLoadError(
            message: message,
            onRetry: () => _retry(context),
          );
        }
        final profile = profileSnapshot.data;
        if (profile == null) return const ProfileSetupScreen();
        if (profile['isActive'] != true) {
          return const _InactiveAccountScreen();
        }
        final role = profile['role'];
        if (role != 'admin' && role != 'resident') {
          return const _ProfileLoadError();
        }
        appThemeController.loadSavedMode(profile['themeMode']);
        return HomeScreen(
          role: role as String,
          fullName: profile['fullName'] as String? ?? 'there',
          societyId: profile['societyId'] as String? ?? '',
          flatNumber: profile['flatNumber'] as String? ?? '',
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _loadProfile(String uid) async {
    final user = authService.currentUser;
    if (user == null) return null;
    final refreshed = authService.currentUser;
    if (refreshed == null || !refreshed.emailVerified) return null;
    await refreshed.getIdToken(true);
    var snapshot = await authService.profileFor(uid);
    if (!snapshot.exists && authService.pendingDraft != null) {
      await authService.completePendingRegistration();
      snapshot = await authService.profileFor(uid);
    }
    return snapshot.data();
  }

  void _retry(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AuthGate()),
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({this.onRetry, this.message});

  final VoidCallback? onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 42),
                const SizedBox(height: 12),
                Text(
                  message ?? 'We could not load your SocietyConnect profile.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: onRetry, child: const Text('Try again')),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: authService.signOut,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      );
}

class _InactiveAccountScreen extends StatelessWidget {
  const _InactiveAccountScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_off_outlined, size: 42),
                const SizedBox(height: 12),
                const Text(
                    'This account is inactive. Contact your society admin.'),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: authService.signOut,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      );
}
