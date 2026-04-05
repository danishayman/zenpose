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
