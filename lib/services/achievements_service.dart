import '../models/badge_definition.dart';
import '../models/badge_progress_snapshot.dart';
import '../models/pose_result.dart';
import '../models/unlocked_badge.dart';
import '../models/user_stats.dart';

class AchievementsService {
  const AchievementsService();

  List<BadgeProgressSnapshot> buildBadgeProgress({
    required List<BadgeDefinition> definitions,
    required List<UnlockedBadge> unlockedBadges,
    required List<PoseResult> results,
    required UserStats userStats,
  }) {
    final completed = results.where((r) => r.completed).toList(growable: false);
    final completedSessions = completed.length;
    final currentStreak = userStats.currentStreak;
    final bestScore = completed.isEmpty
        ? 0.0
        : completed.map((r) => r.bestScore).reduce((a, b) => a > b ? a : b);
    final unlockedById = {
      for (final badge in unlockedBadges)
        if (badge.badgeId.isNotEmpty) badge.badgeId: badge,
    };

    final snapshots = definitions
        .map((definition) {
          final currentValue = _currentValueForDefinition(
            definition: definition,
            completedSessions: completedSessions,
            currentStreak: currentStreak,
            bestScore: bestScore,
          );
          final targetValue = definition.criteriaValue;
          final ratio = targetValue <= 0
              ? 1.0
              : (currentValue / targetValue).clamp(0.0, 1.0);
          final unlocked = unlockedById[definition.id];
          return BadgeProgressSnapshot(
            definition: definition,
            isUnlocked: unlocked != null,
            unlockedAt: unlocked?.unlockedAt,
            currentValue: currentValue,
            targetValue: targetValue,
            progressRatio: ratio,
            progressLabel:
                '${_formatProgressNumber(currentValue)} of ${_formatProgressNumber(targetValue)}',
          );
        })
        .toList(growable: false);

    snapshots.sort((a, b) {
      if (a.isUnlocked != b.isUnlocked) {
        return a.isUnlocked ? -1 : 1;
      }
      if (a.isUnlocked && b.isUnlocked) {
        final at = a.unlockedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.unlockedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      }
      if (a.targetValue != b.targetValue) {
        return a.targetValue.compareTo(b.targetValue);
      }
      return a.definition.name.compareTo(b.definition.name);
    });
    return snapshots;
  }

  List<BadgeProgressSnapshot> previewBadges(
    List<BadgeProgressSnapshot> snapshots, {
    int limit = 3,
  }) {
    if (limit < 1) return const <BadgeProgressSnapshot>[];
    return snapshots.take(limit).toList(growable: false);
  }

  double _currentValueForDefinition({
    required BadgeDefinition definition,
    required int completedSessions,
    required int currentStreak,
    required double bestScore,
  }) {
    return switch (definition.criteriaType) {
      'completed_sessions' => completedSessions.toDouble(),
      'streak' => currentStreak.toDouble(),
      'score' => bestScore,
      _ => 0.0,
    };
  }

  String _formatProgressNumber(double value) {
    if ((value - value.roundToDouble()).abs() < 0.001) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }
}
