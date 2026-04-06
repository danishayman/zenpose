import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:zenpose/models/pose_result.dart';
import 'package:zenpose/models/profile_challenge_models.dart';
import 'package:zenpose/services/database_service.dart';
import 'package:zenpose/services/profile_challenge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.setDatabaseNameOverrideForTesting(
      'yoga_trainer_profile_challenge_test.db',
    );
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
    DatabaseService.setDatabaseNameOverrideForTesting(null);
  });

  Future<String> dbPathForTest() async {
    final root = await getDatabasesPath();
    return p.join(root, DatabaseService.effectiveDatabaseName);
  }

  tearDown(() async {
    await DatabaseService.instance.close();
    final path = await dbPathForTest();
    await deleteDatabase(path);
  });

  test('monthly challenge generation is deterministic by month key', () async {
    final service = ProfileChallengeService();
    final first = await service.loadMonthlyChallenges(
      now: DateTime(2026, 4, 10, 8),
    );
    final second = await service.loadMonthlyChallenges(
      now: DateTime(2026, 4, 29, 22),
    );
    expect(first.length, ProfileChallengeService.monthlyChallengeCount);
    expect(
      first.map((e) => e.definition.challengeId).toList(),
      second.map((e) => e.definition.challengeId).toList(),
    );
  });

  test(
    'progress math follows sessions/minutes/score-count definitions',
    () async {
      final db = DatabaseService.instance;
      await db.database;

      final inMonth = <PoseResult>[
        PoseResult(
          poseName: 'Tree',
          bestScore: 95,
          holdDuration: 600,
          completed: true,
          timestamp: DateTime(2026, 4, 3, 8),
        ),
        PoseResult(
          poseName: 'Plank',
          bestScore: 89,
          holdDuration: 300,
          completed: true,
          timestamp: DateTime(2026, 4, 8, 9),
        ),
        PoseResult(
          poseName: 'Warrior',
          bestScore: 92,
          holdDuration: 600,
          completed: true,
          timestamp: DateTime(2026, 4, 15, 9),
        ),
      ];
      for (final result in inMonth) {
        await db.insertPoseResult(result);
      }
      await db.insertPoseResult(
        PoseResult(
          poseName: 'Other month',
          bestScore: 99,
          holdDuration: 1200,
          completed: true,
          timestamp: DateTime(2026, 3, 22, 10),
        ),
      );
      await db.insertPoseResult(
        PoseResult(
          poseName: 'Incomplete',
          bestScore: 100,
          holdDuration: 1000,
          completed: false,
          timestamp: DateTime(2026, 4, 20, 10),
        ),
      );

      final service = ProfileChallengeService(databaseService: db);
      final snapshots = await service.loadMonthlyChallenges(
        now: DateTime(2026, 4, 22, 11),
      );
      final monthlyResults = inMonth;
      for (final snapshot in snapshots) {
        final expected = switch (snapshot.definition.metricType) {
          ChallengeMetricType.sessions => 3.0,
          ChallengeMetricType.minutes => (600 + 300 + 600) / 60.0,
          ChallengeMetricType.scoreCount =>
            monthlyResults
                .where(
                  (result) =>
                      result.bestScore >=
                      (snapshot.definition.scoreThreshold ?? 90),
                )
                .length
                .toDouble(),
        };
        expect(snapshot.currentValue, closeTo(expected, 0.0001));
      }
    },
  );

  test('join and claim are idempotent and XP reward applies once', () async {
    final db = DatabaseService.instance;
    await db.database;
    final service = ProfileChallengeService(databaseService: db);
    final now = DateTime(2026, 4, 20, 10);

    for (var i = 0; i < 50; i++) {
      await db.insertPoseResult(
        PoseResult(
          poseName: 'Bulk $i',
          bestScore: 100,
          holdDuration: 900,
          completed: true,
          timestamp: DateTime(2026, 4, 5, 9, i % 60),
        ),
      );
    }

    final initial = await service.loadMonthlyChallenges(now: now);
    final target = initial.firstWhere(
      (item) => item.status == ChallengeLifecycleStatus.notJoined,
      orElse: () => initial.first,
    );

    await service.joinChallenge(
      monthKey: target.monthKey,
      challengeId: target.definition.challengeId,
      now: now,
    );
    await service.joinChallenge(
      monthKey: target.monthKey,
      challengeId: target.definition.challengeId,
      now: now,
    );

    final states = await db.getProfileChallengeStatesForMonth(target.monthKey);
    expect(
      states
          .where((s) => s.challengeId == target.definition.challengeId)
          .length,
      equals(1),
    );

    final joinedSnapshot = (await service.loadMonthlyChallenges(now: now))
        .firstWhere(
          (item) =>
              item.definition.challengeId == target.definition.challengeId,
        );
    expect(joinedSnapshot.status, ChallengeLifecycleStatus.claimable);

    final beforeXp = await db.getUserStats();
    final firstClaim = await service.claimChallengeReward(
      monthKey: target.monthKey,
      challengeId: target.definition.challengeId,
      now: now,
    );
    final afterFirstXp = await db.getUserStats();
    final secondClaim = await service.claimChallengeReward(
      monthKey: target.monthKey,
      challengeId: target.definition.challengeId,
      now: now,
    );
    final afterSecondXp = await db.getUserStats();

    expect(firstClaim.applied, isTrue);
    expect(firstClaim.xpGranted, greaterThan(0));
    expect(
      afterFirstXp.totalXp - beforeXp.totalXp,
      equals(firstClaim.xpGranted),
    );

    expect(secondClaim.applied, isFalse);
    expect(afterSecondXp.totalXp, equals(afterFirstXp.totalXp));
  });

  test(
    'joined challenges become ended after month boundary without claim',
    () async {
      final db = DatabaseService.instance;
      await db.database;
      final service = ProfileChallengeService(databaseService: db);
      const monthKey = '2026-04';

      final snapshots = await service.loadMonthlyChallenges(
        monthKey: monthKey,
        now: DateTime(2026, 4, 20),
      );
      final target = snapshots.first;

      await service.joinChallenge(
        monthKey: monthKey,
        challengeId: target.definition.challengeId,
        now: DateTime(2026, 4, 21),
      );

      final ended = await service.loadMonthlyChallenges(
        monthKey: monthKey,
        now: DateTime(2026, 5, 2),
      );
      final endedTarget = ended.firstWhere(
        (item) => item.definition.challengeId == target.definition.challengeId,
      );
      expect(endedTarget.status, ChallengeLifecycleStatus.ended);
    },
  );
}
