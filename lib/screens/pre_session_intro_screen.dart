import 'package:flutter/material.dart';

import '../constants/session_launch_config.dart';
import '../models/pose_template.dart';
import '../theme/zen_theme.dart';
import '../widgets/pre_session_countdown_widgets.dart';

typedef SessionDestinationBuilder =
    Widget Function(BuildContext context, PoseTemplate template);

class PreSessionIntroScreen extends StatefulWidget {
  final PoseTemplate template;
  final SessionDestinationBuilder destinationBuilder;
  final int countdownSeconds;

  const PreSessionIntroScreen({
    super.key,
    required this.template,
    required this.destinationBuilder,
    this.countdownSeconds = SessionLaunchConfig.preSessionCountdownSeconds,
  });

  @override
  State<PreSessionIntroScreen> createState() => _PreSessionIntroScreenState();
}

class _PreSessionIntroScreenState extends State<PreSessionIntroScreen> {
  bool _launchTriggered = false;

  void _launchSession() {
    if (_launchTriggered || !mounted) return;
    _launchTriggered = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) =>
            widget.destinationBuilder(context, widget.template),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZenColors.surface0,
      appBar: AppBar(
        title: Text(
          widget.template.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        backgroundColor: ZenColors.surface0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: Container(
        decoration: ZenDecor.gradientBackdrop(),
        child: SafeArea(
          top: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: PreSessionCountdownPanel(
                template: widget.template,
                countdownSeconds: widget.countdownSeconds,
                onCountdownComplete: _launchSession,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
