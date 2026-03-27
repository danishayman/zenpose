import 'package:flutter_test/flutter_test.dart';

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

  group('DailyChallengeService.dateKeyFromDate', () {
    test('uses local date key format yyyy-mm-dd', () {
      final key = DailyChallengeService.dateKeyFromDate(
        DateTime(2026, 3, 14, 23, 59),
      );
      expect(key, equals('2026-03-14'));
    });
  });
}
