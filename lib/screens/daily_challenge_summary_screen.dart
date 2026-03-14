import 'package:flutter/material.dart';

import '../models/unlocked_badge.dart';
import '../theme/zen_theme.dart';
import '../widgets/zen_section_header.dart';

class DailyChallengeSummaryScreen extends StatelessWidget {
  final int completedSteps;
  final int skippedSteps;
  final int totalSteps;
  final int xpEarned;
  final Duration elapsed;
  final List<UnlockedBadge> unlockedBadges;

  const DailyChallengeSummaryScreen({
    super.key,
    required this.completedSteps,
    required this.skippedSteps,
    required this.totalSteps,
    required this.xpEarned,
    required this.elapsed,
    required this.unlockedBadges,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    final durationLabel =
        '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    final completionRate = totalSteps == 0
        ? 0
        : (completedSteps / totalSteps * 100).round();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: ZenDecor.gradientBackdrop(),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // Celebration header card
              _buildHeroCard(context, completionRate),
              const SizedBox(height: 16),
              // Stats
              _buildStatsCard(context, durationLabel),
              const SizedBox(height: 16),
              // Badges
              _buildBadgesCard(context),
              const SizedBox(height: 24),
              // CTA
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Back to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, int completionRate) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ZenColors.forest, ZenColors.teal],
        ),
        borderRadius: ZenDecor.cardRadius,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Great Flow!',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "You completed today's challenge.",
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
          const SizedBox(height: 20),
          // Completion ring
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$completionRate%',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Challenge',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    'Completed',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, String durationLabel) {
    return Container(
      decoration: ZenDecor.elevatedCard(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ZenSectionHeader(title: 'Session Summary'),
          const SizedBox(height: 14),
          _row(
            context,
            icon: Icons.check_circle_rounded,
            color: ZenColors.success,
            label: 'Poses completed',
            value: '$completedSteps / $totalSteps',
          ),
          _row(
            context,
            icon: Icons.skip_next_rounded,
            color: ZenColors.warning,
            label: 'Poses skipped',
            value: '$skippedSteps',
          ),
          _row(
            context,
            icon: Icons.timer_rounded,
            color: ZenColors.teal,
            label: 'Session time',
            value: durationLabel,
          ),
          _row(
            context,
            icon: Icons.star_rounded,
            color: const Color(0xFFC49A1B),
            label: 'XP gained',
            value: '+$xpEarned',
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesCard(BuildContext context) {
    return Container(
      decoration: ZenDecor.elevatedCard(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ZenSectionHeader(
            title: 'Unlocked Badges',
            subtitle: 'Earned this session',
          ),
          const SizedBox(height: 12),
          if (unlockedBadges.isEmpty)
            Text(
              'No new badges this session. Keep going!',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...unlockedBadges.map(
              (badge) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: ZenColors.sage100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: ZenColors.forest,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        badge.name,
                        style: Theme.of(context).textTheme.bodyLarge,
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

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: ZenDecor.chipRadius,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
