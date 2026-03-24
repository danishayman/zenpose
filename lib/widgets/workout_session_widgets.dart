import 'package:flutter/material.dart';

import '../models/unlocked_badge.dart';
import '../models/workout_guidance_snapshot.dart';

class WorkoutStatusHud extends StatelessWidget {
  final WorkoutGuidanceSnapshot snapshot;
  final double holdSeconds;
  final double durationSeconds;
  final double scoreThreshold;

  const WorkoutStatusHud({
    super.key,
    required this.snapshot,
    required this.holdSeconds,
    required this.durationSeconds,
    required this.scoreThreshold,
  });

  @override
  Widget build(BuildContext context) {
    final score = snapshot.score;
    final progress = snapshot.holdProgress.clamp(0.0, 1.0).toDouble();
    final holdActive = snapshot.state == WorkoutGuidanceState.holding;
    final isStableState =
        snapshot.state != WorkoutGuidanceState.unstablePose &&
        snapshot.state != WorkoutGuidanceState.noUserDetected;

    final Color scoreColor = score >= 80
        ? const Color(0xFF4ADBA8)
        : score >= scoreThreshold
        ? const Color(0xFFFFD166)
        : const Color(0xFFFF8C66);
    final Color barColor = holdActive
        ? const Color(0xFF4ADBA8)
        : const Color(0xFF4A9B8E);
    final chipColor = isStableState
        ? const Color(0xFF4ADBA8).withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.10);
    final chipTextColor = isStableState
        ? const Color(0xFF4ADBA8)
        : Colors.white60;
    final chipIcon = isStableState
        ? Icons.check_circle_rounded
        : Icons.radio_button_unchecked;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
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
                  const Text(
                    'POSE MATCH',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      fontFamily: 'Manrope',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${score.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: scoreColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Manrope',
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
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(chipIcon, color: chipTextColor, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      snapshot.statusLabel,
                      style: TextStyle(
                        color: chipTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Manrope',
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
              backgroundColor: Colors.white.withValues(alpha: 0.15),
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
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Manrope',
                ),
              ),
              if (!holdActive)
                Text(
                  'Needs ≥${scoreThreshold.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontFamily: 'Manrope',
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
    final shown = snapshot.cues.take(2).toList(growable: false);
    if (shown.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'GUIDANCE',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              fontFamily: 'Manrope',
            ),
          ),
        ),
        ...shown.map(
          (msg) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFFD166).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.tips_and_updates_rounded,
                    color: Color(0xFFFFD166),
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      msg,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Manrope',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rewards',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (xpGained > 0)
            Text(
              'XP +$xpGained',
              style: const TextStyle(
                color: Color(0xFF2D3A2E),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'Manrope',
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD8E5DE)),
                      ),
                      child: Text(
                        badge.name,
                        style: const TextStyle(
                          color: Color(0xFF2D3A2E),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Manrope',
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
