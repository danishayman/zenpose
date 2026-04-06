import 'package:flutter/material.dart';

import '../models/badge_progress_snapshot.dart';
import '../theme/zen_theme.dart';
import '../widgets/zen_badge_medallion.dart';

class AchievementsScreen extends StatelessWidget {
  final List<BadgeProgressSnapshot> badges;

  const AchievementsScreen({super.key, required this.badges});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final crossAxisCount = screenWidth >= 760
        ? 4
        : screenWidth >= 520
        ? 3
        : 3;
    final childAspectRatio = screenWidth >= 760
        ? 0.72
        : screenWidth >= 520
        ? 0.66
        : 0.56;

    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: SafeArea(
        child: Container(
          decoration: ZenDecor.gradientBackdrop(),
          child: badges.isEmpty
              ? Center(
                  child: Text(
                    'No badges yet. Complete a session to begin.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : GridView.builder(
                  key: const Key('achievements-grid'),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  itemCount: badges.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: childAspectRatio,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemBuilder: (context, index) {
                    final badge = badges[index];
                    return _BadgeGridTile(snapshot: badge);
                  },
                ),
        ),
      ),
    );
  }
}

class _BadgeGridTile extends StatelessWidget {
  final BadgeProgressSnapshot snapshot;

  const _BadgeGridTile({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final medallionSize = (constraints.maxWidth * 0.76).clamp(66.0, 84.0);
        return Container(
          decoration: ZenDecor.elevatedCard(),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ZenHexBadgeMedallion(snapshot: snapshot, size: medallionSize),
              const SizedBox(height: 8),
              Text(
                snapshot.definition.name,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontSize: 13, height: 1.15),
              ),
              const SizedBox(height: 4),
              Text(
                snapshot.progressLabel,
                key: Key('achievement-progress-${snapshot.definition.id}'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: snapshot.isUnlocked
                      ? ZenColors.success
                      : ZenColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
