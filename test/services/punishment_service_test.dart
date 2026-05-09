import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:zenpose/models/daily_challenge.dart';
import 'package:zenpose/models/daily_challenge_step.dart';
import 'package:zenpose/models/pose_result.dart';
import 'package:zenpose/models/punishment_models.dart';
import 'package:zenpose/services/database_service.dart';
import 'package:zenpose/services/punishment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.setDatabaseNameOverrideForTesting(
      'yoga_trainer_punishment_service_test.db',
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

  test(
    'poor practice penalties escalate and trigger low-score threshold once',
    () async {
      final db = DatabaseService.instance;
      await db.database;
      await db.incrementTotalXp(200);
      final service = PunishmentService(databaseService: db);

      final first = await service.evaluate(
        trigger: PenaltyApplicationTrigger.postSession,
        practiceResult: PoseResult(
          id: 1,
          poseName: 'Tree',
          bestScore: 63,
          holdDuration: 5.0,
          completed: true,
          timestamp: DateTime(2026, 5, 9, 10, 0, 0),
          sessionType: PoseResultSessionType.practice,
        ),
        qualityGateScore: 70,
      );
      expect(first.applied, isTrue);
      expect(first.xpDeducted, equals(8));

      final second = await service.evaluate(
        trigger: PenaltyApplicationTrigger.postSession,
        practiceResult: PoseResult(
          id: 2,
          poseName: 'Tree',
          bestScore: 64,
          holdDuration: 5.1,
          completed: true,
          timestamp: DateTime(2026, 5, 9, 10, 3, 0),
          sessionType: PoseResultSessionType.practice,
        ),
        qualityGateScore: 70,
      );
      expect(second.xpDeducted, equals(12));

      final third = await service.evaluate(
        trigger: PenaltyApplicationTrigger.postSession,
        practiceResult: PoseResult(
          id: 3,
          poseName: 'Tree',
          bestScore: 65,
          holdDuration: 5.0,
          completed: true,
          timestamp: DateTime(2026, 5, 9, 10, 8, 0),
          sessionType: PoseResultSessionType.practice,
        ),
        qualityGateScore: 70,
      );
      expect(third.xpDeducted, equals(26));
      expect(
        third.breakdown.any((b) => b.reason == PenaltyReason.lowScoreFailures),
        isTrue,
      );
    },
  );

  test('penalties scale with rank multiplier', () async {
    final db = DatabaseService.instance;
    await db.database;
    await db.incrementTotalXp(14000);
    final service = PunishmentService(databaseService: db);

    final result = await service.evaluate(
      trigger: PenaltyApplicationTrigger.postSession,
      practiceResult: PoseResult(
        id: 11,
        poseName: 'Plank',
        bestScore: 62,
        holdDuration: 5.0,
        completed: true,
        timestamp: DateTime(2026, 5, 9, 11, 0, 0),
        sessionType: PoseResultSessionType.practice,
      ),
      qualityGateScore: 70,
    );
    expect(result.xpDeducted, equals(18));
  });

  test('idempotent for same practice source key', () async {
    final db = DatabaseService.instance;
    await db.database;
    await db.incrementTotalXp(300);
    final service = PunishmentService(databaseService: db);

    final result = PoseResult(
      id: 77,
      poseName: 'Chair',
      bestScore: 61,
      holdDuration: 5.2,
      completed: true,
      timestamp: DateTime(2026, 5, 9, 12, 0, 0),
      sessionType: PoseResultSessionType.practice,
    );

    final first = await service.evaluate(
      trigger: PenaltyApplicationTrigger.postSession,
      practiceResult: result,
      qualityGateScore: 70,
    );
    final second = await service.evaluate(
      trigger: PenaltyApplicationTrigger.postSession,
      practiceResult: result,
      qualityGateScore: 70,
    );
    expect(first.applied, isTrue);
    expect(second.applied, isFalse);
  });

  test('app-open applies missed day and challenge abandon once', () async {
    final db = DatabaseService.instance;
    await db.database;
    await db.incrementTotalXp(500);
    final service = PunishmentService(databaseService: db);

    final now = DateTime(2026, 5, 9, 9, 0, 0);
    final missedDayKey = '2026-05-08';
    final challenge = DailyChallenge(
      dateKey: missedDayKey,
      status: DailyChallengeStatus.inProgress,
      skipCount: 0,
      totalSteps: 1,
      targetHoldSeconds: 20,
      startedAt: DateTime(2026, 5, 8, 7, 0, 0),
      completedAt: null,
      updatedAt: DateTime(2026, 5, 8, 7, 0, 0),
      sequence: const <String>['Tree'],
    );
    final steps = <DailyChallengeStep>[
      DailyChallengeStep(
        dateKey: missedDayKey,
        stepIndex: 0,
        poseName: 'Tree',
        status: DailyChallengeStepStatus.pending,
        bestScore: null,
        holdDuration: null,
        updatedAt: DateTime(2026, 5, 8, 7, 0, 0),
      ),
    ];
    await db.insertDailyChallenge(challenge: challenge, steps: steps);

    final sqflite = await db.database;
    await sqflite.update(
      DatabaseService.tableUserStats,
      <String, Object?>{
        DatabaseService.columnLastActiveDate: '2026-05-07',
        DatabaseService.columnUpdatedAt: now.toUtc().toIso8601String(),
        DatabaseService.columnIsSynced: 0,
      },
      where: '${DatabaseService.columnUserId} = ?',
      whereArgs: <Object?>['__local__'],
    );

    final first = await service.evaluate(
      trigger: PenaltyApplicationTrigger.appOpen,
      now: now,
    );
    final second = await service.evaluate(
      trigger: PenaltyApplicationTrigger.appOpen,
      now: now,
    );

    expect(first.applied, isTrue);
    expect(first.xpDeducted, greaterThan(0));
    expect(second.applied, isFalse);
  });
}
