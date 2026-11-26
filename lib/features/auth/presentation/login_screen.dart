import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import 'auth_widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await authService.signIn(email: _email.text, password: _password.text);
    } on AuthFlowException catch (error) {
      if (!mounted) return;
      if (error.verificationRequired) {
        _showVerificationResend();
      } else {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Could not sign in. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showVerificationResend() async {
    final resend = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verify your email'),
        content: const Text(
          'Your email is not verified yet. Send a fresh verification link to this address?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Resend link'),
          ),
        ],
      ),
    );
    if (resend != true || !mounted) return;
    try {
      await authService.resendVerification(
          email: _email.text, password: _password.text);
      if (mounted) {
        _showMessage(
            'If the account is eligible, a verification link has been sent.');
      }
    } on AuthFlowException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (validEmail(email) != null) {
      _showMessage('Enter your registered email address first.');
      return;
    }
    try {
      await authService.sendPasswordReset(email);
      if (mounted) {
        _showMessage(
            'If an account exists for that email, a reset link has been sent.');
      }
    } on AuthFlowException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => AuthFrame(
        title: 'Welcome back',
        subtitle: 'Sign in to stay connected with your society.',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                controller: _email,
                label: 'Email address',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: validEmail,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _password,
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                obscureText: _hidePassword,
                suffix: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(_hidePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                ),
                validator: (value) => requiredField(value, label: 'Password'),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : _forgotPassword,
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _signIn,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign in'),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RegisterScreen(),
                          ),
                        ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Create an account'),
                ),
              ),
            ],
          ),
        ),
      );
}
