import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/onboarding_service.dart';
import '../services/punishment_service.dart';
import '../services/sync_service.dart';
import '../models/punishment_models.dart';
import '../theme/zen_theme.dart';
import '../widgets/xp_deduction_dialog.dart';
import 'app_shell_screen.dart';
import 'auth_screen.dart';
import 'onboarding_screen.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  final AuthService _authService = AuthService.instance;
  final OnboardingService _onboardingService = OnboardingService.instance;
  bool _loading = true;
  bool _onboardingCompleted = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await _authService.restoreSession();
    await _loadOnboardingState();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadOnboardingState() async {
    _onboardingCompleted = await _onboardingService.isCompleted();
  }

  Future<void> _completeOnboarding() async {
    await _onboardingService.markCompleted();
    if (!mounted) return;
    setState(() => _onboardingCompleted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ValueListenableBuilder<AuthState>(
      valueListenable: _authService.authState,
      builder: (context, state, _) {
        if (!_onboardingCompleted) {
          return OnboardingScreen(onFinish: _completeOnboarding);
        }
        if (state.status == AuthStatus.unconfigured) {
          return const AppShellScreen();
        }
        if (state.isAuthenticated) {
          if (!state.isAccountActive) {
            return const _InactiveAccountScreen();
          }
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
  final PunishmentService _punishmentService = PunishmentService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_syncService.scheduleAutoSync());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_evaluatePunishments(PenaltyApplicationTrigger.appOpen));
    });
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
      unawaited(_evaluatePunishments(PenaltyApplicationTrigger.appOpen));
    }
  }

  Future<void> _evaluatePunishments(PenaltyApplicationTrigger trigger) async {
    final result = await _punishmentService.evaluate(trigger: trigger);
    if (!mounted) return;
    await XpDeductionDialog.showIfNeeded(context, result: result);
  }

  @override
  Widget build(BuildContext context) {
    return const AppShellScreen();
  }
}

class _InactiveAccountScreen extends StatelessWidget {
  const _InactiveAccountScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: ZenDecor.gradientBackdrop(),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  decoration: ZenDecor.elevatedCard(),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_person_rounded,
                        size: 54,
                        color: ZenColors.warning,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Account Disabled',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your account is currently inactive. Please contact an admin to restore access.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          await AuthService.instance.signOut();
                        },
                        child: const Text('Sign Out'),
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
