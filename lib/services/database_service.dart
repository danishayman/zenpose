import 'dart:developer';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/pose_result.dart';
import '../models/daily_challenge.dart';
import '../models/daily_challenge_step.dart';
import '../models/unlocked_badge.dart';
import '../models/user_stats.dart';
import 'badge_catalog.dart';

/// Local SQLite persistence for pose sessions and offline gamification data.
class DatabaseService {
  DatabaseService._internal();

  static final DatabaseService instance = DatabaseService._internal();

  factory DatabaseService() => instance;

  static const String databaseName = 'yoga_trainer.db';
  static const int databaseVersion = 3;

  static const String tablePoseResults = 'pose_results';
  static const String columnId = 'id';
  static const String columnPoseName = 'pose_name';
  static const String columnBestScore = 'best_score';
  static const String columnHoldDuration = 'hold_duration';
  static const String columnCompleted = 'completed';
  static const String columnTimestamp = 'timestamp';
  static const String columnGamificationProcessed = 'gamification_processed';

  static const String tableUserStats = 'user_stats';
  static const String columnUserStatsId = 'id';
  static const String columnCurrentStreak = 'current_streak';
  static const String columnLongestStreak = 'longest_streak';
  static const String columnTotalXp = 'total_xp';
  static const String columnLastActiveDate = 'last_active_date';

  static const String tableBadges = 'badges';
  static const String columnBadgeId = 'badge_id';
  static const String columnBadgeName = 'name';
  static const String columnBadgeDescription = 'description';
  static const String columnBadgeCriteriaType = 'criteria_type';
  static const String columnBadgeCriteriaValue = 'criteria_value';

  static const String tableUserBadges = 'user_badges';
  static const String columnUnlockedAt = 'unlocked_at';
  static const String columnSourcePoseResultId = 'source_pose_result_id';

  static const String tableDailyChallenges = 'daily_challenges';
  static const String tableDailyChallengeSteps = 'daily_challenge_steps';
  static const String columnDateKey = 'date_key';
  static const String columnStatus = 'status';
  static const String columnSkipCount = 'skip_count';
  static const String columnTotalSteps = 'total_steps';
  static const String columnStartedAt = 'started_at';
  static const String columnCompletedAt = 'completed_at';
  static const String columnUpdatedAt = 'updated_at';
  static const String columnSequenceJson = 'sequence_json';
  static const String columnStepIndex = 'step_index';

  static const int singleUserStatsRowId = 1;

  Database? _database;
  Future<Database>? _databaseInit;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _databaseInit ??= _initDatabase();
    _database = await _databaseInit!;
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, databaseName);
      return openDatabase(
        path,
        version: databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e, stackTrace) {
      _logError('Failed to open database.', e, stackTrace);
      throw Exception('Failed to open database: $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    try {
      await db.execute('''
        CREATE TABLE $tablePoseResults (
          $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
          $columnPoseName TEXT,
          $columnBestScore REAL,
          $columnHoldDuration REAL,
          $columnCompleted INTEGER,
          $columnTimestamp TEXT,
          $columnGamificationProcessed INTEGER NOT NULL DEFAULT 0
        )
        ''');

      await _createGamificationTables(db);
      await _createDailyChallengeTables(db);
      await _ensureUserStatsRow(db);
      await _seedBadges(db);
    } catch (e, stackTrace) {
      _logError('Failed to create database schema.', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    try {
      if (oldVersion < 2) {
        final hasProcessedColumn = await _columnExists(
          db: db,
          tableName: tablePoseResults,
          columnName: columnGamificationProcessed,
        );
        if (!hasProcessedColumn) {
          await db.execute('''
            ALTER TABLE $tablePoseResults
            ADD COLUMN $columnGamificationProcessed INTEGER NOT NULL DEFAULT 0
            ''');
        }

        await _createGamificationTables(db);
        await _ensureUserStatsRow(db);
        await _seedBadges(db);
      }
      if (oldVersion < 3) {
        await _createDailyChallengeTables(db);
      }
    } catch (e, stackTrace) {
      _logError('Failed during database migration.', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _createGamificationTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableUserStats (
        $columnUserStatsId INTEGER PRIMARY KEY,
        $columnCurrentStreak INTEGER NOT NULL DEFAULT 0,
        $columnLongestStreak INTEGER NOT NULL DEFAULT 0,
        $columnTotalXp INTEGER NOT NULL DEFAULT 0,
        $columnLastActiveDate TEXT
      )
      ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableBadges (
        $columnBadgeId TEXT PRIMARY KEY,
        $columnBadgeName TEXT NOT NULL,
        $columnBadgeDescription TEXT NOT NULL,
        $columnBadgeCriteriaType TEXT NOT NULL,
        $columnBadgeCriteriaValue REAL NOT NULL
      )
      ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableUserBadges (
        $columnBadgeId TEXT PRIMARY KEY,
        $columnUnlockedAt TEXT NOT NULL,
        $columnSourcePoseResultId INTEGER,
        FOREIGN KEY($columnBadgeId) REFERENCES $tableBadges($columnBadgeId),
        FOREIGN KEY($columnSourcePoseResultId) REFERENCES $tablePoseResults($columnId)
      )
      ''');
  }

  Future<void> _createDailyChallengeTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableDailyChallenges (
        $columnDateKey TEXT PRIMARY KEY,
        $columnStatus TEXT NOT NULL DEFAULT 'in_progress',
        $columnSkipCount INTEGER NOT NULL DEFAULT 0,
        $columnTotalSteps INTEGER NOT NULL,
        $columnStartedAt TEXT,
        $columnCompletedAt TEXT,
        $columnUpdatedAt TEXT NOT NULL,
        $columnSequenceJson TEXT NOT NULL
      )
      ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableDailyChallengeSteps (
        $columnDateKey TEXT NOT NULL,
        $columnStepIndex INTEGER NOT NULL,
        $columnPoseName TEXT NOT NULL,
        $columnStatus TEXT NOT NULL DEFAULT 'pending',
        $columnBestScore REAL,
        $columnHoldDuration REAL,
        $columnUpdatedAt TEXT,
        PRIMARY KEY ($columnDateKey, $columnStepIndex),
        FOREIGN KEY($columnDateKey) REFERENCES $tableDailyChallenges($columnDateKey)
      )
      ''');
  }

  Future<void> _ensureUserStatsRow(DatabaseExecutor db) async {
    await db.insert(tableUserStats, <String, Object?>{
      columnUserStatsId: singleUserStatsRowId,
      columnCurrentStreak: 0,
      columnLongestStreak: 0,
      columnTotalXp: 0,
      columnLastActiveDate: null,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _seedBadges(DatabaseExecutor db) async {
    for (final badge in BadgeCatalog.defaultBadges) {
      await db.insert(
        tableBadges,
        badge.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<bool> _columnExists({
    required DatabaseExecutor db,
    required String tableName,
    required String columnName,
  }) async {
    final rows = await db.rawQuery('PRAGMA table_info($tableName)');
    return rows.any((row) => row['name']?.toString() == columnName);
  }

  Future<int> insertPoseResult(PoseResult result) async {
    try {
      final db = await database;
      final values = result.toMap();
      values[columnTimestamp] ??= DateTime.now().toIso8601String();
      values[columnGamificationProcessed] = 0;
      return await db.insert(tablePoseResults, values);
    } catch (e, stackTrace) {
      _logError('Failed to insert pose result.', e, stackTrace);
      throw Exception('Failed to insert pose result: $e');
    }
  }

  Future<List<PoseResult>> getAllResults() async {
    try {
      final db = await database;
      final rows = await db.query(
        tablePoseResults,
        orderBy: '$columnTimestamp DESC',
      );
      return rows.map(PoseResult.fromMap).toList();
    } catch (e, stackTrace) {
      _logError('Failed to fetch pose results.', e, stackTrace);
      throw Exception('Failed to fetch pose results: $e');
    }
  }

  Future<PoseResult?> getPoseResultById(int id) async {
    try {
      final db = await database;
      final rows = await db.query(
        tablePoseResults,
        where: '$columnId = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return PoseResult.fromMap(rows.first);
    } catch (e, stackTrace) {
      _logError('Failed to fetch pose result id=$id.', e, stackTrace);
      throw Exception('Failed to fetch pose result: $e');
    }
  }

  Future<double?> getBestScoreForPose(String poseName) async {
    try {
      final db = await database;
      final rows = await db.rawQuery(
        'SELECT MAX($columnBestScore) as max_score '
        'FROM $tablePoseResults '
        'WHERE $columnPoseName = ?',
        <Object?>[poseName],
      );
      if (rows.isEmpty) return null;
      final value = rows.first['max_score'];
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    } catch (e, stackTrace) {
      _logError('Failed to fetch best score for $poseName.', e, stackTrace);
      throw Exception('Failed to fetch best score: $e');
    }
  }

  Future<UserStats> getUserStats() async {
    try {
      final db = await database;
      await _ensureUserStatsRow(db);
      final rows = await db.query(
        tableUserStats,
        where: '$columnUserStatsId = ?',
        whereArgs: <Object?>[singleUserStatsRowId],
        limit: 1,
      );
      if (rows.isEmpty) return const UserStats.initial();
      return UserStats.fromMap(rows.first);
    } catch (e, stackTrace) {
      _logError('Failed to fetch user stats.', e, stackTrace);
      throw Exception('Failed to fetch user stats: $e');
    }
  }

  Future<int> getUnlockedBadgeCount() async {
    try {
      final db = await database;
      final rows = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableUserBadges',
      );
      if (rows.isEmpty) return 0;
      final value = rows.first['count'];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    } catch (e, stackTrace) {
      _logError('Failed to fetch unlocked badge count.', e, stackTrace);
      throw Exception('Failed to fetch unlocked badge count: $e');
    }
  }

  Future<List<UnlockedBadge>> getLatestUnlockedBadges({int limit = 5}) async {
    try {
      final db = await database;
      final rows = await db.rawQuery(
        '''
        SELECT ub.$columnBadgeId,
               b.$columnBadgeName,
               b.$columnBadgeDescription,
               ub.$columnUnlockedAt
        FROM $tableUserBadges ub
        INNER JOIN $tableBadges b
          ON b.$columnBadgeId = ub.$columnBadgeId
        ORDER BY ub.$columnUnlockedAt DESC
        LIMIT ?
        ''',
        <Object?>[limit],
      );
      return rows.map(UnlockedBadge.fromMap).toList();
    } catch (e, stackTrace) {
      _logError('Failed to fetch latest unlocked badges.', e, stackTrace);
      throw Exception('Failed to fetch latest unlocked badges: $e');
    }
  }

  Future<void> insertDailyChallenge({
    required DailyChallenge challenge,
    required List<DailyChallengeStep> steps,
  }) async {
    final db = await database;
    await db.transaction((tx) async {
      await tx.insert(
        tableDailyChallenges,
        challenge.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final step in steps) {
        await tx.insert(
          tableDailyChallengeSteps,
          step.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<DailyChallenge?> getDailyChallengeByDateKey(String dateKey) async {
    final db = await database;
    final rows = await db.query(
      tableDailyChallenges,
      where: '$columnDateKey = ?',
      whereArgs: <Object?>[dateKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DailyChallenge.fromMap(rows.first);
  }

  Future<List<DailyChallengeStep>> getDailyChallengeSteps(
    String dateKey,
  ) async {
    final db = await database;
    final rows = await db.query(
      tableDailyChallengeSteps,
      where: '$columnDateKey = ?',
      whereArgs: <Object?>[dateKey],
      orderBy: '$columnStepIndex ASC',
    );
    return rows.map(DailyChallengeStep.fromMap).toList();
  }

  Future<void> updateDailyChallenge(DailyChallenge challenge) async {
    final db = await database;
    await db.update(
      tableDailyChallenges,
      challenge.toMap(),
      where: '$columnDateKey = ?',
      whereArgs: <Object?>[challenge.dateKey],
    );
  }

  Future<void> updateDailyChallengeStep(DailyChallengeStep step) async {
    final db = await database;
    await db.update(
      tableDailyChallengeSteps,
      step.toMap(),
      where: '$columnDateKey = ? AND $columnStepIndex = ?',
      whereArgs: <Object?>[step.dateKey, step.stepIndex],
    );
  }

  Future<void> close() async {
    if (_database == null) return;
    try {
      await _database!.close();
    } catch (e, stackTrace) {
      _logError('Failed to close database.', e, stackTrace);
      throw Exception('Failed to close database: $e');
    } finally {
      _database = null;
      _databaseInit = null;
    }
  }

  void _logError(String message, Object error, StackTrace stackTrace) {
    log(message, error: error, stackTrace: stackTrace, name: 'DatabaseService');
  }
}
