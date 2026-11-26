import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_controller.dart';
import 'features/auth/presentation/auth_gate.dart';

class SocietyConnectApp extends StatelessWidget {
  const SocietyConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appThemeController,
      builder: (context, _) => MaterialApp(
        title: 'SocietyConnect',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: appThemeController.themeMode,
        home: const AuthGate(),
      ),
    );
  }
}
