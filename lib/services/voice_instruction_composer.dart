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

    if (lowered.contains('raise your left arm')) {
      return _motivate(
        'Raise your left arm higher. Keep your shoulders relaxed.',
      );
    }
    if (lowered.contains('raise your right arm')) {
      return _motivate(
        'Raise your right arm higher. Keep your shoulders relaxed.',
      );
    }
    if (lowered.contains('lower your left arm')) {
      return _motivate(
        'Lower your left arm slightly. Keep your shoulders level.',
      );
    }
    if (lowered.contains('lower your right arm')) {
      return _motivate(
        'Lower your right arm slightly. Keep your shoulders level.',
      );
    }
    if (lowered.contains('straighten your left leg')) {
      return _motivate('Straighten your left leg more. Keep your base steady.');
    }
    if (lowered.contains('straighten your right leg')) {
      return _motivate(
        'Straighten your right leg more. Keep your base steady.',
      );
    }
    if (lowered.contains('bend your left knee')) {
      return _motivate('Bend your left knee more. Stay balanced.');
    }
    if (lowered.contains('bend your right knee')) {
      return _motivate('Bend your right knee more. Stay balanced.');
    }
    if (lowered.contains('open your left hip')) {
      return _motivate('Open your left hip more. Keep your balance.');
    }
    if (lowered.contains('open your right hip')) {
      return _motivate('Open your right hip more. Keep your balance.');
    }
    if (lowered.contains('close your left hip')) {
      return _motivate('Close your left hip slightly. Center your pelvis.');
    }
    if (lowered.contains('close your right hip')) {
      return _motivate('Close your right hip slightly. Center your pelvis.');
    }
    if (lowered.contains('adjust torso alignment') ||
        lowered.contains('torso')) {
      return _motivate('Adjust your torso alignment. Gently engage your core.');
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

  String _motivate(String instruction) {
    if (tone != VoiceCoachTone.motivational) {
      return instruction;
    }
    return instruction;
  }
}
