import 'dart:async';

import 'package:flutter/material.dart';

import '../models/pose_template.dart';
import '../services/pose_demo_asset_resolver.dart';
import '../theme/zen_theme.dart';

class PoseDemoAnimation extends StatelessWidget {
  final PoseTemplate template;
  final double height;
  final BorderRadius borderRadius;

  const PoseDemoAnimation({
    super.key,
    required this.template,
    this.height = 220,
    this.borderRadius = ZenDecor.cardRadius,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = PoseDemoAssetResolver.gifPathForTemplate(template);

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ZenColors.sage100, ZenColors.teal100],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.self_improvement_rounded,
          size: 88,
          color: ZenColors.forest,
        ),
      ),
    );
  }
}

class PreSessionCountdownPanel extends StatefulWidget {
  final PoseTemplate template;
  final int countdownSeconds;
  final VoidCallback onCountdownComplete;
  final bool compact;
  final bool showStartNowButton;
  final String startNowLabel;
  final bool showHoldDurationPicker;
  final int initialHoldSeconds;
  final int minHoldSeconds;
  final int maxHoldSeconds;
  final int holdStepSeconds;
  final ValueChanged<int>? onHoldSecondsChanged;

  const PreSessionCountdownPanel({
    super.key,
    required this.template,
    required this.countdownSeconds,
    required this.onCountdownComplete,
    this.compact = false,
    this.showStartNowButton = false,
    this.startNowLabel = 'Start Now',
    this.showHoldDurationPicker = false,
    this.initialHoldSeconds = 45,
    this.minHoldSeconds = 10,
    this.maxHoldSeconds = 120,
    this.holdStepSeconds = 5,
    this.onHoldSecondsChanged,
  });

  @override
  State<PreSessionCountdownPanel> createState() =>
      _PreSessionCountdownPanelState();
}

class _PreSessionCountdownPanelState extends State<PreSessionCountdownPanel> {
  Timer? _timer;
  late int _remaining;
  late int _selectedHoldSeconds;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.countdownSeconds;
    _selectedHoldSeconds = _clampHoldSeconds(widget.initialHoldSeconds);
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant PreSessionCountdownPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.countdownSeconds != widget.countdownSeconds) {
      _timer?.cancel();
      _remaining = widget.countdownSeconds;
      _completed = false;
      _startTimer();
    }
    if (oldWidget.initialHoldSeconds != widget.initialHoldSeconds) {
      _selectedHoldSeconds = _clampHoldSeconds(widget.initialHoldSeconds);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remaining <= 1) {
        timer.cancel();
        setState(() => _remaining = 0);
        _notifyComplete();
        return;
      }

      setState(() => _remaining -= 1);
    });
  }

  void _notifyComplete() {
    if (_completed) return;
    _completed = true;
    widget.onCountdownComplete();
  }

  void _startNow() {
    if (_completed) return;
    _timer?.cancel();
    if (mounted) {
      setState(() => _remaining = 0);
    }
    _notifyComplete();
  }

  int _clampHoldSeconds(int value) {
    final min = widget.minHoldSeconds;
    final max = widget.maxHoldSeconds;
    return value.clamp(min, max).toInt();
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
    if (next == _selectedHoldSeconds) return;
    setState(() => _selectedHoldSeconds = next);
    widget.onHoldSecondsChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final headlineStyle = widget.compact
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.headlineMedium;
    final countdownSize = widget.compact ? 54.0 : 86.0;
    final demoHeight = widget.compact ? 180.0 : 260.0;

    return Container(
      decoration: ZenDecor.elevatedCard(),
      padding: const EdgeInsets.all(18),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Get Ready', style: headlineStyle),
            const SizedBox(height: 4),
            Text(
              'Watch the pose demo. Camera opens automatically.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            PoseDemoAnimation(template: widget.template, height: demoHeight),
            if (widget.showHoldDurationPicker) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
                decoration: BoxDecoration(
                  color: ZenColors.surface1,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: ZenColors.sage200.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Pose hold',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text(
                          '${_selectedHoldSeconds}s',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: ZenColors.teal,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Manrope',
                              ),
                        ),
                      ],
                    ),
                    Slider(
                      min: widget.minHoldSeconds.toDouble(),
                      max: widget.maxHoldSeconds.toDouble(),
                      divisions:
                          ((widget.maxHoldSeconds - widget.minHoldSeconds) /
                                  widget.holdStepSeconds)
                              .round(),
                      value: _selectedHoldSeconds.toDouble(),
                      label: '${_selectedHoldSeconds}s',
                      onChanged: _setHoldSeconds,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Center(
              child: Column(
                children: [
                  Text(
                    _remaining > 0 ? '$_remaining' : 'GO',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: countdownSize,
                      fontWeight: FontWeight.w800,
                      color: ZenColors.teal,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _remaining > 0 ? 'Opening camera in...' : 'Launching...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (widget.showStartNowButton && _remaining > 0) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _startNow,
                      style: FilledButton.styleFrom(
                        backgroundColor: ZenColors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'Manrope',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(widget.startNowLabel),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
