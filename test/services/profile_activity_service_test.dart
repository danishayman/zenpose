import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/models/pose_result.dart';
import 'package:zenpose/models/profile_activity_models.dart';
import 'package:zenpose/services/profile_activity_service.dart';

void main() {
  group('ProfileActivityService.buildSeries', () {
    test('aggregates duration, score, and sessions across sparse days', () {
      final now = DateTime(2026, 4, 10, 12);
      final results = <PoseResult>[
        PoseResult(
          poseName: 'Tree',
          bestScore: 80,
          holdDuration: 30,
          completed: true,
          timestamp: DateTime(2026, 4, 9, 9),
        ),
        PoseResult(
          poseName: 'Plank',
          bestScore: 90,
          holdDuration: 90,
          completed: true,
          timestamp: DateTime(2026, 4, 9, 20),
        ),
        PoseResult(
          poseName: 'Warrior',
          bestScore: 70,
          holdDuration: 60,
          completed: true,
          timestamp: DateTime(2026, 4, 7, 8),
        ),
        PoseResult(
          poseName: 'Incomplete',
          bestScore: 100,
          holdDuration: 120,
          completed: false,
          timestamp: DateTime(2026, 4, 9, 11),
        ),
      ];

      const service = ProfileActivityService();
      final durationSeries = service.buildSeries(
        results: results,
        metric: ProfileActivityMetric.duration,
        now: now,
        days: 4,
      );
      final scoreSeries = service.buildSeries(
        results: results,
        metric: ProfileActivityMetric.score,
        now: now,
        days: 4,
      );
      final sessionsSeries = service.buildSeries(
        results: results,
        metric: ProfileActivityMetric.sessions,
        now: now,
        days: 4,
      );

      expect(durationSeries.points.length, 4);
      expect(scoreSeries.points.length, 4);
      expect(sessionsSeries.points.length, 4);

      // Date span: Apr 7 -> Apr 10
      expect(durationSeries.points[0].value, closeTo(1.0, 0.0001));
      expect(durationSeries.points[2].value, closeTo(2.0, 0.0001));
      expect(durationSeries.points[3].value, closeTo(0.0, 0.0001));

      expect(scoreSeries.points[0].value, closeTo(70, 0.0001));
      expect(scoreSeries.points[2].value, closeTo(85, 0.0001));
      expect(scoreSeries.points[1].value, closeTo(0, 0.0001));

      expect(sessionsSeries.points[0].value, 1);
      expect(sessionsSeries.points[2].value, 2);
      expect(sessionsSeries.points[1].value, 0);
      expect(sessionsSeries.points[3].value, 0);
    });
  });
}
