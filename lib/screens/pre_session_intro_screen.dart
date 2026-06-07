import 'package:flutter/material.dart';

import '../constants/session_launch_config.dart';
import '../models/pose_template.dart';
import '../services/pose_instruction_catalog.dart';
import '../theme/zen_theme.dart';
import '../widgets/pre_session_countdown_widgets.dart';
import '../widgets/zen_primary_button.dart';

typedef SessionDestinationBuilder =
    Widget Function(
      BuildContext context,
      PoseTemplate template,
      Duration holdDuration,
    );

class PreSessionIntroScreen extends StatefulWidget {
  final PoseTemplate template;
  final SessionDestinationBuilder destinationBuilder;
  final int countdownSeconds;
  final int initialHoldSeconds;
  final int minHoldSeconds;
  final int maxHoldSeconds;
  final int holdStepSeconds;

  const PreSessionIntroScreen({
    super.key,
    required this.template,
    required this.destinationBuilder,
    this.countdownSeconds = SessionLaunchConfig.preSessionCountdownSeconds,
    this.initialHoldSeconds = SessionLaunchConfig.defaultPracticeHoldSeconds,
    this.minHoldSeconds = SessionLaunchConfig.minPracticeHoldSeconds,
    this.maxHoldSeconds = SessionLaunchConfig.maxPracticeHoldSeconds,
    this.holdStepSeconds = SessionLaunchConfig.practiceHoldStepSeconds,
  });

  @override
  State<PreSessionIntroScreen> createState() => _PreSessionIntroScreenState();
}

class _PreSessionIntroScreenState extends State<PreSessionIntroScreen> {
  bool _launchTriggered = false;
  late int _holdSeconds;

  @override
  void initState() {
    super.initState();
    _holdSeconds = widget.initialHoldSeconds
        .clamp(widget.minHoldSeconds, widget.maxHoldSeconds)
        .toInt();
  }

  void _launchSession() {
    if (_launchTriggered || !mounted) return;
    _launchTriggered = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => widget.destinationBuilder(
          context,
          widget.template,
          Duration(seconds: _holdSeconds),
        ),
      ),
    );
  }

  int _clampHoldSeconds(int value) {
    return value.clamp(widget.minHoldSeconds, widget.maxHoldSeconds).toInt();
  }

  int _snapToStep(double value) {
    final clamped = value.clamp(
      widget.minHoldSeconds.toDouble(),
      widget.maxHoldSeconds.toDouble(),
    );
    final stepped = ((clamped - widget.minHoldSeconds) / widget.holdStepSeconds)
        .round();
    return widget.minHoldSeconds + (stepped * widget.holdStepSeconds);
  }

  void _setHoldSeconds(double value) {
    final next = _clampHoldSeconds(_snapToStep(value));
    if (next == _holdSeconds) return;
    setState(() => _holdSeconds = next);
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
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: _InstructionPanel(
                    template: widget.template,
                    steps: PoseInstructionCatalog.stepsFor(widget.template),
                    holdSeconds: _holdSeconds,
                    minHoldSeconds: widget.minHoldSeconds,
                    maxHoldSeconds: widget.maxHoldSeconds,
                    holdStepSeconds: widget.holdStepSeconds,
                    onHoldSecondsChanged: _setHoldSeconds,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  MediaQuery.of(context).padding.bottom + 14,
                ),
                decoration: BoxDecoration(
                  color: ZenColors.surface0,
                  boxShadow: [
                    BoxShadow(
                      color: ZenColors.bark.withValues(alpha: 0.07),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ZenPrimaryButton(
                  label: 'Open Camera',
                  icon: Icons.photo_camera_rounded,
                  onPressed: _launchSession,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionPanel extends StatelessWidget {
  final PoseTemplate template;
  final List<String> steps;
  final int holdSeconds;
  final int minHoldSeconds;
  final int maxHoldSeconds;
  final int holdStepSeconds;
  final ValueChanged<double> onHoldSecondsChanged;

  const _InstructionPanel({
    required this.template,
    required this.steps,
    required this.holdSeconds,
    required this.minHoldSeconds,
    required this.maxHoldSeconds,
    required this.holdStepSeconds,
    required this.onHoldSecondsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ZenDecor.elevatedCard(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to do ${template.name}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Read the steps, choose your hold time, then open the camera.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          PoseDemoAnimation(template: template, height: 240),
          const SizedBox(height: 16),
          Text('Steps', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (var i = 0; i < steps.length; i++) ...[
            _InstructionStep(number: i + 1, text: steps[i]),
            if (i != steps.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 16),
          _HoldDurationPicker(
            holdSeconds: holdSeconds,
            minHoldSeconds: minHoldSeconds,
            maxHoldSeconds: maxHoldSeconds,
            holdStepSeconds: holdStepSeconds,
            onChanged: onHoldSecondsChanged,
          ),
        ],
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final int number;
  final String text;

  const _InstructionStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: ZenColors.teal100,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ZenColors.teal,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ),
      ],
    );
  }
}

class _HoldDurationPicker extends StatelessWidget {
  final int holdSeconds;
  final int minHoldSeconds;
  final int maxHoldSeconds;
  final int holdStepSeconds;
  final ValueChanged<double> onChanged;

  const _HoldDurationPicker({
    required this.holdSeconds,
    required this.minHoldSeconds,
    required this.maxHoldSeconds,
    required this.holdStepSeconds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
      decoration: BoxDecoration(
        color: ZenColors.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZenColors.sage200.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Pose hold',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${holdSeconds}s',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: ZenColors.teal,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Manrope',
                ),
              ),
            ],
          ),
          Slider(
            min: minHoldSeconds.toDouble(),
            max: maxHoldSeconds.toDouble(),
            divisions: ((maxHoldSeconds - minHoldSeconds) / holdStepSeconds)
                .round(),
            value: holdSeconds.toDouble(),
            label: '${holdSeconds}s',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
