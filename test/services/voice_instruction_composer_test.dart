import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/models/workout_guidance_snapshot.dart';
import 'package:zenpose/services/voice_instruction_composer.dart';

void main() {
  group('VoiceInstructionComposer', () {
    const composer = VoiceInstructionComposer();

    test('expands known base cue into concise voice guidance', () {
      const snapshot = WorkoutGuidanceSnapshot(
        score: 62,
        holdProgress: 0.2,
        state: WorkoutGuidanceState.aligning,
        primaryCue: 'Raise your right arm',
        secondaryCue: null,
        shouldResetSession: false,
      );

      final spoken = composer.compose(
        snapshot: snapshot,
        baseCue: snapshot.primaryCue,
      );

      expect(spoken, 'Raise your right arm.');
    });

    test('uses safety guidance when user is not detected', () {
      const snapshot = WorkoutGuidanceSnapshot(
        score: 0,
        holdProgress: 0,
        state: WorkoutGuidanceState.noUserDetected,
        primaryCue: 'Step into frame',
        secondaryCue: null,
        shouldResetSession: false,
      );

      final spoken = composer.compose(
        snapshot: snapshot,
        baseCue: snapshot.primaryCue,
      );

      expect(spoken, 'I cannot see you. Step into frame.');
    });

    test('does not speak unstable hold-still guidance', () {
      const snapshot = WorkoutGuidanceSnapshot(
        score: 58,
        holdProgress: 0.1,
        state: WorkoutGuidanceState.unstablePose,
        primaryCue: 'Hold still',
        secondaryCue: null,
        shouldResetSession: false,
      );

      final spoken = composer.compose(
        snapshot: snapshot,
        baseCue: snapshot.primaryCue,
      );

      expect(spoken, isNull);
    });

    test('uses positive guidance while holding green state', () {
      const snapshot = WorkoutGuidanceSnapshot(
        score: 90,
        holdProgress: 0.5,
        state: WorkoutGuidanceState.holding,
        primaryCue: null,
        secondaryCue: null,
        shouldResetSession: false,
      );

      final spoken = composer.compose(snapshot: snapshot, baseCue: null);

      expect(spoken, "You're doing great.");
    });

    test('expands elbow feedback into specific voice guidance', () {
      const snapshot = WorkoutGuidanceSnapshot(
        score: 62,
        holdProgress: 0.2,
        state: WorkoutGuidanceState.aligning,
        primaryCue: 'Bend your left elbow more',
        secondaryCue: null,
        shouldResetSession: false,
      );

      final spoken = composer.compose(
        snapshot: snapshot,
        baseCue: snapshot.primaryCue,
      );

      expect(spoken, 'Bend your left elbow more.');
    });

    test('expands knee feedback into specific voice guidance', () {
      const snapshot = WorkoutGuidanceSnapshot(
        score: 62,
        holdProgress: 0.2,
        state: WorkoutGuidanceState.aligning,
        primaryCue: 'Bend your right knee more',
        secondaryCue: null,
        shouldResetSession: false,
      );

      final spoken = composer.compose(
        snapshot: snapshot,
        baseCue: snapshot.primaryCue,
      );

      expect(spoken, 'Bend your right knee more.');
    });

    test('expands hip and torso feedback into specific voice guidance', () {
      const hipSnapshot = WorkoutGuidanceSnapshot(
        score: 62,
        holdProgress: 0.2,
        state: WorkoutGuidanceState.aligning,
        primaryCue: 'Open your left hip more',
        secondaryCue: null,
        shouldResetSession: false,
      );
      const torsoSnapshot = WorkoutGuidanceSnapshot(
        score: 62,
        holdProgress: 0.2,
        state: WorkoutGuidanceState.aligning,
        primaryCue: 'Adjust torso alignment',
        secondaryCue: null,
        shouldResetSession: false,
      );

      final hip = composer.compose(
        snapshot: hipSnapshot,
        baseCue: hipSnapshot.primaryCue,
      );
      final torso = composer.compose(
        snapshot: torsoSnapshot,
        baseCue: torsoSnapshot.primaryCue,
      );

      expect(hip, 'Open your left hip.');
      expect(torso, 'Adjust your torso.');
    });

    test('uses deterministic variants for repeated known cues', () {
      const snapshot = WorkoutGuidanceSnapshot(
        score: 62,
        holdProgress: 0.2,
        state: WorkoutGuidanceState.aligning,
        primaryCue: 'Straighten your right arm',
        secondaryCue: null,
        shouldResetSession: false,
      );

      final first = composer.compose(
        snapshot: snapshot,
        baseCue: snapshot.primaryCue,
      );
      final second = composer.compose(
        snapshot: snapshot,
        baseCue: snapshot.primaryCue,
      );

      expect(first, second);
      expect(first, 'Straighten your right arm.');
    });

    test('falls back for unknown cue text', () {
      const snapshot = WorkoutGuidanceSnapshot(
        score: 55,
        holdProgress: 0.1,
        state: WorkoutGuidanceState.aligning,
        primaryCue: 'Custom cue',
        secondaryCue: null,
        shouldResetSession: false,
      );

      final spoken = composer.compose(
        snapshot: snapshot,
        baseCue: snapshot.primaryCue,
      );

      expect(spoken, 'Custom cue.');
    });

    test(
      'does not voice outline or hold-still fallback cues while aligning',
      () {
        const snapshot = WorkoutGuidanceSnapshot(
          score: 55,
          holdProgress: 0.1,
          state: WorkoutGuidanceState.aligning,
          primaryCue: 'Match the outline',
          secondaryCue: null,
          shouldResetSession: false,
        );
        final outline = composer.compose(
          snapshot: snapshot,
          baseCue: 'Match the outline',
        );
        final holdStill = composer.compose(
          snapshot: snapshot,
          baseCue: 'Hold still',
        );

        expect(outline, isNull);
        expect(holdStill, isNull);
      },
    );

    test('returns null when no form cue exists in aligning state', () {
      const snapshot = WorkoutGuidanceSnapshot(
        score: 70,
        holdProgress: 0.3,
        state: WorkoutGuidanceState.aligning,
        primaryCue: null,
        secondaryCue: null,
        shouldResetSession: false,
      );

      final spoken = composer.compose(snapshot: snapshot, baseCue: null);

      expect(spoken, isNull);
    });
  });
}
