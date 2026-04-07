import 'package:flutter/material.dart';

import '../models/unlocked_badge.dart';
import '../models/workout_guidance_snapshot.dart';
import '../theme/zen_theme.dart';

class WorkoutStatusHud extends StatelessWidget {
  final WorkoutGuidanceSnapshot snapshot;
  final double holdSeconds;
  final double durationSeconds;
  final double scoreThreshold;
  final double? displayScore;
  final double? displayProgress;

  const WorkoutStatusHud({
    super.key,
    required this.snapshot,
    required this.holdSeconds,
    required this.durationSeconds,
    required this.scoreThreshold,
    this.displayScore,
    this.displayProgress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final score = (displayScore ?? snapshot.score).clamp(0.0, 100.0).toDouble();
    final progress = (displayProgress ?? snapshot.holdProgress)
        .clamp(0.0, 1.0)
        .toDouble();
    final holdActive = snapshot.state == WorkoutGuidanceState.holding;
    final isStableState =
        snapshot.state != WorkoutGuidanceState.unstablePose &&
        snapshot.state != WorkoutGuidanceState.noUserDetected;

    final Color scoreColor = score >= 80
        ? ZenColors.success
        : score >= scoreThreshold
        ? ZenColors.warning
        : ZenColors.error;
    final Color barColor = holdActive ? ZenColors.success : ZenColors.teal;
    final chipColor = isStableState
        ? ZenColors.success.withValues(alpha: 0.18)
        : ZenColors.bark.withValues(alpha: 0.48);
    final chipBorderColor = isStableState
        ? ZenColors.success.withValues(alpha: 0.40)
        : ZenColors.sage200.withValues(alpha: 0.30);
    final chipTextColor = isStableState
        ? ZenColors.successLight
        : ZenColors.mist.withValues(alpha: 0.70);
    final chipIcon = isStableState
        ? Icons.check_circle_rounded
        : Icons.radio_button_unchecked;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ZenColors.bark.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ZenColors.sage200.withValues(alpha: 0.36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'POSE MATCH',
                    style: textTheme.labelSmall?.copyWith(
                      color: ZenColors.mist.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${score.toStringAsFixed(0)}%',
                    style: textTheme.headlineLarge?.copyWith(
                      color: scoreColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 32,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: chipBorderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(chipIcon, color: chipTextColor, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      snapshot.statusLabel,
                      style: textTheme.labelMedium?.copyWith(
                        color: chipTextColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: ZenColors.mist.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hold  ${holdSeconds.toStringAsFixed(1)}s / '
                '${durationSeconds.toStringAsFixed(0)}s',
                style: textTheme.labelMedium?.copyWith(
                  color: ZenColors.mist.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              if (!holdActive)
                Text(
                  'Needs ≥${scoreThreshold.toStringAsFixed(0)}%',
                  style: textTheme.labelSmall?.copyWith(
                    color: ZenColors.mist.withValues(alpha: 0.52),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class WorkoutFeedbackPanel extends StatelessWidget {
  final WorkoutGuidanceSnapshot snapshot;
  final bool visible;

  const WorkoutFeedbackPanel({
    super.key,
    required this.snapshot,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    final cue = snapshot.primaryCue?.trim() ?? '';

    return SizedBox(
      height: 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'GUIDANCE',
              style: textTheme.labelSmall?.copyWith(
                color: ZenColors.mist.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: ZenColors.bark.withValues(alpha: 0.66),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: ZenColors.warning.withValues(alpha: 0.55),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.tips_and_updates_rounded,
                    color: ZenColors.warning,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: Text(
                        cue,
                        key: ValueKey<String>(cue),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: cue.isEmpty
                              ? ZenColors.mist.withValues(alpha: 0.50)
                              : ZenColors.mist,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WorkoutRewardSummary extends StatelessWidget {
  final int xpGained;
  final List<UnlockedBadge> unlockedBadges;

  const WorkoutRewardSummary({
    super.key,
    required this.xpGained,
    required this.unlockedBadges,
  });

  @override
  Widget build(BuildContext context) {
    if (xpGained <= 0 && unlockedBadges.isEmpty) {
      return const SizedBox.shrink();
    }
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ZenColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZenColors.surface2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rewards',
            style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (xpGained > 0)
            Text(
              'XP +$xpGained',
              style: textTheme.bodyLarge?.copyWith(
                color: ZenColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          if (unlockedBadges.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: unlockedBadges
                  .map(
                    (badge) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: ZenColors.surface0,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ZenColors.surface2),
                      ),
                      child: Text(
                        badge.name,
                        style: textTheme.labelMedium?.copyWith(
                          color: ZenColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}
