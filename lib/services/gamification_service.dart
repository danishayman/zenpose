import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../models/pose_result.dart';
import '../models/unlocked_badge.dart';
import '../models/user_stats.dart';
import 'auth_context.dart';
import 'badge_catalog.dart';
import 'database_service.dart';

/// Result of processing a completed session through local gamification rules.
class GamificationProcessResult {
  final bool alreadyProcessed;
  final int xpGained;
  final UserStats userStats;
  final List<UnlockedBadge> unlockedBadges;

  const GamificationProcessResult({
    required this.alreadyProcessed,
    required this.xpGained,
    required this.userStats,
    required this.unlockedBadges,
  });
}

/// Derived streak state for a specific activity date.
class StreakUpdate {
  final int currentStreak;
  final int longestStreak;

  const StreakUpdate({
    required this.currentStreak,
    required this.longestStreak,
  });
}

/// Offline-first gamification processor (streaks + XP + badges).
class GamificationService {
  final DatabaseService _databaseService;

  GamificationService({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService.instance;

  /// Base XP granted for every completed session.
  static const int baseXp = 50;

  /// Process one completed session exactly once.
  ///
  /// Idempotency is guaranteed via the `gamification_processed` flag
  /// on the corresponding `pose_results` row.
  Future<GamificationProcessResult> processCompletedSession(
    PoseResult result,
  ) async {
    if (!result.completed) {
      return GamificationProcessResult(
        alreadyProcessed: true,
        xpGained: 0,
        userStats: await _databaseService.getUserStats(),
        unlockedBadges: const <UnlockedBadge>[],
      );
    }

    final resultId = result.id;
    if (resultId == null) {
      throw ArgumentError(
        'PoseResult.id is required for idempotent gamification processing.',
      );
    }

    final activeUserId = AuthContext.activeUserId;
    final db = await _databaseService.database;
    final outcome = await db.transaction((Transaction tx) async {
      final resultRows = await tx.query(
        DatabaseService.tablePoseResults,
        columns: <String>[
          DatabaseService.columnId,
          DatabaseService.columnCompleted,
          DatabaseService.columnGamificationProcessed,
        ],
        where:
            '${DatabaseService.columnId} = ? AND ${DatabaseService.columnUserId} = ?',
        whereArgs: <Object?>[resultId, activeUserId],
        limit: 1,
      );

      if (resultRows.isEmpty) {
        throw StateError('No pose result found for id=$resultId');
      }

      final resultRow = resultRows.first;
      final alreadyProcessed =
          (resultRow[DatabaseService.columnGamificationProcessed] as int? ??
              0) ==
          1;
      if (alreadyProcessed) {
        return GamificationProcessResult(
          alreadyProcessed: true,
          xpGained: 0,
          userStats: await _readUserStats(tx),
          unlockedBadges: const <UnlockedBadge>[],
        );
      }

      final currentStats = await _readUserStats(tx);
      final activityDate = _dateOnly(result.timestamp ?? DateTime.now());
      final streakUpdate = computeStreakUpdate(
        currentStreak: currentStats.currentStreak,
        longestStreak: currentStats.longestStreak,
        lastActiveDate: currentStats.lastActiveDate,
        activityDate: activityDate,
      );
      final xpGained = calculateXpGain(result.bestScore);
      final totalXp = currentStats.totalXp + xpGained;

      await tx.update(
        DatabaseService.tableUserStats,
        <String, Object?>{
          DatabaseService.columnCurrentStreak: streakUpdate.currentStreak,
          DatabaseService.columnLongestStreak: streakUpdate.longestStreak,
          DatabaseService.columnTotalXp: totalXp,
          DatabaseService.columnLastActiveDate: _dateKey(activityDate),
          DatabaseService.columnUpdatedAt: DateTime.now()
              .toUtc()
              .toIso8601String(),
          DatabaseService.columnIsSynced: 0,
        },
        where: '${DatabaseService.columnUserId} = ?',
        whereArgs: <Object?>[activeUserId],
      );

      final completedCount = await _countCompletedSessions(tx);
      final existingBadgeIds = await _getUnlockedBadgeIdSet(tx);
      final bestCompletedScore = await _getBestCompletedScore(tx);
      final badgeIdsToUnlock = determineBadgeUnlocks(
        existingBadgeIds: existingBadgeIds,
        completedSessions: completedCount,
        currentStreak: streakUpdate.currentStreak,
        bestScore: bestCompletedScore,
      );

      final unlockedAt = DateTime.now().toIso8601String();
      for (final badgeId in badgeIdsToUnlock) {
        await tx.insert(
          DatabaseService.tableUserBadges,
          <String, Object?>{
            DatabaseService.columnUserId: activeUserId,
            DatabaseService.columnBadgeId: badgeId,
            DatabaseService.columnUnlockedAt: unlockedAt,
            DatabaseService.columnSourcePoseResultId: resultId,
            DatabaseService.columnUpdatedAt: unlockedAt,
            DatabaseService.columnIsSynced: 0,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      await tx.update(
        DatabaseService.tablePoseResults,
        <String, Object?>{
          DatabaseService.columnGamificationProcessed: 1,
          DatabaseService.columnUpdatedAt: DateTime.now()
              .toUtc()
              .toIso8601String(),
          DatabaseService.columnIsSynced: 0,
        },
        where:
            '${DatabaseService.columnId} = ? AND ${DatabaseService.columnUserId} = ?',
        whereArgs: <Object?>[resultId, activeUserId],
      );

      final unlockedBadges = await _loadBadgesByIds(
        tx,
        badgeIdsToUnlock,
        activeUserId,
      );
      final updatedStats = UserStats(
        currentStreak: streakUpdate.currentStreak,
        longestStreak: streakUpdate.longestStreak,
        totalXp: totalXp,
        lastActiveDate: activityDate,
      );

      return GamificationProcessResult(
        alreadyProcessed: false,
        xpGained: xpGained,
        userStats: updatedStats,
        unlockedBadges: unlockedBadges,
      );
    });
    if (!outcome.alreadyProcessed) {
      _databaseService.notifyLocalMutation();
    }
    return outcome;
  }

  /// Compute streak changes based on date continuity.
  static StreakUpdate computeStreakUpdate({
    required int currentStreak,
    required int longestStreak,
    required DateTime? lastActiveDate,
    required DateTime activityDate,
  }) {
    final normalizedActivityDate = _dateOnly(activityDate);

    int nextCurrentStreak;
    if (lastActiveDate == null) {
      nextCurrentStreak = 1;
    } else {
      final normalizedLast = _dateOnly(lastActiveDate);
      final dayDiff = normalizedActivityDate.difference(normalizedLast).inDays;
      if (dayDiff == 0) {
        nextCurrentStreak = currentStreak;
      } else if (dayDiff == 1) {
        nextCurrentStreak = currentStreak + 1;
      } else {
        nextCurrentStreak = 1;
      }
    }

    final nextLongestStreak = max(longestStreak, nextCurrentStreak);
    return StreakUpdate(
      currentStreak: nextCurrentStreak,
      longestStreak: nextLongestStreak,
    );
  }

  /// XP rule: fixed base + rounded score bonus.
  static int calculateXpGain(double bestScore) {
    final normalizedScore = bestScore.clamp(0, 100).round();
    return baseXp + normalizedScore;
  }

  /// Criteria-driven badge rule evaluator with duplicate protection.
  static List<String> determineBadgeUnlocks({
    required Set<String> existingBadgeIds,
    required int completedSessions,
    required int currentStreak,
    required double bestScore,
  }) {
    return BadgeCatalog.defaultBadges
        .where((badge) => !existingBadgeIds.contains(badge.id))
        .where((badge) {
          final target = badge.criteriaValue;
          return switch (badge.criteriaType) {
            'completed_sessions' => completedSessions >= target,
            'streak' => currentStreak >= target,
            'score' => bestScore >= target,
            _ => false,
          };
        })
        .map((badge) => badge.id)
        .toList(growable: false);
  }

  Future<UserStats> _readUserStats(DatabaseExecutor db) async {
    final activeUserId = AuthContext.activeUserId;
    await db.insert(DatabaseService.tableUserStats, <String, Object?>{
      DatabaseService.columnUserId: activeUserId,
      DatabaseService.columnCurrentStreak: 0,
      DatabaseService.columnLongestStreak: 0,
      DatabaseService.columnTotalXp: 0,
      DatabaseService.columnLastActiveDate: null,
      DatabaseService.columnUpdatedAt: DateTime.now().toUtc().toIso8601String(),
      DatabaseService.columnIsSynced: 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final rows = await db.query(
      DatabaseService.tableUserStats,
      where: '${DatabaseService.columnUserId} = ?',
      whereArgs: <Object?>[activeUserId],
      limit: 1,
    );
    if (rows.isEmpty) return const UserStats.initial();
    return UserStats.fromMap(rows.first);
  }

  Future<int> _countCompletedSessions(DatabaseExecutor db) async {
    final activeUserId = AuthContext.activeUserId;
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM ${DatabaseService.tablePoseResults}
      WHERE ${DatabaseService.columnCompleted} = 1
        AND ${DatabaseService.columnUserId} = ?
      ''',
      <Object?>[activeUserId],
    );
    if (rows.isEmpty) return 0;
    final value = rows.first['count'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<double> _getBestCompletedScore(DatabaseExecutor db) async {
    final activeUserId = AuthContext.activeUserId;
    final rows = await db.rawQuery(
      '''
      SELECT MAX(${DatabaseService.columnBestScore}) as max_score
      FROM ${DatabaseService.tablePoseResults}
      WHERE ${DatabaseService.columnCompleted} = 1
        AND ${DatabaseService.columnUserId} = ?
      ''',
      <Object?>[activeUserId],
    );
    if (rows.isEmpty) return 0;
    final value = rows.first['max_score'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<Set<String>> _getUnlockedBadgeIdSet(DatabaseExecutor db) async {
    final activeUserId = AuthContext.activeUserId;
    final rows = await db.query(
      DatabaseService.tableUserBadges,
      columns: <String>[DatabaseService.columnBadgeId],
      where: '${DatabaseService.columnUserId} = ?',
      whereArgs: <Object?>[activeUserId],
    );
    return rows
        .map((row) => row[DatabaseService.columnBadgeId]?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<List<UnlockedBadge>> _loadBadgesByIds(
    DatabaseExecutor db,
    List<String> badgeIds,
    String activeUserId,
  ) async {
    if (badgeIds.isEmpty) return const <UnlockedBadge>[];

    final placeholders = List<String>.filled(badgeIds.length, '?').join(', ');
    final rows = await db.rawQuery(
      '''
      SELECT ub.${DatabaseService.columnBadgeId},
             b.${DatabaseService.columnBadgeName},
             b.${DatabaseService.columnBadgeDescription},
             ub.${DatabaseService.columnUnlockedAt}
      FROM ${DatabaseService.tableUserBadges} ub
      INNER JOIN ${DatabaseService.tableBadges} b
        ON b.${DatabaseService.columnBadgeId} = ub.${DatabaseService.columnBadgeId}
      WHERE ub.${DatabaseService.columnUserId} = ?
        AND ub.${DatabaseService.columnBadgeId} IN ($placeholders)
      ORDER BY ub.${DatabaseService.columnUnlockedAt} DESC
      ''',
      <Object?>[activeUserId, ...badgeIds.cast<Object?>()],
    );
    return rows.map(UnlockedBadge.fromMap).toList();
  }

  static DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static String _dateKey(DateTime date) {
    final local = _dateOnly(date);
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
