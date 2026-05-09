import 'body_measurement.dart';

class DailyWorkoutPoint {
  final DateTime day;
  final int workouts;

  const DailyWorkoutPoint({required this.day, required this.workouts});
}

class ExerciseTrendSnapshot {
  final String poseName;
  final DateTime? lastPerformedAt;
  final List<double> recentScores;
  final int sessionCount;
  final int trendWindowSize;
  final double recentWindowAverage;
  final double? previousWindowAverage;
  final double? windowTrendDelta;
  final bool hasEnoughTrendData;
  final double latestScore;
  final double bestScore;
  final double deltaScore;
  final double averageHoldDuration;

  const ExerciseTrendSnapshot({
    required this.poseName,
    required this.lastPerformedAt,
    required this.recentScores,
    required this.sessionCount,
    required this.trendWindowSize,
    required this.recentWindowAverage,
    required this.previousWindowAverage,
    required this.windowTrendDelta,
    required this.hasEnoughTrendData,
    required this.latestScore,
    required this.bestScore,
    required this.deltaScore,
    required this.averageHoldDuration,
  });
}

class MeasureTrendSnapshot {
  final BodyMetricType metricType;
  final List<BodyMeasurement> history;
  final double? latestValue;
  final double? deltaValue;

  const MeasureTrendSnapshot({
    required this.metricType,
    required this.history,
    required this.latestValue,
    required this.deltaValue,
  });
}

class MonthlyWorkoutSummary {
  final DateTime month;
  final int totalWorkouts;
  final List<DailyWorkoutPoint> dailyPoints;
  final Set<String> activeDateKeys;

  const MonthlyWorkoutSummary({
    required this.month,
    required this.totalWorkouts,
    required this.dailyPoints,
    required this.activeDateKeys,
  });
}
