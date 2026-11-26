import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    await societyNotificationService.initialize();
  } catch (error) {
    debugPrint('SocietyConnect notifications could not initialize: $error');
  }
  runApp(const SocietyConnectApp());
}
