import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/models/body_measurement.dart';
import 'package:zenpose/models/pose_result.dart';
import 'package:zenpose/services/progress_analytics_service.dart';

void main() {
  const service = ProgressAnalyticsService();

  test('buildMonthlySummary counts completed sessions only', () {
    final results = <PoseResult>[
      PoseResult(
        poseName: 'Tree',
        bestScore: 80,
        holdDuration: 30,
        completed: true,
        timestamp: DateTime(2026, 4, 2, 10, 0),
      ),
      PoseResult(
        poseName: 'Tree',
        bestScore: 82,
        holdDuration: 30,
        completed: false,
        timestamp: DateTime(2026, 4, 2, 10, 5),
      ),
      PoseResult(
        poseName: 'Plank',
        bestScore: 86,
        holdDuration: 45,
        completed: true,
        timestamp: DateTime(2026, 4, 9, 7, 30),
      ),
    ];

    final summary = service.buildMonthlySummary(
      results: results,
      month: DateTime(2026, 4, 1),
    );
    expect(summary.totalWorkouts, equals(2));
    expect(summary.activeDateKeys.contains('2026-04-02'), isTrue);
    expect(summary.activeDateKeys.contains('2026-04-09'), isTrue);
  });

  test('countWeeklyCompleted uses Sunday start', () {
    final results = <PoseResult>[
      PoseResult(
        poseName: 'Tree',
        bestScore: 80,
        holdDuration: 30,
        completed: true,
        timestamp: DateTime(2026, 4, 5, 8, 0), // Sunday
      ),
      PoseResult(
        poseName: 'Plank',
        bestScore: 85,
        holdDuration: 35,
        completed: true,
        timestamp: DateTime(2026, 4, 7, 8, 0), // Tuesday
      ),
      PoseResult(
        poseName: 'Warrior2',
        bestScore: 90,
        holdDuration: 35,
        completed: true,
        timestamp: DateTime(2026, 4, 12, 8, 0), // next Sunday
      ),
    ];

    final count = service.countWeeklyCompleted(
      results: results,
      anchorDate: DateTime(2026, 4, 9, 12, 0),
    );
    expect(count, equals(2));
  });

  test('buildExerciseTrends sorts by most recent performed', () {
    final results = <PoseResult>[
      PoseResult(
        poseName: 'Tree',
        bestScore: 80,
        holdDuration: 30,
        completed: true,
        timestamp: DateTime(2026, 4, 1, 10, 0),
      ),
      PoseResult(
        poseName: 'Plank',
        bestScore: 75,
        holdDuration: 45,
        completed: true,
        timestamp: DateTime(2026, 4, 2, 10, 0),
      ),
      PoseResult(
        poseName: 'Tree',
        bestScore: 84,
        holdDuration: 32,
        completed: true,
        timestamp: DateTime(2026, 4, 3, 10, 0),
      ),
    ];

    final trends = service.buildExerciseTrends(results);
    expect(trends.first.poseName, equals('Tree'));
    expect(trends.first.deltaScore, equals(4));
  });

  test(
    'buildExerciseTrends computes last5 vs previous5 trend for 10 sessions',
    () {
      final results = List<PoseResult>.generate(10, (i) {
        final scores = <double>[60, 62, 64, 66, 68, 70, 72, 74, 76, 78];
        return PoseResult(
          poseName: 'Tree',
          bestScore: scores[i],
          holdDuration: 30 + i.toDouble(),
          completed: true,
          timestamp: DateTime(2026, 4, i + 1, 8, 0),
        );
      });

      final trends = service.buildExerciseTrends(results);
      final tree = trends.single;

      expect(tree.sessionCount, equals(10));
      expect(tree.trendWindowSize, equals(5));
      expect(tree.recentWindowAverage, closeTo(74, 0.001));
      expect(tree.previousWindowAverage, closeTo(64, 0.001));
      expect(tree.windowTrendDelta, closeTo(10, 0.001));
      expect(tree.hasEnoughTrendData, isTrue);
      expect(
        tree.recentScores,
        equals(<double>[60, 62, 64, 66, 68, 70, 72, 74, 76, 78]),
      );
    },
  );

  test(
    'buildExerciseTrends computes trend with partial previous window for 6-9 sessions',
    () {
      final results = List<PoseResult>.generate(7, (i) {
        final scores = <double>[60, 62, 64, 66, 68, 70, 72];
        return PoseResult(
          poseName: 'Tree',
          bestScore: scores[i],
          holdDuration: 40,
          completed: true,
          timestamp: DateTime(2026, 4, i + 1, 8, 0),
        );
      });

      final trends = service.buildExerciseTrends(results);
      final tree = trends.single;

      expect(tree.sessionCount, equals(7));
      expect(tree.hasEnoughTrendData, isTrue);
      expect(tree.recentWindowAverage, closeTo(68, 0.001));
      expect(tree.previousWindowAverage, closeTo(61, 0.001));
      expect(tree.windowTrendDelta, closeTo(7, 0.001));
    },
  );

  test('buildExerciseTrends marks sparse data under 6 sessions', () {
    final results = List<PoseResult>.generate(5, (i) {
      return PoseResult(
        poseName: 'Tree',
        bestScore: 70 + i.toDouble(),
        holdDuration: 35,
        completed: true,
        timestamp: DateTime(2026, 4, i + 1, 8, 0),
      );
    });

    final trends = service.buildExerciseTrends(results);
    final tree = trends.single;

    expect(tree.sessionCount, equals(5));
    expect(tree.hasEnoughTrendData, isFalse);
    expect(tree.previousWindowAverage, isNull);
    expect(tree.windowTrendDelta, isNull);
  });

  test(
    'buildExerciseTrends keeps recentScores chronological for plotted last 10',
    () {
      final results = List<PoseResult>.generate(12, (i) {
        return PoseResult(
          poseName: 'Tree',
          bestScore: 50 + i.toDouble(),
          holdDuration: 30,
          completed: true,
          timestamp: DateTime(2026, 4, i + 1, 8, 0),
        );
      });

      final trends = service.buildExerciseTrends(results);
      final tree = trends.single;

      expect(tree.recentScores.length, equals(10));
      expect(tree.recentScores.first, equals(52));
      expect(tree.recentScores.last, equals(61));
    },
  );

  test('buildMeasureTrend returns latest and delta', () {
    final history = <BodyMeasurement>[
      BodyMeasurement(
        userId: 'u1',
        metricType: BodyMetricType.bodyWeight,
        value: 70.8,
        unit: 'kg',
        measuredAt: DateTime(2026, 4, 5),
        updatedAt: DateTime(2026, 4, 5),
        isSynced: false,
      ),
      BodyMeasurement(
        userId: 'u1',
        metricType: BodyMetricType.bodyWeight,
        value: 71.3,
        unit: 'kg',
        measuredAt: DateTime(2026, 4, 3),
        updatedAt: DateTime(2026, 4, 3),
        isSynced: false,
      ),
    ];

    final trend = service.buildMeasureTrend(
      metricType: BodyMetricType.bodyWeight,
      history: history,
    );
    expect(trend.latestValue, equals(70.8));
    expect(trend.deltaValue, equals(-0.5));
  });
}
