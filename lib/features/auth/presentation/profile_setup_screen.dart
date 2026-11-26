import 'package:flutter/material.dart';

import 'auth_widgets.dart';
import 'register_screen.dart';

class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context) => AuthFrame(
        title: 'Finish your setup',
        subtitle:
            'Your email is verified, but your SocietyConnect profile is not complete yet.',
        child: FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const RegisterScreen(completeExistingAccount: true),
            ),
          ),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Text('Continue profile setup'),
          ),
        ),
      );
}
