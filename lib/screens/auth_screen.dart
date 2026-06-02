import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../services/auth_service.dart';
import '../theme/zen_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService.instance;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isRegisterMode = false;
  bool _loading = false;
  String? _error;

  String _formatError(Object error, {required bool isRegisterMode}) {
    if (error is StateError) {
      return error.message.toString();
    }

    if (error is supa.AuthWeakPasswordException) {
      return 'Password is too weak. Use at least 6 characters with a mix of letters and numbers.';
    }

    if (error is supa.AuthException) {
      final code = (error.code ?? '').toLowerCase();
      final message = error.message.toLowerCase();

      if (code == 'invalid_credentials') {
        return 'Incorrect email or password. Please try again.';
      }

      if (code == 'email_not_confirmed') {
        return 'Please verify your email address before signing in.';
      }

      if (code == 'over_request_rate_limit' ||
          code == 'too_many_requests' ||
          code == 'rate_limit_exceeded' ||
          message.contains('rate limit')) {
        return 'Too many attempts. Please wait a moment and try again.';
      }

      if (code == 'user_already_exists' ||
          code == 'email_exists' ||
          (isRegisterMode && message.contains('already'))) {
        return 'An account with this email already exists. Please sign in instead.';
      }

      if (code == 'user_not_found' ||
          (!isRegisterMode && message.contains('not found'))) {
        return 'No account was found for this email. Please sign up first.';
      }

      if (code == 'email_address_invalid' ||
          code == 'validation_failed' ||
          message.contains('invalid email')) {
        return 'Please enter a valid email address.';
      }

      final safeMessage = error.message.trim();
      if (safeMessage.isNotEmpty) {
        return safeMessage;
      }
    }

    final raw = error.toString();
    return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailAuth() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isRegisterMode && username.isEmpty) {
      setState(() => _error = 'Please choose a username.');
      return;
    }

    if (_isRegisterMode && username.length < 3) {
      setState(() => _error = 'Username must be at least 3 characters.');
      return;
    }

    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }

    if (password.isEmpty) {
      setState(() => _error = 'Please enter your password.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isRegisterMode) {
        await _authService.signUpWithEmail(
          email: email,
          password: password,
          username: username,
        );
      } else {
        await _authService.signInWithEmail(email: email, password: password);
      }
    } catch (e) {
      setState(() => _error = _formatError(e, isRegisterMode: _isRegisterMode));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      setState(() => _error = _formatError(e, isRegisterMode: false));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: ZenDecor.gradientBackdrop(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  decoration: ZenDecor.elevatedCard(),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isRegisterMode ? 'Create account' : 'Welcome back',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isRegisterMode
                            ? 'Create your account to sync progress and personalize your profile.'
                            : 'Sign in to sync your progress across devices.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 18),
                      if (_isRegisterMode) ...[
                        TextField(
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFB33A3A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submitEmailAuth,
                          child: Text(_isRegisterMode ? 'Sign Up' : 'Sign In'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _signInWithGoogle,
                          icon: const Icon(
                            Icons.g_mobiledata_rounded,
                            size: 28,
                          ),
                          label: const Text('Continue with Google'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() {
                                _isRegisterMode = !_isRegisterMode;
                                _error = null;
                              }),
                        child: Text(
                          _isRegisterMode
                              ? 'Already have an account? Sign in'
                              : "Don't have an account? Sign up",
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
