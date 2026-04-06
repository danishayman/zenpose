import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/models/badge_definition.dart';
import 'package:zenpose/models/pose_result.dart';
import 'package:zenpose/models/unlocked_badge.dart';
import 'package:zenpose/models/user_stats.dart';
import 'package:zenpose/services/achievements_service.dart';

void main() {
  group('AchievementsService.buildBadgeProgress', () {
    test('builds unlocked and locked snapshots with progress labels', () {
      const definitions = <BadgeDefinition>[
        BadgeDefinition(
          id: 'sessions_5',
          name: 'Flow Builder',
          description: 'Complete 5 sessions',
          criteriaType: 'completed_sessions',
          criteriaValue: 5,
        ),
        BadgeDefinition(
          id: 'streak_7',
          name: 'Weekly Flow',
          description: 'Reach a 7-day streak',
          criteriaType: 'streak',
          criteriaValue: 7,
        ),
      ];
      final unlockedBadges = <UnlockedBadge>[
        UnlockedBadge(
          badgeId: 'sessions_5',
          name: 'Flow Builder',
          description: 'Complete 5 sessions',
          unlockedAt: DateTime(2026, 4, 1),
        ),
      ];
      final results = <PoseResult>[
        PoseResult(
          poseName: 'Tree',
          bestScore: 88,
          holdDuration: 40,
          completed: true,
          timestamp: DateTime(2026, 4, 1),
        ),
        PoseResult(
          poseName: 'Plank',
          bestScore: 91,
          holdDuration: 45,
          completed: true,
          timestamp: DateTime(2026, 4, 2),
        ),
        PoseResult(
          poseName: 'Warrior 2',
          bestScore: 89,
          holdDuration: 45,
          completed: true,
          timestamp: DateTime(2026, 4, 3),
        ),
        PoseResult(
          poseName: 'Goddess',
          bestScore: 84,
          holdDuration: 45,
          completed: true,
          timestamp: DateTime(2026, 4, 4),
        ),
        PoseResult(
          poseName: 'Downward Dog',
          bestScore: 90,
          holdDuration: 45,
          completed: true,
          timestamp: DateTime(2026, 4, 5),
        ),
      ];
      final stats = UserStats(
        currentStreak: 3,
        longestStreak: 5,
        totalXp: 150,
        lastActiveDate: DateTime(2026, 4, 2),
      );

      final snapshots = const AchievementsService().buildBadgeProgress(
        definitions: definitions,
        unlockedBadges: unlockedBadges,
        results: results,
        userStats: stats,
      );

      expect(snapshots.length, 2);
      final first = snapshots.first;
      final second = snapshots.last;

      expect(first.definition.id, 'sessions_5');
      expect(first.isUnlocked, isTrue);
      expect(first.progressLabel, '5 of 5');

      expect(second.definition.id, 'streak_7');
      expect(second.isUnlocked, isFalse);
      expect(second.progressLabel, '3 of 7');
      expect(second.progressRatio, closeTo(3 / 7, 0.0001));
    });
  });
}
