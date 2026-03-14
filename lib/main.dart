import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/app_shell_screen.dart';
import 'theme/zen_theme.dart';

/// Entry point for the ZenPose Prototype app.
///
/// Forces portrait orientation and launches the [MainScreen] which handles
/// camera initialisation, pose detection, and skeleton rendering.
void main() async {
  // Ensure Flutter bindings are ready before calling platform code.
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait-up only (requirement: portrait mode).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Keep a standard app shell look with edge-to-edge content.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const ZenPoseApp());
}

/// Root widget for ZenPose with global yoga-themed styling.
class ZenPoseApp extends StatelessWidget {
  const ZenPoseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZenPose',
      debugShowCheckedModeBanner: false,
      theme: ZenTheme.build(),
      home: const AppShellScreen(),
    );
  }
}
