import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AppThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void loadSavedMode(Object? value) {
    final saved = switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    if (_themeMode == saved) return;
    _themeMode = saved;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    final previous = _themeMode;
    _themeMode = mode;
    notifyListeners();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'themeMode': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      _themeMode = previous;
      notifyListeners();
      rethrow;
    }
  }
}

final appThemeController = AppThemeController();
