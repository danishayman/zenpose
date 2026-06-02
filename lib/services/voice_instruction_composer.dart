import '../models/workout_guidance_snapshot.dart';

enum VoiceCoachTone { motivational }

/// Expands short visual cues into richer voice-only coaching instructions.
class VoiceInstructionComposer {
  final VoiceCoachTone tone;

  const VoiceInstructionComposer({
    this.tone = VoiceCoachTone.motivational,
  });

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
        return _motivate(
          'Great hold. Stay steady and keep breathing to build control.',
        );
      }
      return null;
    }

    final lowered = cue.toLowerCase();

    if (lowered.contains('raise your left arm')) {
      return _motivate(
        'Raise your left arm a little and stack your shoulders for better alignment.',
      );
    }
    if (lowered.contains('raise your right arm')) {
      return _motivate(
        'Raise your right arm a little and stack your shoulders for better alignment.',
      );
    }
    if (lowered.contains('lower your left arm')) {
      return _motivate(
        'Lower your left arm slightly to level your shoulders and stay balanced.',
      );
    }
    if (lowered.contains('lower your right arm')) {
      return _motivate(
        'Lower your right arm slightly to level your shoulders and stay balanced.',
      );
    }
    if (lowered.contains('straighten your left leg')) {
      return _motivate(
        'Straighten your left leg to create a stable base and improve control.',
      );
    }
    if (lowered.contains('straighten your right leg')) {
      return _motivate(
        'Straighten your right leg to create a stable base and improve control.',
      );
    }
    if (lowered.contains('bend your left knee')) {
      return _motivate(
        'Bend your left knee a bit more so your lower body lines up with the pose target.',
      );
    }
    if (lowered.contains('bend your right knee')) {
      return _motivate(
        'Bend your right knee a bit more so your lower body lines up with the pose target.',
      );
    }
    if (lowered.contains('open your left hip')) {
      return _motivate(
        'Open your left hip more to improve hip alignment and overall balance.',
      );
    }
    if (lowered.contains('open your right hip')) {
      return _motivate(
        'Open your right hip more to improve hip alignment and overall balance.',
      );
    }
    if (lowered.contains('close your left hip')) {
      return _motivate(
        'Close your left hip slightly to center your pelvis and steady your pose.',
      );
    }
    if (lowered.contains('close your right hip')) {
      return _motivate(
        'Close your right hip slightly to center your pelvis and steady your pose.',
      );
    }
    if (lowered.contains('adjust torso alignment') ||
        lowered.contains('torso')) {
      return _motivate(
        'Adjust your torso and engage your core to keep your balance centered.',
      );
    }
    if (lowered.contains('match the outline')) {
      return _motivate(
        'Match the outline with small, controlled adjustments until your joints line up.',
      );
    }
    if (lowered.contains('hold still')) {
      return _safetyUnstableInstruction();
    }
    if (lowered.contains('step into frame')) {
      return _safetyNoUserInstruction();
    }

    return _motivate('$cue to improve alignment and keep your form steady.');
  }

  String _safetyUnstableInstruction() => _motivate(
        'Hold still and breathe for a moment so tracking can stabilize.',
      );

  String _safetyNoUserInstruction() =>
      _motivate('Step into frame so I can track your pose accurately.');

  String _motivate(String instruction) {
    if (tone != VoiceCoachTone.motivational) {
      return instruction;
    }
    return '$instruction You are doing great, keep going.';
  }
}
