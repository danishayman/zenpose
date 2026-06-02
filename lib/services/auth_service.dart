import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../models/account_access.dart';
import 'auth_context.dart';

enum AuthStatus { unconfigured, unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? email;
  final String? displayName;
  final AccountRole role;
  final AccountStatus accountStatus;

  const AuthState({
    required this.status,
    required this.userId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.accountStatus,
  });

  const AuthState.unconfigured()
    : status = AuthStatus.unconfigured,
      userId = null,
      email = null,
      displayName = null,
      role = AccountRole.user,
      accountStatus = AccountStatus.active;

  const AuthState.unauthenticated()
    : status = AuthStatus.unauthenticated,
      userId = null,
      email = null,
      displayName = null,
      role = AccountRole.user,
      accountStatus = AccountStatus.active;

  const AuthState.authenticated({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.accountStatus,
  }) : status = AuthStatus.authenticated;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isAdmin => role == AccountRole.admin;
  bool get isAccountActive => accountStatus == AccountStatus.active;
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
  bool get isConfigured => _configured;

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

    authState.value = await _buildAuthenticatedState(user);
    return authState.value;
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    _ensureConfigured();
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) {
      throw StateError('Please enter a username.');
    }
    await supa.Supabase.instance.client.auth.signUp(
      email: email.trim(),
      password: password,
      data: <String, dynamic>{
        'display_name': cleanUsername,
        'username': cleanUsername,
      },
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
    ) async {
      final user = event.session?.user;
      if (user == null) {
        AuthContext.setActiveUserId(null);
        authState.value = const AuthState.unauthenticated();
        return;
      }
      authState.value = await _buildAuthenticatedState(user);
    });
  }

  Future<AuthState> _buildAuthenticatedState(supa.User user) async {
    AuthContext.setActiveUserId(user.id);
    final profile = await _fetchUserProfile(user.id);
    final email =
        _nonEmpty(profile?['email'])?.trim() ?? _nonEmpty(user.email)?.trim();
    final profileDisplayName = _nonEmpty(profile?['display_name'])?.trim();
    final displayName = profileDisplayName ?? _extractDisplayName(user);
    final role = AccountRoleX.fromDbValue(profile?['role']?.toString());
    final accountStatus = AccountStatusX.fromDbValue(
      profile?['status']?.toString(),
    );
    return AuthState.authenticated(
      userId: user.id,
      email: email,
      displayName: displayName,
      role: role,
      accountStatus: accountStatus,
    );
  }

  Future<Map<String, dynamic>?> _fetchUserProfile(String userId) async {
    if (!_configured) return null;
    try {
      final payload = await supa.Supabase.instance.client
          .from('user_profiles')
          .select('email, display_name, role, status')
          .eq('user_id', userId)
          .maybeSingle();
      if (payload == null) return null;
      return Map<String, dynamic>.from(payload);
    } catch (_) {
      return null;
    }
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

  String? _nonEmpty(Object? value) {
    final str = value?.toString().trim();
    if (str == null || str.isEmpty) return null;
    return str;
  }
}
