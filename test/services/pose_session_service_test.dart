import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/models/pose_session_config.dart';
import 'package:zenpose/services/pose_session_service.dart';

void main() {
  test('timed mode computes average score and excludes paused duration', () {
    final service = PoseSessionService(
      poseName: 'Test Pose',
      sessionConfig: const PoseSessionConfig(
        mode: PoseSessionMode.timed,
        holdDuration: Duration(seconds: 45),
        timedDuration: Duration(seconds: 5),
        scoreThreshold: 70,
        persistResult: false,
      ),
    );

    final t0 = DateTime(2026, 3, 27, 10, 0, 0);
    service.startTimedSession(startedAt: t0);

    expect(
      service.update(50, timestamp: t0.add(const Duration(seconds: 1))),
      isNull,
    );
    expect(
      service.update(70, timestamp: t0.add(const Duration(seconds: 3))),
      isNull,
    );

    service.pauseTimedSession(pausedAt: t0.add(const Duration(seconds: 3)));
    expect(
      service.update(95, timestamp: t0.add(const Duration(seconds: 6))),
      isNull,
    );
    service.resumeTimedSession(resumedAt: t0.add(const Duration(seconds: 8)));

    final result = service.update(
      80,
      timestamp: t0.add(const Duration(seconds: 10)),
    );

    expect(result, isNotNull);
    // Active timeline = 0-3s and 8-10s => 5 seconds total.
    expect(result!.holdDuration, closeTo(5.0, 0.01));
    // Sampled scores while active: 50, 70, 80.
    expect(result.bestScore, closeTo((50 + 70 + 80) / 3, 0.01));
  });
}
