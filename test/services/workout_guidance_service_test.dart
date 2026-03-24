import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/models/workout_guidance_snapshot.dart';
import 'package:zenpose/services/workout_guidance_service.dart';

void main() {
  group('WorkoutGuidanceService', () {
    test('returns noUserDetected when landmarks are missing', () {
      final service = WorkoutGuidanceService(
        lostTrackingGrace: const Duration(seconds: 2),
      );
      final t0 = DateTime(2026, 3, 14, 9, 0, 0);

      service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: true,
        poseCompleted: false,
        score: 82,
        holdProgress: 0.4,
        scoreThreshold: 70,
        feedbackMessages: const <String>[],
        now: t0,
      );
      final missing = service.evaluate(
        cameraReady: true,
        hasPose: false,
        poseStable: false,
        poseCompleted: false,
        score: 0,
        holdProgress: 0,
        scoreThreshold: 70,
        feedbackMessages: const <String>[],
        now: t0.add(const Duration(milliseconds: 500)),
      );

      expect(missing.state, WorkoutGuidanceState.noUserDetected);
      expect(missing.shouldResetSession, isFalse);
      expect(missing.score, closeTo(82, 0.0001));
    });

    test('returns unstablePose when pose is detected but unstable', () {
      final service = WorkoutGuidanceService();
      final snapshot = service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: false,
        poseCompleted: false,
        score: 76,
        holdProgress: 0.15,
        scoreThreshold: 70,
        feedbackMessages: const <String>['Straighten your left leg'],
      );

      expect(snapshot.state, WorkoutGuidanceState.unstablePose);
      expect(snapshot.primaryCue, 'Hold still');
    });

    test('enters holding only when stable and score threshold is met', () {
      final service = WorkoutGuidanceService();
      final aligning = service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: true,
        poseCompleted: false,
        score: 65,
        holdProgress: 0.2,
        scoreThreshold: 70,
        feedbackMessages: const <String>['Raise your right arm'],
      );
      final holding = service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: true,
        poseCompleted: false,
        score: 84,
        holdProgress: 0.35,
        scoreThreshold: 70,
        feedbackMessages: const <String>['Raise your right arm'],
      );

      expect(aligning.state, WorkoutGuidanceState.aligning);
      expect(holding.state, WorkoutGuidanceState.holding);
    });

    test('resets after tracking-loss grace timeout expires', () {
      final service = WorkoutGuidanceService(
        lostTrackingGrace: const Duration(seconds: 2),
      );
      final t0 = DateTime(2026, 3, 14, 9, 0, 0);

      service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: true,
        poseCompleted: false,
        score: 90,
        holdProgress: 0.6,
        scoreThreshold: 70,
        feedbackMessages: const <String>[],
        now: t0,
      );

      final expired = service.evaluate(
        cameraReady: true,
        hasPose: false,
        poseStable: false,
        poseCompleted: false,
        score: 0,
        holdProgress: 0,
        scoreThreshold: 70,
        feedbackMessages: const <String>[],
        now: t0.add(const Duration(seconds: 3)),
      );

      expect(expired.state, WorkoutGuidanceState.noUserDetected);
      expect(expired.shouldResetSession, isTrue);
      expect(expired.score, 0);
      expect(expired.holdProgress, 0);
    });
  });
}
