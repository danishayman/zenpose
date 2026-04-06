import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/daily_challenge.dart';
import '../models/daily_challenge_step.dart';
import '../models/badge_definition.dart';
import '../models/body_measurement.dart';
import '../models/pose_result.dart';
import '../models/profile_challenge_models.dart';
import '../models/unlocked_badge.dart';
import '../models/user_stats.dart';
import '../models/weekly_workout_goal.dart';
import 'auth_context.dart';
import 'badge_catalog.dart';

class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();
  factory DatabaseService() => instance;

  static const String databaseName = 'yoga_trainer.db';
  static String? _databaseNameOverrideForTesting;
  static String get effectiveDatabaseName =>
      _databaseNameOverrideForTesting ?? databaseName;

  static void setDatabaseNameOverrideForTesting(String? fileName) {
    _databaseNameOverrideForTesting = fileName;
  }

  static const int databaseVersion = 7;

  static const String tablePoseResults = 'pose_results';
  static const String columnId = 'id';
  static const String columnRecordId = 'record_id';
  static const String columnUserId = 'user_id';
  static const String columnPoseName = 'pose_name';
  static const String columnBestScore = 'best_score';
  static const String columnHoldDuration = 'hold_duration';
  static const String columnCompleted = 'completed';
  static const String columnTimestamp = 'timestamp';
  static const String columnGamificationProcessed = 'gamification_processed';
  static const String columnUpdatedAt = 'updated_at';
  static const String columnIsSynced = 'is_synced';

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
  static const String tableWeeklyWorkoutGoals = 'weekly_workout_goals';
  static const String tableBodyMeasurements = 'body_measurements';
  static const String tableUserProfileChallenges = 'user_profile_challenges';
  static const String columnDateKey = 'date_key';
  static const String columnMonthKey = 'month_key';
  static const String columnChallengeId = 'challenge_id';
  static const String columnStatus = 'status';
  static const String columnSkipCount = 'skip_count';
  static const String columnTotalSteps = 'total_steps';
  static const String columnJoinedAt = 'joined_at';
  static const String columnStartedAt = 'started_at';
  static const String columnCompletedAt = 'completed_at';
  static const String columnClaimedAt = 'claimed_at';
  static const String columnRewardBadgeLabel = 'reward_badge_label';
  static const String columnSequenceJson = 'sequence_json';
  static const String columnSessionAvgScore = 'session_avg_score';
  static const String columnSessionCalories = 'session_calories';
  static const String columnSessionFeedback = 'session_feedback';
  static const String columnSessionElapsedSeconds = 'session_elapsed_seconds';
  static const String columnStepIndex = 'step_index';
  static const String columnTargetWorkouts = 'target_workouts';
  static const String columnMetricKey = 'metric_key';
  static const String columnValue = 'value';
  static const String columnUnit = 'unit';
  static const String columnMeasuredAt = 'measured_at';
  static const int singleUserStatsRowId = 1;

  Database? _database;
  Future<Database>? _databaseInit;
  final StreamController<void> _mutationController =
      StreamController<void>.broadcast();
  final math.Random _rng = math.Random();

  Stream<void> get mutationStream => _mutationController.stream;
  String get _activeUserId => AuthContext.activeUserId;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _databaseInit ??= _initDatabase();
    _database = await _databaseInit!;
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, effectiveDatabaseName);
    return openDatabase(
      path,
      version: databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tablePoseResults (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnRecordId TEXT NOT NULL UNIQUE,
        $columnUserId TEXT NOT NULL,
        $columnPoseName TEXT,
        $columnBestScore REAL,
        $columnHoldDuration REAL,
        $columnCompleted INTEGER,
        $columnTimestamp TEXT,
        $columnGamificationProcessed INTEGER NOT NULL DEFAULT 0,
        $columnUpdatedAt TEXT NOT NULL,
        $columnIsSynced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _createGamificationTables(db);
    await _createDailyChallengeTables(db);
    await _createProgressTrackingTables(db);
    await _ensureUserStatsRow(db);
    await _ensureWeeklyGoalRow(db);
    await _seedBadges(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2 &&
        !await _columnExists(
          db: db,
          tableName: tablePoseResults,
          columnName: columnGamificationProcessed,
        )) {
      await db.execute('''
        ALTER TABLE $tablePoseResults
        ADD COLUMN $columnGamificationProcessed INTEGER NOT NULL DEFAULT 0
      ''');
    }
    if (oldVersion < 4) {
      await _migrateToV4(db);
    }
    if (oldVersion < 5) {
      await _migrateToV5(db);
    }
    if (oldVersion < 6) {
      await _migrateToV6(db);
    }
    if (oldVersion < 7) {
      await _migrateToV7(db);
    }
    await _createGamificationTables(db);
    await _createDailyChallengeTables(db);
    await _createProgressTrackingTables(db);
    await _ensureDailyChallengeSummaryColumns(db);
    await _ensureUserStatsRow(db);
    await _ensureWeeklyGoalRow(db);
    await _seedBadges(db);
  }

  Future<void> _migrateToV5(Database db) async {
    await _ensureDailyChallengeSummaryColumns(db);
  }

  Future<void> _migrateToV6(Database db) async {
    await _createProgressTrackingTables(db);
    await _ensureWeeklyGoalRow(db);
  }

  Future<void> _migrateToV7(Database db) async {
    await _createProgressTrackingTables(db);
  }

  Future<void> _migrateToV4(Database db) async {
    final nowIso = _nowIso();
    if (!await _columnExists(
      db: db,
      tableName: tablePoseResults,
      columnName: columnRecordId,
    )) {
      await db.execute(
        'ALTER TABLE $tablePoseResults ADD COLUMN $columnRecordId TEXT',
      );
    }
    if (!await _columnExists(
      db: db,
      tableName: tablePoseResults,
      columnName: columnUserId,
    )) {
      await db.execute(
        'ALTER TABLE $tablePoseResults ADD COLUMN $columnUserId TEXT',
      );
    }
    if (!await _columnExists(
      db: db,
      tableName: tablePoseResults,
      columnName: columnUpdatedAt,
    )) {
      await db.execute(
        'ALTER TABLE $tablePoseResults ADD COLUMN $columnUpdatedAt TEXT',
      );
    }
    if (!await _columnExists(
      db: db,
      tableName: tablePoseResults,
      columnName: columnIsSynced,
    )) {
      await db.execute(
        'ALTER TABLE $tablePoseResults ADD COLUMN $columnIsSynced INTEGER NOT NULL DEFAULT 0',
      );
    }
    final poseRows = await db.query(
      tablePoseResults,
      columns: <String>[
        columnId,
        columnRecordId,
        columnTimestamp,
        columnUpdatedAt,
      ],
    );
    for (final row in poseRows) {
      final id = row[columnId] as int?;
      if (id == null) continue;
      await db.update(
        tablePoseResults,
        <String, Object?>{
          columnRecordId: (row[columnRecordId]?.toString().isNotEmpty ?? false)
              ? row[columnRecordId]
              : _generateRecordId(),
          columnUserId: AuthContext.localUserId,
          columnUpdatedAt:
              (row[columnUpdatedAt]?.toString().isNotEmpty ?? false)
              ? row[columnUpdatedAt]
              : (row[columnTimestamp] ?? nowIso),
          columnIsSynced: 0,
        },
        where: '$columnId = ?',
        whereArgs: <Object?>[id],
      );
    }
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_pose_record ON $tablePoseResults($columnRecordId)',
    );

    await _rebuildUserBadgesToScoped(db, nowIso);
    await _rebuildDailyChallengesToScoped(db, nowIso);
    await _rebuildDailyChallengeStepsToScoped(db, nowIso);
    await _ensureUserStatsColumns(db, nowIso);
  }

  Future<void> _createGamificationTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableUserStats (
        $columnUserStatsId INTEGER PRIMARY KEY,
        $columnUserId TEXT NOT NULL UNIQUE,
        $columnCurrentStreak INTEGER NOT NULL DEFAULT 0,
        $columnLongestStreak INTEGER NOT NULL DEFAULT 0,
        $columnTotalXp INTEGER NOT NULL DEFAULT 0,
        $columnLastActiveDate TEXT,
        $columnUpdatedAt TEXT NOT NULL,
        $columnIsSynced INTEGER NOT NULL DEFAULT 0
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
        $columnUserId TEXT NOT NULL,
        $columnBadgeId TEXT NOT NULL,
        $columnUnlockedAt TEXT NOT NULL,
        $columnSourcePoseResultId INTEGER,
        $columnUpdatedAt TEXT NOT NULL,
        $columnIsSynced INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY($columnUserId, $columnBadgeId),
        FOREIGN KEY($columnBadgeId) REFERENCES $tableBadges($columnBadgeId),
        FOREIGN KEY($columnSourcePoseResultId) REFERENCES $tablePoseResults($columnId)
      )
    ''');
  }

  Future<void> _createDailyChallengeTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableDailyChallenges (
        $columnUserId TEXT NOT NULL,
        $columnDateKey TEXT NOT NULL,
        $columnStatus TEXT NOT NULL DEFAULT 'in_progress',
        $columnSkipCount INTEGER NOT NULL DEFAULT 0,
        $columnTotalSteps INTEGER NOT NULL,
        $columnStartedAt TEXT,
        $columnCompletedAt TEXT,
        $columnSessionAvgScore REAL,
        $columnSessionCalories REAL,
        $columnSessionFeedback TEXT,
        $columnSessionElapsedSeconds INTEGER,
        $columnUpdatedAt TEXT NOT NULL,
        $columnSequenceJson TEXT NOT NULL,
        $columnIsSynced INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY($columnUserId, $columnDateKey)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableDailyChallengeSteps (
        $columnUserId TEXT NOT NULL,
        $columnDateKey TEXT NOT NULL,
        $columnStepIndex INTEGER NOT NULL,
        $columnPoseName TEXT NOT NULL,
        $columnStatus TEXT NOT NULL DEFAULT 'pending',
        $columnBestScore REAL,
        $columnHoldDuration REAL,
        $columnUpdatedAt TEXT,
        $columnIsSynced INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY($columnUserId, $columnDateKey, $columnStepIndex)
      )
    ''');
  }

  Future<void> _createProgressTrackingTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableWeeklyWorkoutGoals (
        $columnUserId TEXT PRIMARY KEY,
        $columnTargetWorkouts INTEGER NOT NULL DEFAULT 3,
        $columnUpdatedAt TEXT NOT NULL,
        $columnIsSynced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableBodyMeasurements (
        $columnUserId TEXT NOT NULL,
        $columnMetricKey TEXT NOT NULL,
        $columnValue REAL NOT NULL,
        $columnUnit TEXT NOT NULL,
        $columnMeasuredAt TEXT NOT NULL,
        $columnUpdatedAt TEXT NOT NULL,
        $columnIsSynced INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY($columnUserId, $columnMetricKey, $columnMeasuredAt)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableUserProfileChallenges (
        $columnUserId TEXT NOT NULL,
        $columnMonthKey TEXT NOT NULL,
        $columnChallengeId TEXT NOT NULL,
        $columnStatus TEXT NOT NULL,
        $columnJoinedAt TEXT NOT NULL,
        $columnCompletedAt TEXT,
        $columnClaimedAt TEXT,
        $columnRewardBadgeLabel TEXT,
        $columnUpdatedAt TEXT NOT NULL,
        $columnIsSynced INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY($columnUserId, $columnMonthKey, $columnChallengeId)
      )
    ''');
  }

  Future<void> _ensureDailyChallengeSummaryColumns(DatabaseExecutor db) async {
    if (!await _columnExists(
      db: db,
      tableName: tableDailyChallenges,
      columnName: columnSessionAvgScore,
    )) {
      await db.execute(
        'ALTER TABLE $tableDailyChallenges ADD COLUMN $columnSessionAvgScore REAL',
      );
    }
    if (!await _columnExists(
      db: db,
      tableName: tableDailyChallenges,
      columnName: columnSessionCalories,
    )) {
      await db.execute(
        'ALTER TABLE $tableDailyChallenges ADD COLUMN $columnSessionCalories REAL',
      );
    }
    if (!await _columnExists(
      db: db,
      tableName: tableDailyChallenges,
      columnName: columnSessionFeedback,
    )) {
      await db.execute(
        'ALTER TABLE $tableDailyChallenges ADD COLUMN $columnSessionFeedback TEXT',
      );
    }
    if (!await _columnExists(
      db: db,
      tableName: tableDailyChallenges,
      columnName: columnSessionElapsedSeconds,
    )) {
      await db.execute(
        'ALTER TABLE $tableDailyChallenges ADD COLUMN $columnSessionElapsedSeconds INTEGER',
      );
    }
  }

  Future<void> _ensureUserStatsRow(DatabaseExecutor db) async {
    final rows = await db.query(
      tableUserStats,
      where: '$columnUserId = ?',
      whereArgs: <Object?>[_activeUserId],
      limit: 1,
    );
    if (rows.isNotEmpty) return;
    await db.insert(tableUserStats, <String, Object?>{
      columnUserId: _activeUserId,
      columnCurrentStreak: 0,
      columnLongestStreak: 0,
      columnTotalXp: 0,
      columnLastActiveDate: null,
      columnUpdatedAt: _nowIso(),
      columnIsSynced: 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _ensureWeeklyGoalRow(DatabaseExecutor db) async {
    final rows = await db.query(
      tableWeeklyWorkoutGoals,
      where: '$columnUserId = ?',
      whereArgs: <Object?>[_activeUserId],
      limit: 1,
    );
    if (rows.isNotEmpty) return;
    await db.insert(tableWeeklyWorkoutGoals, <String, Object?>{
      columnUserId: _activeUserId,
      columnTargetWorkouts: 3,
      columnUpdatedAt: _nowIso(),
      columnIsSynced: 0,
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

  Future<bool> _tableExists(DatabaseExecutor db, String tableName) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
      <Object?>[tableName],
    );
    return rows.isNotEmpty;
  }

  Future<void> _ensureUserStatsColumns(Database db, String nowIso) async {
    if (!await _columnExists(
      db: db,
      tableName: tableUserStats,
      columnName: columnUserId,
    )) {
      await db.execute(
        'ALTER TABLE $tableUserStats ADD COLUMN $columnUserId TEXT',
      );
    }
    if (!await _columnExists(
      db: db,
      tableName: tableUserStats,
      columnName: columnUpdatedAt,
    )) {
      await db.execute(
        'ALTER TABLE $tableUserStats ADD COLUMN $columnUpdatedAt TEXT',
      );
    }
    if (!await _columnExists(
      db: db,
      tableName: tableUserStats,
      columnName: columnIsSynced,
    )) {
      await db.execute(
        'ALTER TABLE $tableUserStats ADD COLUMN $columnIsSynced INTEGER NOT NULL DEFAULT 0',
      );
    }
    await db.rawUpdate(
      '''
      UPDATE $tableUserStats
      SET $columnUserId = COALESCE(NULLIF($columnUserId,''), ?),
          $columnUpdatedAt = COALESCE(NULLIF($columnUpdatedAt,''), ?),
          $columnIsSynced = 0
      ''',
      <Object?>[AuthContext.localUserId, nowIso],
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_user_stats_user_id ON $tableUserStats($columnUserId)',
    );
  }

  Future<void> _rebuildUserBadgesToScoped(Database db, String nowIso) async {
    if (!await _tableExists(db, tableUserBadges)) {
      await _createGamificationTables(db);
      return;
    }
    final hasUserId = await _columnExists(
      db: db,
      tableName: tableUserBadges,
      columnName: columnUserId,
    );
    if (hasUserId) return;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${tableUserBadges}_v4 (
        $columnUserId TEXT NOT NULL,
        $columnBadgeId TEXT NOT NULL,
        $columnUnlockedAt TEXT NOT NULL,
        $columnSourcePoseResultId INTEGER,
        $columnUpdatedAt TEXT NOT NULL,
        $columnIsSynced INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY($columnUserId, $columnBadgeId),
        FOREIGN KEY($columnBadgeId) REFERENCES $tableBadges($columnBadgeId),
        FOREIGN KEY($columnSourcePoseResultId) REFERENCES $tablePoseResults($columnId)
      )
    ''');
    await db.execute(
      '''
      INSERT INTO ${tableUserBadges}_v4 (
        $columnUserId, $columnBadgeId, $columnUnlockedAt,
        $columnSourcePoseResultId, $columnUpdatedAt, $columnIsSynced
      )
      SELECT ?, $columnBadgeId, $columnUnlockedAt, $columnSourcePoseResultId,
             COALESCE($columnUnlockedAt, ?), 0
      FROM $tableUserBadges
    ''',
      <Object?>[AuthContext.localUserId, nowIso],
    );
    await db.execute('DROP TABLE $tableUserBadges');
    await db.execute(
      'ALTER TABLE ${tableUserBadges}_v4 RENAME TO $tableUserBadges',
    );
  }

  Future<void> _rebuildDailyChallengesToScoped(
    Database db,
    String nowIso,
  ) async {
    if (!await _tableExists(db, tableDailyChallenges)) {
      await _createDailyChallengeTables(db);
      return;
    }
    final hasUserId = await _columnExists(
      db: db,
      tableName: tableDailyChallenges,
      columnName: columnUserId,
    );
    if (hasUserId) {
      if (!await _columnExists(
        db: db,
        tableName: tableDailyChallenges,
        columnName: columnIsSynced,
      )) {
        await db.execute(
          'ALTER TABLE $tableDailyChallenges ADD COLUMN $columnIsSynced INTEGER NOT NULL DEFAULT 0',
        );
      }
      await db.rawUpdate(
        'UPDATE $tableDailyChallenges SET $columnUserId = COALESCE(NULLIF($columnUserId,\'\'),?), $columnUpdatedAt = COALESCE(NULLIF($columnUpdatedAt,\'\'),?), $columnIsSynced = 0',
        <Object?>[AuthContext.localUserId, nowIso],
      );
      return;
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${tableDailyChallenges}_v4 (
        $columnUserId TEXT NOT NULL,
        $columnDateKey TEXT NOT NULL,
        $columnStatus TEXT NOT NULL DEFAULT 'in_progress',
        $columnSkipCount INTEGER NOT NULL DEFAULT 0,
        $columnTotalSteps INTEGER NOT NULL,
        $columnStartedAt TEXT,
        $columnCompletedAt TEXT,
        $columnUpdatedAt TEXT NOT NULL,
        $columnSequenceJson TEXT NOT NULL,
        $columnIsSynced INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY($columnUserId, $columnDateKey)
      )
    ''');
    await db.execute(
      '''
      INSERT INTO ${tableDailyChallenges}_v4 (
        $columnUserId, $columnDateKey, $columnStatus, $columnSkipCount, $columnTotalSteps,
        $columnStartedAt, $columnCompletedAt, $columnUpdatedAt, $columnSequenceJson, $columnIsSynced
      )
      SELECT ?, $columnDateKey, $columnStatus, $columnSkipCount, $columnTotalSteps,
             $columnStartedAt, $columnCompletedAt, COALESCE($columnUpdatedAt, ?), $columnSequenceJson, 0
      FROM $tableDailyChallenges
    ''',
      <Object?>[AuthContext.localUserId, nowIso],
    );
    await db.execute('DROP TABLE $tableDailyChallenges');
    await db.execute(
      'ALTER TABLE ${tableDailyChallenges}_v4 RENAME TO $tableDailyChallenges',
    );
  }

  Future<void> _rebuildDailyChallengeStepsToScoped(
    Database db,
    String nowIso,
  ) async {
    if (!await _tableExists(db, tableDailyChallengeSteps)) {
      await _createDailyChallengeTables(db);
      return;
    }
    final hasUserId = await _columnExists(
      db: db,
      tableName: tableDailyChallengeSteps,
      columnName: columnUserId,
    );
    if (hasUserId) {
      if (!await _columnExists(
        db: db,
        tableName: tableDailyChallengeSteps,
        columnName: columnIsSynced,
      )) {
        await db.execute(
          'ALTER TABLE $tableDailyChallengeSteps ADD COLUMN $columnIsSynced INTEGER NOT NULL DEFAULT 0',
        );
      }
      await db.rawUpdate(
        'UPDATE $tableDailyChallengeSteps SET $columnUserId = COALESCE(NULLIF($columnUserId,\'\'),?), $columnUpdatedAt = COALESCE(NULLIF($columnUpdatedAt,\'\'),?), $columnIsSynced = 0',
        <Object?>[AuthContext.localUserId, nowIso],
      );
      return;
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${tableDailyChallengeSteps}_v4 (
        $columnUserId TEXT NOT NULL,
        $columnDateKey TEXT NOT NULL,
        $columnStepIndex INTEGER NOT NULL,
        $columnPoseName TEXT NOT NULL,
        $columnStatus TEXT NOT NULL DEFAULT 'pending',
        $columnBestScore REAL,
        $columnHoldDuration REAL,
        $columnUpdatedAt TEXT,
        $columnIsSynced INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY($columnUserId, $columnDateKey, $columnStepIndex)
      )
    ''');
    await db.execute(
      '''
      INSERT INTO ${tableDailyChallengeSteps}_v4 (
        $columnUserId, $columnDateKey, $columnStepIndex, $columnPoseName,
        $columnStatus, $columnBestScore, $columnHoldDuration, $columnUpdatedAt, $columnIsSynced
      )
      SELECT ?, $columnDateKey, $columnStepIndex, $columnPoseName,
             $columnStatus, $columnBestScore, $columnHoldDuration, COALESCE($columnUpdatedAt, ?), 0
      FROM $tableDailyChallengeSteps
    ''',
      <Object?>[AuthContext.localUserId, nowIso],
    );
    await db.execute('DROP TABLE $tableDailyChallengeSteps');
    await db.execute(
      'ALTER TABLE ${tableDailyChallengeSteps}_v4 RENAME TO $tableDailyChallengeSteps',
    );
  }

  Future<int> insertPoseResult(PoseResult result) async {
    final db = await database;
    final nowIso = _nowIso();
    final values = result.toMap();
    values[columnRecordId] = _generateRecordId();
    values[columnUserId] = _activeUserId;
    values[columnTimestamp] ??= nowIso;
    values[columnUpdatedAt] = nowIso;
    values[columnIsSynced] = 0;
    values[columnGamificationProcessed] = 0;
    final id = await db.insert(tablePoseResults, values);
    notifyLocalMutation();
    return id;
  }

  Future<List<PoseResult>> getAllResults() async {
    final db = await database;
    final rows = await db.query(
      tablePoseResults,
      where: '$columnUserId = ?',
      whereArgs: <Object?>[_activeUserId],
      orderBy: '$columnTimestamp DESC',
    );
    return rows.map(PoseResult.fromMap).toList();
  }

  Future<PoseResult?> getPoseResultById(int id) async {
    final db = await database;
    final rows = await db.query(
      tablePoseResults,
      where: '$columnUserId = ? AND $columnId = ?',
      whereArgs: <Object?>[_activeUserId, id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PoseResult.fromMap(rows.first);
  }

  Future<double?> getBestScoreForPose(String poseName) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT MAX($columnBestScore) as max_score FROM $tablePoseResults WHERE $columnPoseName = ? AND $columnUserId = ?',
      <Object?>[poseName, _activeUserId],
    );
    final value = rows.first['max_score'];
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Future<UserStats> getUserStats() async {
    final db = await database;
    await _ensureUserStatsRow(db);
    final rows = await db.query(
      tableUserStats,
      where: '$columnUserId = ?',
      whereArgs: <Object?>[_activeUserId],
      limit: 1,
    );
    if (rows.isEmpty) return const UserStats.initial();
    return UserStats.fromMap(rows.first);
  }

  Future<int> getUnlockedBadgeCount() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableUserBadges WHERE $columnUserId = ?',
      <Object?>[_activeUserId],
    );
    final value = rows.first['count'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<List<BadgeDefinition>> getBadgeDefinitions() async {
    final db = await database;
    final rows = await db.query(
      tableBadges,
      orderBy: '$columnBadgeCriteriaValue ASC, $columnBadgeName ASC',
    );
    return rows.map(BadgeDefinition.fromMap).toList(growable: false);
  }

  Future<List<UnlockedBadge>> getUnlockedBadges() async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT ub.$columnBadgeId, b.$columnBadgeName, b.$columnBadgeDescription, ub.$columnUnlockedAt
      FROM $tableUserBadges ub
      INNER JOIN $tableBadges b ON b.$columnBadgeId = ub.$columnBadgeId
      WHERE ub.$columnUserId = ?
      ORDER BY ub.$columnUnlockedAt DESC
      ''',
      <Object?>[_activeUserId],
    );
    return rows.map(UnlockedBadge.fromMap).toList(growable: false);
  }

  Future<List<UnlockedBadge>> getLatestUnlockedBadges({int limit = 5}) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT ub.$columnBadgeId, b.$columnBadgeName, b.$columnBadgeDescription, ub.$columnUnlockedAt
      FROM $tableUserBadges ub
      INNER JOIN $tableBadges b ON b.$columnBadgeId = ub.$columnBadgeId
      WHERE ub.$columnUserId = ?
      ORDER BY ub.$columnUnlockedAt DESC
      LIMIT ?
      ''',
      <Object?>[_activeUserId, limit],
    );
    return rows.map(UnlockedBadge.fromMap).toList();
  }

  Future<WeeklyWorkoutGoal> getWeeklyWorkoutGoal() async {
    final db = await database;
    await _ensureWeeklyGoalRow(db);
    final rows = await db.query(
      tableWeeklyWorkoutGoals,
      where: '$columnUserId = ?',
      whereArgs: <Object?>[_activeUserId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return WeeklyWorkoutGoal.defaultForUser(_activeUserId);
    }
    return WeeklyWorkoutGoal.fromMap(rows.first);
  }

  Future<void> incrementTotalXp(int delta) async {
    if (delta == 0) return;
    final db = await database;
    await _ensureUserStatsRow(db);
    final rows = await db.query(
      tableUserStats,
      columns: <String>[columnTotalXp],
      where: '$columnUserId = ?',
      whereArgs: <Object?>[_activeUserId],
      limit: 1,
    );
    final currentXp = rows.isEmpty
        ? 0
        : (rows.first[columnTotalXp] as num?)?.toInt() ?? 0;
    final nextXp = currentXp + delta;
    await db.update(
      tableUserStats,
      <String, Object?>{
        columnTotalXp: nextXp,
        columnUpdatedAt: _nowIso(),
        columnIsSynced: 0,
      },
      where: '$columnUserId = ?',
      whereArgs: <Object?>[_activeUserId],
    );
    notifyLocalMutation();
  }

  Future<void> upsertWeeklyWorkoutGoal({required int targetWorkouts}) async {
    final db = await database;
    final clampedTarget = targetWorkouts.clamp(1, 14);
    final nowIso = _nowIso();
    await db.insert(tableWeeklyWorkoutGoals, <String, Object?>{
      columnUserId: _activeUserId,
      columnTargetWorkouts: clampedTarget,
      columnUpdatedAt: nowIso,
      columnIsSynced: 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    notifyLocalMutation();
  }

  Future<void> insertBodyMeasurement(BodyMeasurement measurement) async {
    final db = await database;
    final nowIso = _nowIso();
    final payload = measurement.toMap();
    payload[columnUserId] = _activeUserId;
    payload[columnUpdatedAt] = nowIso;
    payload[columnIsSynced] = 0;
    await db.insert(
      tableBodyMeasurements,
      payload,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyLocalMutation();
  }

  Future<List<BodyMeasurement>> getBodyMeasurementHistory(
    BodyMetricType metricType, {
    int limit = 30,
  }) async {
    final db = await database;
    final rows = await db.query(
      tableBodyMeasurements,
      where: '$columnUserId = ? AND $columnMetricKey = ?',
      whereArgs: <Object?>[_activeUserId, metricType.metricKey],
      orderBy: '$columnMeasuredAt DESC',
      limit: limit,
    );
    return rows.map(BodyMeasurement.fromMap).toList(growable: false);
  }

  Future<BodyMeasurement?> getLatestBodyMeasurement(
    BodyMetricType metricType,
  ) async {
    final rows = await getBodyMeasurementHistory(metricType, limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> insertDailyChallenge({
    required DailyChallenge challenge,
    required List<DailyChallengeStep> steps,
  }) async {
    final db = await database;
    final nowIso = _nowIso();
    await db.transaction((tx) async {
      final challengeMap = challenge.toMap();
      challengeMap[columnUserId] = _activeUserId;
      challengeMap[columnUpdatedAt] ??= nowIso;
      challengeMap[columnIsSynced] = 0;
      await tx.insert(
        tableDailyChallenges,
        challengeMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final step in steps) {
        final stepMap = step.toMap();
        stepMap[columnUserId] = _activeUserId;
        stepMap[columnUpdatedAt] ??= nowIso;
        stepMap[columnIsSynced] = 0;
        await tx.insert(
          tableDailyChallengeSteps,
          stepMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    notifyLocalMutation();
  }

  Future<DailyChallenge?> getDailyChallengeByDateKey(String dateKey) async {
    final db = await database;
    final rows = await db.query(
      tableDailyChallenges,
      where: '$columnUserId = ? AND $columnDateKey = ?',
      whereArgs: <Object?>[_activeUserId, dateKey],
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
      where: '$columnUserId = ? AND $columnDateKey = ?',
      whereArgs: <Object?>[_activeUserId, dateKey],
      orderBy: '$columnStepIndex ASC',
    );
    return rows.map(DailyChallengeStep.fromMap).toList();
  }

  Future<void> updateDailyChallenge(DailyChallenge challenge) async {
    final db = await database;
    final map = challenge.toMap();
    map[columnUserId] = _activeUserId;
    map[columnUpdatedAt] = _nowIso();
    map[columnIsSynced] = 0;
    await db.update(
      tableDailyChallenges,
      map,
      where: '$columnUserId = ? AND $columnDateKey = ?',
      whereArgs: <Object?>[_activeUserId, challenge.dateKey],
    );
    notifyLocalMutation();
  }

  Future<void> updateDailyChallengeStep(DailyChallengeStep step) async {
    final db = await database;
    final map = step.toMap();
    map[columnUserId] = _activeUserId;
    map[columnUpdatedAt] = _nowIso();
    map[columnIsSynced] = 0;
    await db.update(
      tableDailyChallengeSteps,
      map,
      where:
          '$columnUserId = ? AND $columnDateKey = ? AND $columnStepIndex = ?',
      whereArgs: <Object?>[_activeUserId, step.dateKey, step.stepIndex],
    );
    notifyLocalMutation();
  }

  Future<List<UserProfileChallengeState>> getProfileChallengeStatesForMonth(
    String monthKey,
  ) async {
    final db = await database;
    final rows = await db.query(
      tableUserProfileChallenges,
      where: '$columnUserId = ? AND $columnMonthKey = ?',
      whereArgs: <Object?>[_activeUserId, monthKey],
      orderBy: '$columnUpdatedAt DESC',
    );
    return rows.map(UserProfileChallengeState.fromMap).toList(growable: false);
  }

  Future<UserProfileChallengeState?> getProfileChallengeState({
    required String monthKey,
    required String challengeId,
  }) async {
    final db = await database;
    final rows = await db.query(
      tableUserProfileChallenges,
      where:
          '$columnUserId = ? AND $columnMonthKey = ? AND $columnChallengeId = ?',
      whereArgs: <Object?>[_activeUserId, monthKey, challengeId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserProfileChallengeState.fromMap(rows.first);
  }

  Future<void> upsertProfileChallengeState(
    UserProfileChallengeState state,
  ) async {
    final db = await database;
    final map = state.toMap();
    map[columnUserId] = _activeUserId;
    map[columnUpdatedAt] = _nowIso();
    map[columnIsSynced] = 0;
    await db.insert(
      tableUserProfileChallenges,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyLocalMutation();
  }

  List<String> tableKeyColumns(String tableName) {
    switch (tableName) {
      case tablePoseResults:
        return <String>[columnUserId, columnRecordId];
      case tableUserStats:
        return <String>[columnUserId];
      case tableUserBadges:
        return <String>[columnUserId, columnBadgeId];
      case tableDailyChallenges:
        return <String>[columnUserId, columnDateKey];
      case tableDailyChallengeSteps:
        return <String>[columnUserId, columnDateKey, columnStepIndex];
      case tableWeeklyWorkoutGoals:
        return <String>[columnUserId];
      case tableBodyMeasurements:
        return <String>[columnUserId, columnMetricKey, columnMeasuredAt];
      case tableUserProfileChallenges:
        return <String>[columnUserId, columnMonthKey, columnChallengeId];
      default:
        throw ArgumentError('Unsupported sync table: $tableName');
    }
  }

  Future<List<Map<String, Object?>>> getUnsyncedRows({
    required String tableName,
    int limit = 200,
  }) async {
    final db = await database;
    return db.query(
      tableName,
      where: '$columnUserId = ? AND $columnIsSynced = 0',
      whereArgs: <Object?>[_activeUserId],
      orderBy: '$columnUpdatedAt ASC',
      limit: limit,
    );
  }

  Future<Map<String, Object?>?> getRowByKeys({
    required String tableName,
    required Map<String, Object?> keyValues,
  }) async {
    final db = await database;
    final where = keyValues.keys.map((k) => '$k = ?').join(' AND ');
    final args = keyValues.values.toList(growable: false);
    final rows = await db.query(
      tableName,
      where: where,
      whereArgs: args,
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> markRowSynced({
    required String tableName,
    required Map<String, Object?> keyValues,
  }) async {
    final db = await database;
    final where = keyValues.keys.map((k) => '$k = ?').join(' AND ');
    final args = keyValues.values.toList(growable: false);
    await db.update(
      tableName,
      <String, Object?>{columnIsSynced: 1},
      where: where,
      whereArgs: args,
    );
  }

  Future<void> upsertRowFromSync({
    required String tableName,
    required Map<String, Object?> row,
  }) async {
    final db = await database;
    final keys = <String, Object?>{
      for (final key in tableKeyColumns(tableName)) key: row[key],
    };
    final where = keys.keys.map((k) => '$k = ?').join(' AND ');
    final args = keys.values.toList(growable: false);
    final normalized = Map<String, Object?>.from(row)..[columnIsSynced] = 1;
    final updated = await db.update(
      tableName,
      normalized,
      where: where,
      whereArgs: args,
    );
    if (updated == 0) {
      await db.insert(
        tableName,
        normalized,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  void notifyLocalMutation() {
    if (!_mutationController.isClosed) _mutationController.add(null);
  }

  Future<void> close() async {
    if (_database == null) return;
    try {
      await _database!.close();
    } catch (e, stackTrace) {
      _logError('Failed to close database.', e, stackTrace);
      rethrow;
    } finally {
      _database = null;
      _databaseInit = null;
    }
  }

  String _nowIso() => DateTime.now().toUtc().toIso8601String();

  String _generateRecordId() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final rand = List<int>.generate(
      8,
      (_) => _rng.nextInt(256),
    ).map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '$ts$rand';
  }

  void _logError(String message, Object error, StackTrace stackTrace) {
    log(message, error: error, stackTrace: stackTrace, name: 'DatabaseService');
  }
}
