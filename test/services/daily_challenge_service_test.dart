import 'package:flutter_test/flutter_test.dart';

import 'package:zenpose/models/daily_challenge.dart';
import 'package:zenpose/services/daily_challenge_service.dart';

void main() {
  group('DailyChallengeService.buildDeterministicSequence', () {
    test('returns same order for same date', () {
      const poses = <String>['Tree', 'Plank', 'Warrior2', 'Downdog', 'Goddess'];
      final a = DailyChallengeService.buildDeterministicSequence(
        poseNames: poses,
        dateKey: '2026-03-14',
        take: 5,
      );
      final b = DailyChallengeService.buildDeterministicSequence(
        poseNames: poses,
        dateKey: '2026-03-14',
        take: 5,
      );
      expect(a, equals(b));
    });

    test('returns different order for different date', () {
      const poses = <String>['Tree', 'Plank', 'Warrior2', 'Downdog', 'Goddess'];
      final a = DailyChallengeService.buildDeterministicSequence(
        poseNames: poses,
        dateKey: '2026-03-14',
        take: 5,
      );
      final b = DailyChallengeService.buildDeterministicSequence(
        poseNames: poses,
        dateKey: '2026-03-15',
        take: 5,
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('DailyChallengeService rules', () {
    test('allows exactly one skip', () {
      expect(DailyChallengeService.canSkip(0), isTrue);
      expect(DailyChallengeService.canSkip(1), isFalse);
    });

    test('challenge completes whenever pending steps reach zero', () {
      expect(
        DailyChallengeService.shouldMarkCompleted(
          pendingStepsAfterUpdate: 0,
          skipCount: 1,
        ),
        isTrue,
      );
      expect(
        DailyChallengeService.shouldMarkCompleted(
          pendingStepsAfterUpdate: 1,
          skipCount: 0,
        ),
        isFalse,
      );
      expect(
        DailyChallengeService.shouldMarkCompleted(
          pendingStepsAfterUpdate: 0,
          skipCount: 2,
        ),
        isTrue,
      );
    });

    test('hybrid pass requires both score and hold duration', () {
      expect(
        DailyChallengeService.isStepPassing(
          bestScore: 70,
          holdDurationSeconds: 45,
        ),
        isTrue,
      );
      expect(
        DailyChallengeService.isStepPassing(
          bestScore: 69.9,
          holdDurationSeconds: 45,
        ),
        isFalse,
      );
      expect(
        DailyChallengeService.isStepPassing(
          bestScore: 80,
          holdDurationSeconds: 40,
        ),
        isFalse,
      );
    });
  });

  group('DailyChallengeService level-based hold policy', () {
    test('maps XP bands to level correctly', () {
      expect(
        DailyChallengeService.levelFromXp(0),
        equals(DailyChallengeUserLevel.beginner),
      );
      expect(
        DailyChallengeService.levelFromXp(999),
        equals(DailyChallengeUserLevel.beginner),
      );
      expect(
        DailyChallengeService.levelFromXp(1000),
        equals(DailyChallengeUserLevel.intermediate),
      );
      expect(
        DailyChallengeService.levelFromXp(2999),
        equals(DailyChallengeUserLevel.intermediate),
      );
      expect(
        DailyChallengeService.levelFromXp(3000),
        equals(DailyChallengeUserLevel.advanced),
      );
    });

    test('maps level to hold seconds correctly', () {
      expect(
        DailyChallengeService.holdSecondsForLevel(
          DailyChallengeUserLevel.beginner,
        ),
        equals(20),
      );
      expect(
        DailyChallengeService.holdSecondsForLevel(
          DailyChallengeUserLevel.intermediate,
        ),
        equals(35),
      );
      expect(
        DailyChallengeService.holdSecondsForLevel(
          DailyChallengeUserLevel.advanced,
        ),
        equals(45),
      );
    });

    test('falls back to legacy 45s when challenge target is missing', () {
      final challenge = DailyChallenge(
        dateKey: '2026-04-07',
        status: DailyChallengeStatus.inProgress,
        skipCount: 0,
        totalSteps: 5,
        startedAt: DateTime(2026, 4, 7, 8, 0),
        completedAt: null,
        updatedAt: DateTime(2026, 4, 7, 8, 0),
        sequence: const <String>['Tree'],
      );
      expect(
        DailyChallengeService.targetHoldSecondsForChallenge(challenge),
        equals(45),
      );
    });
  });

  group('DailyChallengeService.dateKeyFromDate', () {
    test('uses local date key format yyyy-mm-dd', () {
      final key = DailyChallengeService.dateKeyFromDate(
        DateTime(2026, 3, 14, 23, 59),
      );
      expect(key, equals('2026-03-14'));
    });
  });
}
