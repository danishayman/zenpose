import 'package:flutter/material.dart';

import '../theme/zen_theme.dart';
import 'home_screen.dart';
import 'pose_selection_screen.dart';
import 'progress_dashboard_screen.dart';

class AppShellScreen extends StatefulWidget {
  final List<Widget>? tabsOverride;

  const AppShellScreen({super.key, this.tabsOverride});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  int _tabIndex = 0;

  late final List<Widget> _tabs =
      widget.tabsOverride ??
      const <Widget>[
        HomeScreen(),
        PoseSelectionScreen(),
        ProgressDashboardScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: ZenDecor.gradientBackdrop(),
        child: IndexedStack(index: _tabIndex, children: _tabs),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BottomNavigationBar(
            currentIndex: _tabIndex,
            onTap: (index) => setState(() => _tabIndex = index),
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            backgroundColor: Colors.white,
            selectedItemColor: ZenColors.forest,
            unselectedItemColor: ZenColors.earth.withValues(alpha: 0.8),
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.self_improvement),
                label: 'Library',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.insights_rounded),
                label: 'Progress',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
