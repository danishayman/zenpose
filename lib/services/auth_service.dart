import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'auth_context.dart';

enum AuthStatus { unconfigured, unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? email;

  const AuthState({
    required this.status,
    required this.userId,
    required this.email,
  });

  const AuthState.unconfigured()
    : status = AuthStatus.unconfigured,
      userId = null,
      email = null;

  const AuthState.unauthenticated()
    : status = AuthStatus.unauthenticated,
      userId = null,
      email = null;

  const AuthState.authenticated({required this.userId, required this.email})
    : status = AuthStatus.authenticated;

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

/// Supabase-backed auth orchestration.
class AuthService {
  AuthService._internal();

  static final AuthService instance = AuthService._internal();

  final ValueNotifier<AuthState> authState = ValueNotifier<AuthState>(
    const AuthState.unauthenticated(),
  );

  StreamSubscription<supa.AuthState>? _authSub;
  bool _configured = false;

  void configure({required bool enabled}) {
    _configured = enabled;
    if (!enabled) {
      AuthContext.setActiveUserId(null);
      authState.value = const AuthState.unconfigured();
      _authSub?.cancel();
      _authSub = null;
      return;
    }
    _bindAuthStream();
  }

  Future<AuthState> restoreSession() async {
    if (!_configured) {
      authState.value = const AuthState.unconfigured();
      return authState.value;
    }

    final user = supa.Supabase.instance.client.auth.currentUser;
    if (user == null) {
      AuthContext.setActiveUserId(null);
      authState.value = const AuthState.unauthenticated();
      return authState.value;
    }

    AuthContext.setActiveUserId(user.id);
    authState.value = AuthState.authenticated(
      userId: user.id,
      email: user.email,
    );
    return authState.value;
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    _ensureConfigured();
    await supa.Supabase.instance.client.auth.signUp(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _ensureConfigured();
    await supa.Supabase.instance.client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signInWithGoogle() async {
    _ensureConfigured();
    await supa.Supabase.instance.client.auth.signInWithOAuth(
      supa.OAuthProvider.google,
    );
  }

  Future<void> signOut() async {
    if (_configured) {
      await supa.Supabase.instance.client.auth.signOut();
    }
    AuthContext.setActiveUserId(null);
    authState.value = const AuthState.unauthenticated();
  }

  void _ensureConfigured() {
    if (!_configured) {
      throw StateError(
        'Supabase is not configured. Pass SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.',
      );
    }
  }

  void _bindAuthStream() {
    _authSub?.cancel();
    _authSub = supa.Supabase.instance.client.auth.onAuthStateChange.listen((
      event,
    ) {
      final user = event.session?.user;
      if (user == null) {
        AuthContext.setActiveUserId(null);
        authState.value = const AuthState.unauthenticated();
        return;
      }
      AuthContext.setActiveUserId(user.id);
      authState.value = AuthState.authenticated(
        userId: user.id,
        email: user.email,
      );
    });
  }
}
