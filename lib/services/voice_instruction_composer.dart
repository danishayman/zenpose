import '../models/workout_guidance_snapshot.dart';

enum VoiceCoachTone { motivational }

/// Expands short visual cues into concise voice-only coaching instructions.
class VoiceInstructionComposer {
  final VoiceCoachTone tone;

  const VoiceInstructionComposer({this.tone = VoiceCoachTone.motivational});

  String? compose({
    required WorkoutGuidanceSnapshot snapshot,
    String? baseCue,
  }) {
    switch (snapshot.state) {
      case WorkoutGuidanceState.initializing:
      case WorkoutGuidanceState.completed:
        return null;
      case WorkoutGuidanceState.noUserDetected:
        return _safetyNoUserInstruction();
      case WorkoutGuidanceState.unstablePose:
        return _safetyUnstableInstruction();
      case WorkoutGuidanceState.aligning:
      case WorkoutGuidanceState.holding:
        return _composeFormInstruction(snapshot, baseCue);
    }
  }

  String? _composeFormInstruction(
    WorkoutGuidanceSnapshot snapshot,
    String? baseCue,
  ) {
    final cue = baseCue?.trim() ?? '';
    if (cue.isEmpty) {
      if (snapshot.state == WorkoutGuidanceState.holding) {
        return _motivate('Great hold. Keep breathing.');
      }
      return null;
    }

    final lowered = cue.toLowerCase();

    if (lowered.contains('bend your left elbow')) {
      return _motivate(
        _variant(snapshot, cue, const <String>[
          'Bend your left elbow more. Keep your shoulder steady.',
          'Soften your left elbow a little more. Keep your arm controlled.',
        ]),
      );
    }
    if (lowered.contains('bend your right elbow')) {
      return _motivate(
        _variant(snapshot, cue, const <String>[
          'Bend your right elbow more. Keep your shoulder steady.',
          'Soften your right elbow a little more. Keep your arm controlled.',
        ]),
      );
    }
    if (lowered.contains('straighten your left arm')) {
      return _motivate(
        _variant(snapshot, cue, const <String>[
          'Straighten your left arm more. Keep your wrist in line.',
          'Extend your left arm a little more. Keep your shoulder relaxed.',
        ]),
      );
    }
    if (lowered.contains('straighten your right arm')) {
      return _motivate(
        _variant(snapshot, cue, const <String>[
          'Straighten your right arm more. Keep your wrist in line.',
          'Extend your right arm a little more. Keep your shoulder relaxed.',
        ]),
      );
    }
    if (lowered.contains('raise your left arm')) {
      return _motivate(
        _variant(snapshot, cue, const <String>[
          'Raise your left arm higher. Keep your shoulders relaxed.',
          'Lift your left arm a little higher. Keep your chest open.',
        ]),
      );
    }
    if (lowered.contains('raise your right arm')) {
      return _motivate(
        _variant(snapshot, cue, const <String>[
          'Raise your right arm higher. Keep your shoulders relaxed.',
          'Lift your right arm a little higher. Keep your chest open.',
        ]),
      );
    }
    if (lowered.contains('lower your left arm')) {
      return _motivate(
        _variant(snapshot, cue, const <String>[
          'Lower your left arm slightly. Keep your shoulders level.',
          'Bring your left arm down a little. Keep your neck relaxed.',
        ]),
      );
    }
    if (lowered.contains('lower your right arm')) {
      return _motivate(
        _variant(snapshot, cue, const <String>[
          'Lower your right arm slightly. Keep your shoulders level.',
          'Bring your right arm down a little. Keep your neck relaxed.',
        ]),
      );
    }
    if (lowered.contains('straighten your left leg')) {
      return _motivate(
        _variant(snapshot, cue, const <String>[
          'Straighten your left leg more. Keep your base steady.',
          'Lengthen your left leg a little more. Press evenly through your foot.',
        ]),
      );
    }
    if (lowered.contains('straighten your right leg')) {
      return _motivate(
        _variant(snapshot, cue, const <String>[
          'Straighten your right leg more. Keep your base steady.',
          'Lengthen your right leg a little more. Press evenly through your foot.',
        ]),
      );
    }
    if (lowered.contains('bend your left knee')) {
      return _motivate(
        _variant(snapshot, cue, const <String>[
          'Bend your left knee more. Stay balanced.',
          'Sink a little deeper into your left knee. Keep it tracking forward.',
        ]),
      );
    }
    if (lowered.contains('bend your right knee')) {
      return _motivate(
        _variant(snapshot, cue, const <String>[
          'Bend your right knee more. Stay balanced.',
          'Sink a little deeper into your right knee. Keep it tracking forward.',
        ]),
      );
    }
    if (lowered.contains('open your left hip')) {
      return _motivate(
        _variant(snapshot, cue, const <String>[
          'Open your left hip more. Keep your balance.',
          'Rotate your left hip open a little more. Keep your pelvis steady.',
        ]),
      );
    }
    if (lowered.contains('open your right hip')) {
      return _motivate(
        _variant(snapshot, cue, const <String>[
          'Open your right hip more. Keep your balance.',
          'Rotate your right hip open a little more. Keep your pelvis steady.',
        ]),
      );
    }
    if (lowered.contains('close your left hip')) {
      return _motivate(
        _variant(snapshot, cue, const <String>[
          'Close your left hip slightly. Center your pelvis.',
          'Draw your left hip in slightly. Keep your pelvis centered.',
        ]),
      );
    }
    if (lowered.contains('close your right hip')) {
      return _motivate(
        _variant(snapshot, cue, const <String>[
          'Close your right hip slightly. Center your pelvis.',
          'Draw your right hip in slightly. Keep your pelvis centered.',
        ]),
      );
    }
    if (lowered.contains('adjust torso alignment') ||
        lowered.contains('torso')) {
      return _motivate(
        _variant(snapshot, cue, const <String>[
          'Adjust your torso alignment. Gently engage your core.',
          'Stack your torso more evenly. Keep your core lightly active.',
        ]),
      );
    }
    if (lowered.contains('match the outline')) {
      return _motivate('Ease toward the outline. Use small adjustments.');
    }
    if (lowered.contains('hold still')) {
      return _safetyUnstableInstruction();
    }
    if (lowered.contains('step into frame')) {
      return _safetyNoUserInstruction();
    }

    return _motivate('$cue. Keep your breath steady.');
  }

  String _safetyUnstableInstruction() =>
      _motivate('Hold still for a moment. Take a slow breath.');

  String _safetyNoUserInstruction() =>
      _motivate('I cannot see you. Step into frame.');

  String _variant(
    WorkoutGuidanceSnapshot snapshot,
    String cue,
    List<String> options,
  ) {
    if (options.length == 1) return options.first;
    final seed =
        _stableCueSeed(cue) +
        snapshot.state.index +
        snapshot.score.round() +
        (snapshot.holdProgress * 100).round();
    return options[seed % options.length];
  }

  int _stableCueSeed(String cue) {
    var seed = 0;
    for (final codeUnit in cue.toLowerCase().codeUnits) {
      seed = (seed + codeUnit) % 9973;
    }
    return seed;
  }

  String _motivate(String instruction) {
    if (tone != VoiceCoachTone.motivational) {
      return instruction;
    }
    return instruction;
  }
}
