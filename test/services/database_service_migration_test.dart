import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:zenpose/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<String> dbPathForTest() async {
    final root = await getDatabasesPath();
    return p.join(root, DatabaseService.databaseName);
  }

  tearDown(() async {
    await DatabaseService.instance.close();
    final path = await dbPathForTest();
    await deleteDatabase(path);
  });

  test('migrates v1 database to v4 while preserving pose_results', () async {
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
  });

  test(
    'initializes v4 tables and default gamification rows on fresh database',
    () async {
      final db = await DatabaseService.instance.database;

      final statsRows = await db.query(DatabaseService.tableUserStats);
      expect(statsRows.length, 1);
      expect(statsRows.first[DatabaseService.columnCurrentStreak], equals(0));
      expect(statsRows.first[DatabaseService.columnTotalXp], equals(0));
      expect(statsRows.first[DatabaseService.columnUserId], isNotNull);
      expect(statsRows.first[DatabaseService.columnUpdatedAt], isNotNull);
      expect(statsRows.first[DatabaseService.columnIsSynced], equals(0));

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
    },
  );
}
