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

  const PreSessionCountdownPanel({
    super.key,
    required this.template,
    required this.countdownSeconds,
    required this.onCountdownComplete,
    this.compact = false,
  });

  @override
  State<PreSessionCountdownPanel> createState() =>
      _PreSessionCountdownPanelState();
}

class _PreSessionCountdownPanelState extends State<PreSessionCountdownPanel> {
  Timer? _timer;
  late int _remaining;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.countdownSeconds;
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
