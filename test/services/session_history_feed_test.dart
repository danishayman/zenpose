import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:zenpose/models/challenge_step_result.dart';
import 'package:zenpose/models/daily_challenge.dart';
import 'package:zenpose/models/daily_challenge_step.dart';
import 'package:zenpose/models/pose_result.dart';
import 'package:zenpose/models/session_history_entry.dart';
import 'package:zenpose/services/daily_challenge_service.dart';
import 'package:zenpose/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.setDatabaseNameOverrideForTesting(
      'yoga_trainer_session_history_test.db',
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
    'daily challenge completion persists pose results as challenge sessions',
    () async {
      final db = DatabaseService.instance;
      await db.database;
      final dateKey = '2026-04-06';
      final startedAt = DateTime(2026, 4, 6, 9, 0);
      await db.insertDailyChallenge(
        challenge: DailyChallenge(
          dateKey: dateKey,
          status: DailyChallengeStatus.inProgress,
          skipCount: 0,
          totalSteps: 1,
          startedAt: startedAt,
          completedAt: null,
          updatedAt: startedAt,
          sequence: const <String>['Tree'],
        ),
        steps: <DailyChallengeStep>[
          DailyChallengeStep(
            dateKey: dateKey,
            stepIndex: 0,
            poseName: 'Tree',
            status: DailyChallengeStepStatus.pending,
            bestScore: null,
            holdDuration: null,
            updatedAt: startedAt,
          ),
        ],
      );

      final service = DailyChallengeService(databaseService: db);
      final process = await service.completeTimedStep(
        dateKey: dateKey,
        stepIndex: 0,
        stepResult: ChallengeStepResult(
          poseName: 'Tree',
          bestScore: 88,
          holdDuration: 45,
          passed: true,
          completedAt: DateTime(2026, 4, 6, 9, 10),
        ),
      );
      expect(process.applied, isTrue);

      final results = await db.getAllResults();
      expect(results.length, equals(1));
      expect(
        results.first.sessionType,
        equals(PoseResultSessionType.challenge),
      );
    },
  );

  test('practice pose results retain practice session type', () async {
    final db = DatabaseService.instance;
    await db.database;
    await db.insertPoseResult(
      PoseResult(
        poseName: 'Tree',
        bestScore: 87,
        holdDuration: 120,
        completed: true,
        timestamp: DateTime(2026, 4, 8, 18, 0),
        sessionType: PoseResultSessionType.practice,
      ),
    );

    final results = await db.getAllResults();
    expect(results.length, equals(1));
    expect(results.single.sessionType, equals(PoseResultSessionType.practice));
  });

  test(
    'home history merges challenge and practice sessions with legacy handling',
    () async {
      final db = DatabaseService.instance;
      await db.database;

      final dateKey = '2026-04-07';
      final startedAt = DateTime(2026, 4, 7, 7, 30);
      await db.insertDailyChallenge(
        challenge: DailyChallenge(
          dateKey: dateKey,
          status: DailyChallengeStatus.inProgress,
          skipCount: 1,
          totalSteps: 3,
          startedAt: startedAt,
          completedAt: null,
          updatedAt: DateTime(2026, 4, 7, 8, 0),
          sequence: const <String>['Downdog', 'Tree', 'Plank'],
        ),
        steps: <DailyChallengeStep>[
          DailyChallengeStep(
            dateKey: dateKey,
            stepIndex: 0,
            poseName: 'Downdog',
            status: DailyChallengeStepStatus.completed,
            bestScore: 82,
            holdDuration: 45,
            updatedAt: DateTime(2026, 4, 7, 7, 40),
          ),
          DailyChallengeStep(
            dateKey: dateKey,
            stepIndex: 1,
            poseName: 'Tree',
            status: DailyChallengeStepStatus.skipped,
            bestScore: null,
            holdDuration: null,
            updatedAt: DateTime(2026, 4, 7, 7, 50),
          ),
          DailyChallengeStep(
            dateKey: dateKey,
            stepIndex: 2,
            poseName: 'Plank',
            status: DailyChallengeStepStatus.pending,
            bestScore: null,
            holdDuration: null,
            updatedAt: DateTime(2026, 4, 7, 8, 0),
          ),
        ],
      );

      await db.insertPoseResult(
        PoseResult(
          poseName: 'Warrior2',
          bestScore: 91,
          holdDuration: 320,
          completed: true,
          timestamp: DateTime(2026, 4, 7, 12, 0),
          sessionType: PoseResultSessionType.practice,
        ),
      );
      await db.insertPoseResult(
        PoseResult(
          poseName: 'Goddess',
          bestScore: 77,
          holdDuration: 190,
          completed: true,
          timestamp: DateTime(2026, 4, 6, 9, 0),
        ),
      );
      await db.insertPoseResult(
        PoseResult(
          poseName: 'ShouldNotShowAsPractice',
          bestScore: 99,
          holdDuration: 88,
          completed: true,
          timestamp: DateTime(2026, 4, 7, 11, 0),
          sessionType: PoseResultSessionType.challenge,
        ),
      );

      final history = await db.getHomeSessionHistory();
      expect(history.length, equals(3));
      expect(history.first.kind, equals(SessionHistoryKind.practice));
      expect(history.first.poses.single.poseName, equals('Warrior2'));

      final challengeEntry = history.firstWhere(
        (entry) => entry.kind == SessionHistoryKind.challenge,
      );
      expect(challengeEntry.completed, isFalse);
      expect(challengeEntry.poseCount, equals(3));
      expect(challengeEntry.completedPoseCount, equals(1));
      expect(challengeEntry.durationSeconds, equals(45));
      expect(challengeEntry.averageScore, equals(82.0));

      final legacyPractice = history.firstWhere(
        (entry) =>
            entry.kind == SessionHistoryKind.practice && entry.isLegacyPractice,
      );
      expect(legacyPractice.poses.single.poseName, equals('Goddess'));
    },
  );
}
