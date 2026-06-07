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

    test('debounces unstablePose entry', () {
      final service = WorkoutGuidanceService();
      final t0 = DateTime(2026, 3, 14, 9, 0, 0);

      service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: true,
        poseCompleted: false,
        score: 76,
        holdProgress: 0.15,
        scoreThreshold: 70,
        feedbackMessages: const <String>['Straighten your left leg'],
        now: t0,
      );
      final earlyUnstable = service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: false,
        poseCompleted: false,
        score: 76,
        holdProgress: 0.15,
        scoreThreshold: 70,
        feedbackMessages: const <String>['Straighten your left leg'],
        now: t0.add(const Duration(milliseconds: 120)),
      );
      final confirmedUnstable = service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: false,
        poseCompleted: false,
        score: 76,
        holdProgress: 0.15,
        scoreThreshold: 70,
        feedbackMessages: const <String>['Straighten your left leg'],
        now: t0.add(const Duration(milliseconds: 420)),
      );

      expect(earlyUnstable.state, isNot(WorkoutGuidanceState.unstablePose));
      expect(confirmedUnstable.state, WorkoutGuidanceState.unstablePose);
    });

    test('enters holding only after sustained threshold + hysteresis', () {
      final service = WorkoutGuidanceService();
      final t0 = DateTime(2026, 3, 14, 9, 0, 0);
      final aligning = service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: true,
        poseCompleted: false,
        score: 74,
        holdProgress: 0.2,
        scoreThreshold: 70,
        feedbackMessages: const <String>['Raise your right arm'],
        now: t0,
      );
      final stillAligning = service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: true,
        poseCompleted: false,
        score: 74,
        holdProgress: 0.35,
        scoreThreshold: 70,
        feedbackMessages: const <String>['Raise your right arm'],
        now: t0.add(const Duration(milliseconds: 200)),
      );
      final holding = service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: true,
        poseCompleted: false,
        score: 74,
        holdProgress: 0.35,
        scoreThreshold: 70,
        feedbackMessages: const <String>['Raise your right arm'],
        now: t0.add(const Duration(milliseconds: 500)),
      );

      expect(aligning.state, WorkoutGuidanceState.aligning);
      expect(stillAligning.state, WorkoutGuidanceState.aligning);
      expect(holding.state, WorkoutGuidanceState.holding);
    });

    test('exits holding when score drops below exit threshold', () {
      final service = WorkoutGuidanceService();
      final t0 = DateTime(2026, 3, 14, 9, 0, 0);

      service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: true,
        poseCompleted: false,
        score: 74,
        holdProgress: 0.2,
        scoreThreshold: 70,
        feedbackMessages: const <String>['Raise your right arm'],
        now: t0,
      );
      service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: true,
        poseCompleted: false,
        score: 74,
        holdProgress: 0.3,
        scoreThreshold: 70,
        feedbackMessages: const <String>['Raise your right arm'],
        now: t0.add(const Duration(milliseconds: 500)),
      );

      final exited = service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: true,
        poseCompleted: false,
        score: 64,
        holdProgress: 0.3,
        scoreThreshold: 70,
        feedbackMessages: const <String>['Raise your right arm'],
        now: t0.add(const Duration(milliseconds: 900)),
      );

      expect(exited.state, WorkoutGuidanceState.aligning);
    });

    test('prioritizes torso cues and emits a single visual cue', () {
      final service = WorkoutGuidanceService();
      final snapshot = service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: true,
        poseCompleted: false,
        score: 60,
        holdProgress: 0.1,
        scoreThreshold: 70,
        feedbackMessages: const <String>[
          'Raise your right arm',
          'Adjust torso alignment',
          'Straighten your left leg',
        ],
        now: DateTime(2026, 3, 14, 9, 0, 0),
      );

      expect(snapshot.primaryCue, 'Adjust torso alignment');
      expect(snapshot.secondaryCue, isNull);
    });

    test('rotates across body-part cues after display duration', () {
      final service = WorkoutGuidanceService(
        cueMinDisplayDuration: const Duration(seconds: 1),
      );
      final t0 = DateTime(2026, 3, 14, 9, 0, 0);
      const feedback = <String>[
        'Bend your left elbow more',
        'Bend your right knee more',
        'Adjust torso alignment',
      ];

      final first = service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: true,
        poseCompleted: false,
        score: 58,
        holdProgress: 0.1,
        scoreThreshold: 70,
        feedbackMessages: feedback,
        now: t0,
      );
      final held = service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: true,
        poseCompleted: false,
        score: 58,
        holdProgress: 0.1,
        scoreThreshold: 70,
        feedbackMessages: feedback,
        now: t0.add(const Duration(milliseconds: 500)),
      );
      final rotated = service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: true,
        poseCompleted: false,
        score: 58,
        holdProgress: 0.1,
        scoreThreshold: 70,
        feedbackMessages: feedback,
        now: t0.add(const Duration(milliseconds: 1200)),
      );

      expect(first.primaryCue, 'Bend your left elbow more');
      expect(held.primaryCue, 'Bend your left elbow more');
      expect(rotated.primaryCue, 'Bend your right knee more');
    });

    test('prefers joint-level feedback over broad segment cues', () {
      final service = WorkoutGuidanceService();
      final snapshot = service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: true,
        poseCompleted: false,
        score: 60,
        holdProgress: 0.1,
        scoreThreshold: 70,
        feedbackMessages: const <String>[
          'Raise your right arm',
          'Straighten your left leg',
          'Bend your right knee more',
        ],
        now: DateTime(2026, 3, 14, 9, 0, 0),
      );

      expect(snapshot.primaryCue, 'Bend your right knee more');
    });

    test('suppresses contradictory cue flips for the same limb', () {
      final service = WorkoutGuidanceService();
      final t0 = DateTime(2026, 3, 14, 9, 0, 0);

      final first = service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: true,
        poseCompleted: false,
        score: 60,
        holdProgress: 0.1,
        scoreThreshold: 70,
        feedbackMessages: const <String>['Raise your right arm'],
        now: t0,
      );
      final second = service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: true,
        poseCompleted: false,
        score: 60,
        holdProgress: 0.1,
        scoreThreshold: 70,
        feedbackMessages: const <String>['Lower your right arm'],
        now: t0.add(const Duration(milliseconds: 900)),
      );

      expect(first.primaryCue, 'Raise your right arm');
      expect(second.primaryCue, isNot('Lower your right arm'));
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

      final stillMissing = service.evaluate(
        cameraReady: true,
        hasPose: false,
        poseStable: false,
        poseCompleted: false,
        score: 0,
        holdProgress: 0,
        scoreThreshold: 70,
        feedbackMessages: const <String>[],
        now: t0.add(const Duration(seconds: 4)),
      );
      expect(stillMissing.shouldResetSession, isFalse);

      service.evaluate(
        cameraReady: true,
        hasPose: true,
        poseStable: true,
        poseCompleted: false,
        score: 80,
        holdProgress: 0.2,
        scoreThreshold: 70,
        feedbackMessages: const <String>[],
        now: t0.add(const Duration(seconds: 5)),
      );
      final expiredAgain = service.evaluate(
        cameraReady: true,
        hasPose: false,
        poseStable: false,
        poseCompleted: false,
        score: 0,
        holdProgress: 0,
        scoreThreshold: 70,
        feedbackMessages: const <String>[],
        now: t0.add(const Duration(seconds: 8)),
      );
      expect(expiredAgain.shouldResetSession, isTrue);
    });
  });
}
