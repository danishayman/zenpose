import 'package:flutter_test/flutter_test.dart';

import 'package:zenpose/services/badge_catalog.dart';
import 'package:zenpose/services/gamification_service.dart';

void main() {
  group('GamificationService.computeStreakUpdate', () {
    test('keeps streak on same-day activity', () {
      final update = GamificationService.computeStreakUpdate(
        currentStreak: 4,
        longestStreak: 7,
        lastActiveDate: DateTime(2026, 3, 14, 8, 30),
        activityDate: DateTime(2026, 3, 14, 21, 15),
      );

      expect(update.currentStreak, 4);
      expect(update.longestStreak, 7);
    });

    test('increments streak on next-day activity', () {
      final update = GamificationService.computeStreakUpdate(
        currentStreak: 2,
        longestStreak: 3,
        lastActiveDate: DateTime(2026, 3, 14),
        activityDate: DateTime(2026, 3, 15),
      );

      expect(update.currentStreak, 3);
      expect(update.longestStreak, 3);
    });

    test('resets streak after a missed day', () {
      final update = GamificationService.computeStreakUpdate(
        currentStreak: 5,
        longestStreak: 5,
        lastActiveDate: DateTime(2026, 3, 14),
        activityDate: DateTime(2026, 3, 17),
      );

      expect(update.currentStreak, 1);
      expect(update.longestStreak, 5);
    });
  });

  group('GamificationService.calculateXpGain', () {
    test('awards base xp + score bonus', () {
      expect(GamificationService.calculateXpGain(82.3), 132);
    });

    test('clamps score to 100 when calculating bonus', () {
      expect(GamificationService.calculateXpGain(180), 150);
    });
  });

  group('GamificationService.determineBadgeUnlocks', () {
    test('unlocks expected badges and avoids duplicates', () {
      final unlocked = GamificationService.determineBadgeUnlocks(
        existingBadgeIds: <String>{BadgeCatalog.firstCompletionId},
        completedSessions: 5,
        currentStreak: 7,
        bestScore: 95,
      );

      expect(unlocked, contains(BadgeCatalog.sessions5Id));
      expect(unlocked, contains(BadgeCatalog.streak3Id));
      expect(unlocked, contains(BadgeCatalog.streak7Id));
      expect(unlocked, contains(BadgeCatalog.highScore90Id));
      expect(unlocked, contains(BadgeCatalog.highScore95Id));
      expect(unlocked, isNot(contains(BadgeCatalog.firstCompletionId)));
      expect(unlocked, isNot(contains(BadgeCatalog.streak14Id)));
      expect(unlocked, isNot(contains(BadgeCatalog.highScore98Id)));
    });
  });
}
