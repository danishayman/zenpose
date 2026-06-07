import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/punishment_models.dart';
import '../models/user_rank.dart';
import '../theme/zen_theme.dart';

class XpDeductionDialog extends StatefulWidget {
  final PunishmentEvaluationResult result;

  const XpDeductionDialog({super.key, required this.result});

  static Future<void> showIfNeeded(
    BuildContext context, {
    required PunishmentEvaluationResult result,
  }) async {
    if (!result.applied || result.xpDeducted <= 0) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => XpDeductionDialog(result: result),
    );
  }

  @override
  State<XpDeductionDialog> createState() => _XpDeductionDialogState();
}

class _XpDeductionDialogState extends State<XpDeductionDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    if (widget.result.didRankDown) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaries = _PenaltySummary.fromBreakdown(widget.result.breakdown);
    final maxContentHeight = MediaQuery.sizeOf(context).height * 0.58;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('XP Deducted'),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxContentHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '-${widget.result.xpDeducted} XP',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: ZenColors.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              ...summaries.map(
                (summary) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _PenaltySummaryText(summary: summary),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total XP: ${widget.result.xpAfter}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (widget.result.didRankDown) ...[
                const SizedBox(height: 14),
                const Text(
                  'Rank Dropped',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w800,
                    color: ZenColors.error,
                  ),
                ),
                const SizedBox(height: 8),
                _RankDropBadgeTransition(
                  progress: _progress,
                  fromAsset: widget.result.rankBefore.badgeAssetPath,
                  toAsset: widget.result.rankAfter.badgeAssetPath,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _PenaltySummaryText extends StatelessWidget {
  final _PenaltySummary summary;

  const _PenaltySummaryText({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summary.title, style: theme.bodyMedium),
        if (summary.subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            summary.subtitle!,
            style: theme.bodySmall?.copyWith(
              color: theme.bodySmall?.color?.withValues(alpha: 0.74),
            ),
          ),
        ],
      ],
    );
  }
}

class _PenaltySummary {
  final PenaltyReason reason;
  final int count;
  final int xpDeducted;
  final List<String> dateKeys;

  const _PenaltySummary({
    required this.reason,
    required this.count,
    required this.xpDeducted,
    required this.dateKeys,
  });

  String get title {
    final label = count == 1 ? reason.label : _pluralLabel(reason);
    final countText = count == 1 ? '' : ' x$count';
    return '$label$countText: -$xpDeducted';
  }

  String? get subtitle {
    if (count <= 1 || dateKeys.isEmpty) return null;
    final dates = [...dateKeys]..sort();
    if (dates.length == 1) return dates.single;
    return '${dates.first} to ${dates.last}';
  }

  static List<_PenaltySummary> fromBreakdown(
    List<PenaltyBreakdownItem> breakdown,
  ) {
    final grouped = <PenaltyReason, List<PenaltyBreakdownItem>>{};
    for (final item in breakdown) {
      grouped
          .putIfAbsent(item.reason, () => <PenaltyBreakdownItem>[])
          .add(item);
    }

    return grouped.entries
        .map((entry) {
          final dateKeys = entry.value
              .map((item) => item.dateKey)
              .where((dateKey) => dateKey.isNotEmpty)
              .toSet()
              .toList(growable: false);
          return _PenaltySummary(
            reason: entry.key,
            count: entry.value.length,
            xpDeducted: entry.value.fold<int>(
              0,
              (total, item) => total + item.xpDeducted,
            ),
            dateKeys: dateKeys,
          );
        })
        .toList(growable: false);
  }

  static String _pluralLabel(PenaltyReason reason) {
    switch (reason) {
      case PenaltyReason.missedDay:
        return 'Missed Days';
      case PenaltyReason.challengeAbandon:
        return 'Challenges Abandoned';
      case PenaltyReason.practicePoorPerformance:
        return 'Poor Practices';
      case PenaltyReason.practiceRepeatedPoorPerformance:
        return 'Repeated Poor Practices';
      case PenaltyReason.lowScoreFailures:
        return reason.label;
    }
  }
}

class _RankDropBadgeTransition extends StatelessWidget {
  final Animation<double> progress;
  final String fromAsset;
  final String toAsset;

  const _RankDropBadgeTransition({
    required this.progress,
    required this.fromAsset,
    required this.toAsset,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final t = progress.value;
        final shakeAmount = t < 0.62 ? math.sin(t * 18 * math.pi) * 6.0 : 0.0;
        final crackOpacity = t.clamp(0.2, 0.75);
        final showDropped = t >= 0.65;

        return SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: showDropped ? 0.0 : (1.0 - (t * 1.3)).clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(shakeAmount, 0),
                  child: _badge(fromAsset),
                ),
              ),
              if (!showDropped)
                IgnorePointer(
                  child: Opacity(
                    opacity: crackOpacity,
                    child: CustomPaint(
                      size: const Size(72, 72),
                      painter: _CrackPainter(),
                    ),
                  ),
                ),
              Opacity(
                opacity: showDropped ? ((t - 0.65) / 0.35).clamp(0.0, 1.0) : 0,
                child: Transform.scale(
                  scale: showDropped ? 0.9 + (((t - 0.65) / 0.35) * 0.1) : 0.9,
                  child: _badge(toAsset),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _badge(String assetPath) {
    return Image.asset(
      assetPath,
      width: 72,
      height: 72,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Icon(
        Icons.workspace_premium_rounded,
        color: ZenColors.forest,
        size: 56,
      ),
    );
  }
}

class _CrackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ZenColors.error
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final p1 = Path()
      ..moveTo(size.width * 0.22, size.height * 0.20)
      ..lineTo(size.width * 0.52, size.height * 0.44)
      ..lineTo(size.width * 0.44, size.height * 0.74);
    final p2 = Path()
      ..moveTo(size.width * 0.74, size.height * 0.18)
      ..lineTo(size.width * 0.52, size.height * 0.44)
      ..lineTo(size.width * 0.70, size.height * 0.72);
    canvas.drawPath(p1, paint);
    canvas.drawPath(p2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
