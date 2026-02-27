import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/main_screen.dart';

/// Entry point for the ZenPose Prototype app.
///
/// Forces portrait orientation and launches the [MainScreen] which handles
/// camera initialisation, pose detection, and skeleton rendering.
void main() async {
  // Ensure Flutter bindings are ready before calling platform code.
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait-up only (requirement: portrait mode).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Hide the status bar for a full-screen camera experience.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const ZenPoseApp());
}

/// Root widget – minimal Material shell around [MainScreen].
class ZenPoseApp extends StatelessWidget {
  const ZenPoseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZenPose Prototype',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const MainScreen(),
    );
  }
}
