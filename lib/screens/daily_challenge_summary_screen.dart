import 'package:flutter/material.dart';

import '../models/unlocked_badge.dart';
import '../theme/zen_theme.dart';

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
    final durationLabel = '${minutes}m ${seconds.toString().padLeft(2, '0')}s';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Challenge Summary'),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: ZenDecor.gradientBackdrop(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              decoration: ZenDecor.softCard(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Great Flow',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You completed today\'s challenge.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  _row(
                    context,
                    'Completed poses',
                    '$completedSteps / $totalSteps',
                  ),
                  _row(context, 'Skipped poses', '$skippedSteps'),
                  _row(context, 'Session time', durationLabel),
                  _row(context, 'XP gained', '+$xpEarned'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: ZenDecor.softCard(color: Colors.white),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unlocked badges',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (unlockedBadges.isEmpty)
                    Text(
                      'No new badges this session.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else
                    ...unlockedBadges.map(
                      (badge) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.workspace_premium,
                              color: ZenColors.forest,
                            ),
                            const SizedBox(width: 8),
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
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: ZenColors.forest,
            ),
          ),
        ],
      ),
    );
  }
}
