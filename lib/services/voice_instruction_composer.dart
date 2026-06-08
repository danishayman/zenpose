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
        return null;
      case WorkoutGuidanceState.aligning:
        return _composeFormInstruction(snapshot, baseCue);
      case WorkoutGuidanceState.holding:
        return _positiveHoldingInstruction();
    }
  }

  String? _composeFormInstruction(
    WorkoutGuidanceSnapshot snapshot,
    String? baseCue,
  ) {
    final cue = baseCue?.trim() ?? '';
    if (cue.isEmpty) {
      return null;
    }

    final lowered = cue.toLowerCase();

    if (lowered.contains('bend your left elbow')) {
      return _motivate('Bend your left elbow more.');
    }
    if (lowered.contains('bend your right elbow')) {
      return _motivate('Bend your right elbow more.');
    }
    if (lowered.contains('straighten your left arm')) {
      return _motivate('Straighten your left arm.');
    }
    if (lowered.contains('straighten your right arm')) {
      return _motivate('Straighten your right arm.');
    }
    if (lowered.contains('raise your left arm')) {
      return _motivate('Raise your left arm.');
    }
    if (lowered.contains('raise your right arm')) {
      return _motivate('Raise your right arm.');
    }
    if (lowered.contains('lower your left arm')) {
      return _motivate('Lower your left arm.');
    }
    if (lowered.contains('lower your right arm')) {
      return _motivate('Lower your right arm.');
    }
    if (lowered.contains('straighten your left leg')) {
      return _motivate('Straighten your left leg.');
    }
    if (lowered.contains('straighten your right leg')) {
      return _motivate('Straighten your right leg.');
    }
    if (lowered.contains('bend your left knee')) {
      return _motivate('Bend your left knee more.');
    }
    if (lowered.contains('bend your right knee')) {
      return _motivate('Bend your right knee more.');
    }
    if (lowered.contains('open your left hip')) {
      return _motivate('Open your left hip.');
    }
    if (lowered.contains('open your right hip')) {
      return _motivate('Open your right hip.');
    }
    if (lowered.contains('close your left hip')) {
      return _motivate('Close your left hip.');
    }
    if (lowered.contains('close your right hip')) {
      return _motivate('Close your right hip.');
    }
    if (lowered.contains('adjust torso alignment') ||
        lowered.contains('torso')) {
      return _motivate('Adjust your torso.');
    }
    if (lowered.contains('match the outline') ||
        lowered.contains('hold still')) {
      return null;
    }
    if (lowered.contains('step into frame')) {
      return _safetyNoUserInstruction();
    }

    return _motivate(_ensureSentence(cue));
  }

  String _positiveHoldingInstruction() => _motivate("You're doing great.");

  String _safetyNoUserInstruction() =>
      _motivate('I cannot see you. Step into frame.');

  String _ensureSentence(String cue) {
    if (cue.endsWith('.') || cue.endsWith('!') || cue.endsWith('?')) {
      return cue;
    }
    return '$cue.';
  }

  String _motivate(String instruction) {
    if (tone != VoiceCoachTone.motivational) {
      return instruction;
    }
    return instruction;
  }
}
