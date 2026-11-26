import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class SocietyNotificationService {
  SocietyNotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'society_updates',
    'Society updates',
    description: 'Notices, maintenance, complaints, events and bookings.',
    importance: Importance.high,
  );

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FlutterLocalNotificationsPlugin _localNotifications;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _registrationSubscription;
  String? _boundUserId;
  String? _installationId;
  Future<void> _pendingRegistrationWrite = Future<void>.value();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_societyconnect'),
    );
    await _localNotifications.initialize(settings: settings);
    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
    _foregroundSubscription =
        FirebaseMessaging.onMessage.listen(_showForeground);
    _initialized = true;
  }

  Future<void> bindUser(String userId) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await initialize();
    if (_boundUserId != null && _boundUserId != userId) {
      await unbindUser(_boundUserId!);
    }
    _boundUserId = userId;
    final permission = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (permission.authorizationStatus == AuthorizationStatus.denied) return;

    await _registrationSubscription?.cancel();
    _registrationSubscription = _messaging.onRegistered.listen((fid) {
      _installationId = fid;
      _pendingRegistrationWrite = _saveInstallationId(userId, fid);
      _pendingRegistrationWrite.catchError((Object error) {
        debugPrint('Could not refresh SocietyConnect registration: $error');
      });
    });
    await _messaging.register();
  }

  Future<void> unbindUser(String userId) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final wasBound = _boundUserId == userId;
    if (!wasBound) return;
    await _registrationSubscription?.cancel();
    _registrationSubscription = null;
    _boundUserId = null;
    try {
      await _pendingRegistrationWrite;
    } catch (_) {
      // Continue clearing the FCM registration and signing out.
    }
    final fid = _installationId;
    try {
      await _messaging.unregister();
    } catch (error) {
      debugPrint('Could not unregister SocietyConnect notifications: $error');
    }
    try {
      if (fid != null) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('fcm_tokens')
            .doc(fid)
            .delete();
      }
    } catch (error) {
      debugPrint('Could not remove SocietyConnect installation ID: $error');
    } finally {
      _installationId = null;
    }
  }

  Future<void> _saveInstallationId(String userId, String fid) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('fcm_tokens')
        .doc(fid)
        .set({
      'fid': fid,
      'platform': 'android',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: notification.title ?? 'SocietyConnect',
      body: notification.body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'society_updates',
          'Society updates',
          channelDescription:
              'Notices, maintenance, complaints, events and bookings.',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_societyconnect',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _registrationSubscription?.cancel();
  }
}

final societyNotificationService = SocietyNotificationService();
