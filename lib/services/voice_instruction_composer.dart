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
      return _motivate('Raise your left arm a little. Stack your shoulders.');
    }
    if (lowered.contains('raise your right arm')) {
      return _motivate('Raise your right arm a little. Stack your shoulders.');
    }
    if (lowered.contains('lower your left arm')) {
      return _motivate('Lower your left arm slightly. Level your shoulders.');
    }
    if (lowered.contains('lower your right arm')) {
      return _motivate('Lower your right arm slightly. Level your shoulders.');
    }
    if (lowered.contains('straighten your left leg')) {
      return _motivate('Straighten your left leg. Keep your base steady.');
    }
    if (lowered.contains('straighten your right leg')) {
      return _motivate('Straighten your right leg. Keep your base steady.');
    }
    if (lowered.contains('bend your left knee')) {
      return _motivate('Bend your left knee a bit more. Stay controlled.');
    }
    if (lowered.contains('bend your right knee')) {
      return _motivate('Bend your right knee a bit more. Stay controlled.');
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
      return _motivate('Adjust your torso. Engage your core.');
    }
    if (lowered.contains('match the outline')) {
      return _motivate('Match the outline with small adjustments.');
    }
    if (lowered.contains('hold still')) {
      return _safetyUnstableInstruction();
    }
    if (lowered.contains('step into frame')) {
      return _safetyNoUserInstruction();
    }

    return _motivate('$cue. Keep your form steady.');
  }

  String _safetyUnstableInstruction() =>
      _motivate('Hold still and breathe for a moment.');

  String _safetyNoUserInstruction() =>
      _motivate('Step into frame so I can track your pose.');

  String _motivate(String instruction) {
    if (tone != VoiceCoachTone.motivational) {
      return instruction;
    }
    return instruction;
  }
}
