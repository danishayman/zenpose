import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'app_shell_screen.dart';
import 'auth_screen.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  final AuthService _authService = AuthService.instance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await _authService.restoreSession();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ValueListenableBuilder<AuthState>(
      valueListenable: _authService.authState,
      builder: (context, state, _) {
        if (state.status == AuthStatus.unconfigured) {
          return const AppShellScreen();
        }
        if (state.isAuthenticated) {
          return const _AuthenticatedRoot();
        }
        return const AuthScreen();
      },
    );
  }
}

class _AuthenticatedRoot extends StatefulWidget {
  const _AuthenticatedRoot();

  @override
  State<_AuthenticatedRoot> createState() => _AuthenticatedRootState();
}

class _AuthenticatedRootState extends State<_AuthenticatedRoot>
    with WidgetsBindingObserver {
  final SyncService _syncService = SyncService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_syncService.scheduleAutoSync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncService.syncNow());
    }
  }

  @override
  Widget build(BuildContext context) {
    return const AppShellScreen();
  }
}
