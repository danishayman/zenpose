import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/zen_theme.dart';
import 'admin_screen.dart';
import 'home_screen.dart';
import 'pose_selection_screen.dart';
import 'profile_screen.dart';
import 'progress_dashboard_screen.dart';

class AppShellScreen extends StatefulWidget {
  final List<Widget>? tabsOverride;

  const AppShellScreen({super.key, this.tabsOverride});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService.instance;
  int _tabIndex = 0;

  List<Widget> _buildTabs(bool includeAdmin) {
    if (widget.tabsOverride != null) return widget.tabsOverride!;
    return <Widget>[
      const HomeScreen(),
      const PoseSelectionScreen(),
      const ProgressDashboardScreen(),
      const ProfileScreen(),
      if (includeAdmin) const AdminScreen(),
    ];
  }

  List<NavigationDestination> _buildDestinations(bool includeAdmin) {
    return <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.self_improvement_outlined),
        selectedIcon: Icon(Icons.self_improvement),
        label: 'Practice',
      ),
      const NavigationDestination(
        icon: Icon(Icons.bar_chart_outlined),
        selectedIcon: Icon(Icons.bar_chart_rounded),
        label: 'Progress',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
      if (includeAdmin)
        const NavigationDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings_rounded),
          label: 'Admin',
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthState>(
      valueListenable: _authService.authState,
      builder: (context, auth, _) {
        final includeAdmin =
            widget.tabsOverride == null && auth.isAdmin && auth.isAccountActive;
        final tabs = _buildTabs(includeAdmin);
        final destinations = _buildDestinations(includeAdmin);
        if (_tabIndex >= tabs.length) {
          _tabIndex = tabs.length - 1;
        }

        return Scaffold(
          extendBody: true,
          body: Container(
            decoration: ZenDecor.gradientBackdrop(),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.03),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey<int>(_tabIndex),
                child: tabs[_tabIndex],
              ),
            ),
          ),
          bottomNavigationBar: _buildNavBar(destinations),
        );
      },
    );
  }

  Widget _buildNavBar(List<NavigationDestination> destinations) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: ZenColors.surface1,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: ZenColors.bark.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (index) =>
                setState(() => _tabIndex = index),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            indicatorColor: ZenColors.sage100,
            labelBehavior:
                NavigationDestinationLabelBehavior.alwaysShow,
            animationDuration: const Duration(milliseconds: 250),
            destinations: destinations,
          ),
        ),
      ),
    );
  }
}
