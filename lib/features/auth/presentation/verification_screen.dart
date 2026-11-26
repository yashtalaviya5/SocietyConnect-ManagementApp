import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import 'auth_widgets.dart';
import 'login_screen.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({required this.onVerified, super.key});

  final VoidCallback onVerified;

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() =>
            _message = 'Your sign-in expired. Sign in again to continue.');
      }
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await user.reload();
      final updated = FirebaseAuth.instance.currentUser;
      if (updated?.emailVerified == true) {
        await updated!.getIdToken(true);
        if (mounted) {
          widget.onVerified();
        }
      } else if (mounted) {
        setState(() => _message =
            'Email is not verified yet. Open the latest verification link, then try again.');
      }
    } on AuthFlowException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not check verification. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw const AuthFlowException('Sign in again to continue.');
      }
      await user.sendEmailVerification();
      await authService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const _ResentNoticeScreen()),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() =>
            _message = error.message ?? 'Could not send the email. Try again.');
      }
    } on AuthFlowException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Could not send the email. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email =
        FirebaseAuth.instance.currentUser?.email ?? 'your email address';
    return AuthFrame(
      title: 'Check your email',
      subtitle:
          'We sent a verification link to $email. Verify your address to unlock registration.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_message != null) ...[
            Text(_message!, textAlign: TextAlign.center),
            const SizedBox(height: 14),
          ],
          FilledButton.icon(
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.mark_email_read_outlined),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 13),
              child: Text("I've verified my email"),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _resend,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Resend verification email'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : authService.signOut,
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    );
  }
}

class _ResentNoticeScreen extends StatelessWidget {
  const _ResentNoticeScreen();

  @override
  Widget build(BuildContext context) => AuthFrame(
        title: 'Check your inbox',
        subtitle:
            'If the account is eligible, a verification email has been sent. Follow its link, then sign in again.',
        child: FilledButton(
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
            (_) => false,
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Text('Return to sign in'),
          ),
        ),
      );
}
