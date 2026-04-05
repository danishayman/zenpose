import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'auth_context.dart';

enum AuthStatus { unconfigured, unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? email;
  final String? displayName;

  const AuthState({
    required this.status,
    required this.userId,
    required this.email,
    required this.displayName,
  });

  const AuthState.unconfigured()
    : status = AuthStatus.unconfigured,
      userId = null,
      email = null,
      displayName = null;

  const AuthState.unauthenticated()
    : status = AuthStatus.unauthenticated,
      userId = null,
      email = null,
      displayName = null;

  const AuthState.authenticated({
    required this.userId,
    required this.email,
    required this.displayName,
  }) : status = AuthStatus.authenticated;

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
  String? _unconfiguredReason;

  void configure({required bool enabled, String? unconfiguredReason}) {
    _configured = enabled;
    _unconfiguredReason = unconfiguredReason;
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
      displayName: _extractDisplayName(user),
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
      AuthContext.setActiveUserId(null);
      authState.value = const AuthState.unauthenticated();
      return;
    }
    AuthContext.setActiveUserId(null);
    authState.value = const AuthState.unconfigured();
  }

  void _ensureConfigured() {
    if (!_configured) {
      throw StateError(
        _unconfiguredReason ??
            'Supabase is not configured. Pass SUPABASE_URL and '
                'SUPABASE_ANON_KEY via --dart-define-from-file=.env.',
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
        displayName: _extractDisplayName(user),
      );
    });
  }

  String? _extractDisplayName(supa.User user) {
    final metadata = user.userMetadata;
    final candidates = <Object?>[
      metadata?['full_name'],
      metadata?['name'],
      metadata?['display_name'],
      metadata?['preferred_username'],
      metadata?['user_name'],
      metadata?['username'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    final email = user.email?.trim();
    if (email == null || email.isEmpty) return null;
    final localPart = email.split('@').first.trim();
    return localPart.isEmpty ? null : localPart;
  }
}
