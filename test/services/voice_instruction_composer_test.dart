import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/models/workout_guidance_snapshot.dart';
import 'package:zenpose/services/voice_instruction_composer.dart';

void main() {
  group('VoiceInstructionComposer', () {
    const composer = VoiceInstructionComposer();

    test('expands known base cue with reason and motivational tone', () {
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

      expect(
        spoken,
        'Raise your right arm a little and stack your shoulders for better alignment. You are doing great, keep going.',
      );
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

      expect(
        spoken,
        'Step into frame so I can track your pose accurately. You are doing great, keep going.',
      );
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

      expect(
        spoken,
        'Custom cue to improve alignment and keep your form steady. You are doing great, keep going.',
      );
    });

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
