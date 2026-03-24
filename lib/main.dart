import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_gate_screen.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
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

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  final hasSupabaseConfig =
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  var supabaseReady = false;
  if (hasSupabaseConfig) {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      supabaseReady = true;
    } catch (_) {
      supabaseReady = false;
    }
  }

  AuthService.instance.configure(enabled: supabaseReady);
  SyncService.instance.configure(enabled: supabaseReady);

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
      home: const AuthGateScreen(),
    );
  }
}
