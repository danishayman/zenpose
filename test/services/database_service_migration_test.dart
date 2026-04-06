import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:zenpose/models/body_measurement.dart';
import 'package:zenpose/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
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

  test('migrates v1 database to v8 while preserving pose_results', () async {
    final path = await dbPathForTest();

    final legacyDb = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE ${DatabaseService.tablePoseResults} (
            ${DatabaseService.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
            ${DatabaseService.columnPoseName} TEXT,
            ${DatabaseService.columnBestScore} REAL,
            ${DatabaseService.columnHoldDuration} REAL,
            ${DatabaseService.columnCompleted} INTEGER,
            ${DatabaseService.columnTimestamp} TEXT
          )
          ''');
      },
    );

    await legacyDb.insert(DatabaseService.tablePoseResults, <String, Object?>{
      DatabaseService.columnPoseName: 'Warrior II',
      DatabaseService.columnBestScore: 88.0,
      DatabaseService.columnHoldDuration: 5.0,
      DatabaseService.columnCompleted: 1,
      DatabaseService.columnTimestamp: DateTime(2026, 3, 14).toIso8601String(),
    });
    await legacyDb.close();

    final db = await DatabaseService.instance.database;

    final poseRows = await db.query(DatabaseService.tablePoseResults);
    expect(poseRows.length, 1);
    expect(
      poseRows.first[DatabaseService.columnGamificationProcessed],
      equals(0),
    );
    expect(
      poseRows.first.containsKey(DatabaseService.columnSessionType),
      isTrue,
    );
    expect(poseRows.first[DatabaseService.columnRecordId], isNotNull);
    expect(poseRows.first[DatabaseService.columnUserId], isNotNull);
    expect(poseRows.first[DatabaseService.columnUpdatedAt], isNotNull);
    expect(poseRows.first[DatabaseService.columnIsSynced], equals(0));

    final statsRows = await db.query(DatabaseService.tableUserStats);
    expect(statsRows.length, 1);

    final badgeRows = await db.query(DatabaseService.tableBadges);
    expect(badgeRows.length, greaterThanOrEqualTo(3));

    final challengeRows = await db.query(DatabaseService.tableDailyChallenges);
    expect(challengeRows, isEmpty);

    final challengeStepRows = await db.query(
      DatabaseService.tableDailyChallengeSteps,
    );
    expect(challengeStepRows, isEmpty);

    final challengeColumns = await db.rawQuery(
      'PRAGMA table_info(${DatabaseService.tableDailyChallenges})',
    );
    final names = challengeColumns
        .map((row) => row['name']?.toString())
        .whereType<String>()
        .toSet();
    expect(names.contains(DatabaseService.columnSessionAvgScore), isTrue);
    expect(names.contains(DatabaseService.columnSessionCalories), isTrue);
    expect(names.contains(DatabaseService.columnSessionFeedback), isTrue);
    expect(names.contains(DatabaseService.columnSessionElapsedSeconds), isTrue);

    final weeklyGoalRows = await db.query(
      DatabaseService.tableWeeklyWorkoutGoals,
    );
    expect(weeklyGoalRows.length, 1);
    expect(
      weeklyGoalRows.first[DatabaseService.columnTargetWorkouts],
      equals(3),
    );

    final bodyMeasurementRows = await db.query(
      DatabaseService.tableBodyMeasurements,
    );
    expect(bodyMeasurementRows, isEmpty);

    final profileChallengeRows = await db.query(
      DatabaseService.tableUserProfileChallenges,
    );
    expect(profileChallengeRows, isEmpty);
  });

  test(
    'initializes v8 tables and default progress tracking rows on fresh database',
    () async {
      final db = await DatabaseService.instance.database;

      final statsRows = await db.query(DatabaseService.tableUserStats);
      expect(statsRows.length, 1);
      expect(statsRows.first[DatabaseService.columnCurrentStreak], equals(0));
      expect(statsRows.first[DatabaseService.columnTotalXp], equals(0));
      expect(statsRows.first[DatabaseService.columnUserId], isNotNull);
      expect(statsRows.first[DatabaseService.columnUpdatedAt], isNotNull);
      expect(statsRows.first[DatabaseService.columnIsSynced], equals(1));

      final badgeRows = await db.query(DatabaseService.tableBadges);
      expect(badgeRows.length, greaterThanOrEqualTo(3));

      final unlockedRows = await db.query(DatabaseService.tableUserBadges);
      expect(unlockedRows, isEmpty);

      final challengeRows = await db.query(
        DatabaseService.tableDailyChallenges,
      );
      expect(challengeRows, isEmpty);

      final challengeStepRows = await db.query(
        DatabaseService.tableDailyChallengeSteps,
      );
      expect(challengeStepRows, isEmpty);

      final challengeColumns = await db.rawQuery(
        'PRAGMA table_info(${DatabaseService.tableDailyChallenges})',
      );
      final names = challengeColumns
          .map((row) => row['name']?.toString())
          .whereType<String>()
          .toSet();
      expect(names.contains(DatabaseService.columnSessionAvgScore), isTrue);
      expect(names.contains(DatabaseService.columnSessionCalories), isTrue);
      expect(names.contains(DatabaseService.columnSessionFeedback), isTrue);
      expect(
        names.contains(DatabaseService.columnSessionElapsedSeconds),
        isTrue,
      );

      final poseColumns = await db.rawQuery(
        'PRAGMA table_info(${DatabaseService.tablePoseResults})',
      );
      final poseColumnNames = poseColumns
          .map((row) => row['name']?.toString())
          .whereType<String>()
          .toSet();
      expect(
        poseColumnNames.contains(DatabaseService.columnSessionType),
        isTrue,
      );

      final weeklyGoalRows = await db.query(
        DatabaseService.tableWeeklyWorkoutGoals,
      );
      expect(weeklyGoalRows.length, 1);
      expect(
        weeklyGoalRows.first[DatabaseService.columnTargetWorkouts],
        equals(3),
      );

      final measureRows = await db.query(DatabaseService.tableBodyMeasurements);
      expect(measureRows, isEmpty);

      final profileChallengeRows = await db.query(
        DatabaseService.tableUserProfileChallenges,
      );
      expect(profileChallengeRows, isEmpty);
    },
  );

  test('upsertWeeklyWorkoutGoal saves and reads target', () async {
    await DatabaseService.instance.database;
    await DatabaseService.instance.upsertWeeklyWorkoutGoal(targetWorkouts: 5);

    final goal = await DatabaseService.instance.getWeeklyWorkoutGoal();
    expect(goal.targetWorkouts, equals(5));
  });

  test('insertBodyMeasurement stores and returns latest history', () async {
    await DatabaseService.instance.database;
    final now = DateTime(2026, 4, 5, 8, 0, 0);

    await DatabaseService.instance.insertBodyMeasurement(
      BodyMeasurement(
        userId: '',
        metricType: BodyMetricType.bodyWeight,
        value: 71.2,
        unit: 'kg',
        measuredAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.toUtc(),
        isSynced: false,
      ),
    );
    await DatabaseService.instance.insertBodyMeasurement(
      BodyMeasurement(
        userId: '',
        metricType: BodyMetricType.bodyWeight,
        value: 70.8,
        unit: 'kg',
        measuredAt: now,
        updatedAt: now.toUtc(),
        isSynced: false,
      ),
    );

    final history = await DatabaseService.instance.getBodyMeasurementHistory(
      BodyMetricType.bodyWeight,
    );
    expect(history.length, equals(2));
    expect(history.first.value, equals(70.8));

    final latest = await DatabaseService.instance.getLatestBodyMeasurement(
      BodyMetricType.bodyWeight,
    );
    expect(latest, isNotNull);
    expect(latest!.value, equals(70.8));
  });

  test('sync key columns include new progress tracking tables', () {
    final weeklyKeys = DatabaseService.instance.tableKeyColumns(
      DatabaseService.tableWeeklyWorkoutGoals,
    );
    final measureKeys = DatabaseService.instance.tableKeyColumns(
      DatabaseService.tableBodyMeasurements,
    );
    final profileChallengeKeys = DatabaseService.instance.tableKeyColumns(
      DatabaseService.tableUserProfileChallenges,
    );
    expect(weeklyKeys, equals(<String>[DatabaseService.columnUserId]));
    expect(
      measureKeys,
      equals(<String>[
        DatabaseService.columnUserId,
        DatabaseService.columnMetricKey,
        DatabaseService.columnMeasuredAt,
      ]),
    );
    expect(
      profileChallengeKeys,
      equals(<String>[
        DatabaseService.columnUserId,
        DatabaseService.columnMonthKey,
        DatabaseService.columnChallengeId,
      ]),
    );
  });
}
