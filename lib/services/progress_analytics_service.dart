import '../models/body_measurement.dart';
import '../models/pose_result.dart';
import '../models/progress_analytics_models.dart';

class ProgressAnalyticsService {
  const ProgressAnalyticsService();
  static const int _exerciseTrendWindowSize = 5;

  MonthlyWorkoutSummary buildMonthlySummary({
    required List<PoseResult> results,
    required DateTime month,
  }) {
    final monthStart = DateTime(month.year, month.month, 1);
    final nextMonthStart = DateTime(month.year, month.month + 1, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final completed = _completedResults(results);
    final activeDateKeys = <String>{};
    final counts = <String, int>{};

    for (final result in completed) {
      final timestamp = result.timestamp?.toLocal();
      if (timestamp == null) continue;
      if (timestamp.isBefore(monthStart) ||
          !timestamp.isBefore(nextMonthStart)) {
        continue;
      }
      final key = _dateKey(timestamp);
      activeDateKeys.add(key);
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final dailyPoints = <DailyWorkoutPoint>[];
    var total = 0;
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final value = counts[_dateKey(date)] ?? 0;
      total += value;
      dailyPoints.add(DailyWorkoutPoint(day: date, workouts: value));
    }

    return MonthlyWorkoutSummary(
      month: monthStart,
      totalWorkouts: total,
      dailyPoints: dailyPoints,
      activeDateKeys: activeDateKeys,
    );
  }

  int countWeeklyCompleted({
    required List<PoseResult> results,
    required DateTime anchorDate,
  }) {
    final completed = _completedResults(results);
    final localAnchor = anchorDate.toLocal();
    final weekStart = startOfSundayWeek(localAnchor);
    final weekEnd = weekStart.add(const Duration(days: 7));
    var total = 0;

    for (final result in completed) {
      final timestamp = result.timestamp?.toLocal();
      if (timestamp == null) continue;
      if (!timestamp.isBefore(weekStart) && timestamp.isBefore(weekEnd)) {
        total += 1;
      }
    }
    return total;
  }

  List<ExerciseTrendSnapshot> buildExerciseTrends(List<PoseResult> results) {
    final completed = _completedResults(results);
    final grouped = <String, List<PoseResult>>{};
    for (final result in completed) {
      grouped.putIfAbsent(result.poseName, () => <PoseResult>[]).add(result);
    }
    final snapshots = <ExerciseTrendSnapshot>[];

    for (final entry in grouped.entries) {
      final rows = entry.value
        ..sort((a, b) {
          final at = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bt = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bt.compareTo(at);
        });
      final latest = rows.first;
      final latestScore = latest.bestScore;
      final previousScore = rows.length > 1 ? rows[1].bestScore : latestScore;
      final bestScore = rows
          .map((e) => e.bestScore)
          .reduce((a, b) => a > b ? a : b);
      final averageHold =
          rows.map((e) => e.holdDuration).reduce((a, b) => a + b) / rows.length;
      final recentWindow = rows.take(_exerciseTrendWindowSize).toList();
      final previousWindow = rows
          .skip(_exerciseTrendWindowSize)
          .take(_exerciseTrendWindowSize)
          .toList();
      final recentWindowAverage = _averageScore(recentWindow);
      final previousWindowAverage = previousWindow.isEmpty
          ? null
          : _averageScore(previousWindow);
      final windowTrendDelta = previousWindowAverage == null
          ? null
          : recentWindowAverage - previousWindowAverage;
      final hasEnoughTrendData = rows.length >= 6;
      final recent = rows.take(10).toList().reversed;
      snapshots.add(
        ExerciseTrendSnapshot(
          poseName: entry.key,
          lastPerformedAt: latest.timestamp?.toLocal(),
          recentScores: recent.map((e) => e.bestScore).toList(growable: false),
          sessionCount: rows.length,
          trendWindowSize: _exerciseTrendWindowSize,
          recentWindowAverage: recentWindowAverage,
          previousWindowAverage: previousWindowAverage,
          windowTrendDelta: windowTrendDelta,
          hasEnoughTrendData: hasEnoughTrendData,
          latestScore: latestScore,
          bestScore: bestScore,
          deltaScore: latestScore - previousScore,
          averageHoldDuration: averageHold,
        ),
      );
    }

    snapshots.sort((a, b) {
      final at = a.lastPerformedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.lastPerformedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return snapshots;
  }

  MeasureTrendSnapshot buildMeasureTrend({
    required BodyMetricType metricType,
    required List<BodyMeasurement> history,
  }) {
    final sorted = List<BodyMeasurement>.from(history)
      ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    final latest = sorted.isEmpty ? null : sorted.first.value;
    final delta = sorted.length >= 2
        ? sorted.first.value - sorted[1].value
        : null;
    return MeasureTrendSnapshot(
      metricType: metricType,
      history: sorted,
      latestValue: latest,
      deltaValue: delta,
    );
  }

  DateTime startOfSundayWeek(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    final daysSinceSunday = local.weekday % 7;
    return local.subtract(Duration(days: daysSinceSunday));
  }

  List<PoseResult> _completedResults(List<PoseResult> results) {
    return results.where((result) => result.completed).toList(growable: false);
  }

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  double _averageScore(List<PoseResult> items) {
    final total = items.map((e) => e.bestScore).reduce((a, b) => a + b);
    return total / items.length;
  }
}
