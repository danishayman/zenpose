import 'package:flutter_tts/flutter_tts.dart';

import '../models/workout_guidance_snapshot.dart';

abstract class VoiceSpeaker {
  Future<void> speak(String message);
  Future<void> stop();
}

class FlutterTtsVoiceSpeaker implements VoiceSpeaker {
  final FlutterTts _tts;

  FlutterTtsVoiceSpeaker({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _tts.setSpeechRate(0.48);
    _tts.setPitch(1.0);
    _tts.setVolume(1.0);
    _tts.awaitSpeakCompletion(false);
  }

  @override
  Future<void> speak(String message) => _tts.speak(message);

  @override
  Future<void> stop() => _tts.stop();
}

/// Voice prompt throttler for corrective cues.
class VoiceCueService {
  final VoiceSpeaker _speaker;
  final Duration cooldown;
  final Duration repeatInterval;
  final Duration postUnspeakableMute;

  DateTime? _lastSpokenAt;
  DateTime? _lastUnspeakableAt;
  final Map<String, DateTime> _lastMessageAt = <String, DateTime>{};

  VoiceCueService({
    required VoiceSpeaker speaker,
    this.cooldown = const Duration(seconds: 6),
    this.repeatInterval = const Duration(seconds: 12),
    this.postUnspeakableMute = const Duration(milliseconds: 1200),
  }) : _speaker = speaker;

  Future<bool> speakIfAllowed(
    String message,
    WorkoutGuidanceState state, {
    DateTime? now,
    bool isCritical = false,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return false;

    final at = now ?? DateTime.now();
    if (!_isSpeakableState(state)) {
      _lastUnspeakableAt = at;
      return false;
    }

    final unspeakableAt = _lastUnspeakableAt;
    if (!isCritical &&
        unspeakableAt != null &&
        at.difference(unspeakableAt) < postUnspeakableMute) {
      return false;
    }

    final last = _lastSpokenAt;
    if (last != null && at.difference(last) < cooldown) {
      return false;
    }
    final repeatAt = _lastMessageAt[trimmed];
    if (!isCritical &&
        repeatAt != null &&
        at.difference(repeatAt) < repeatInterval) {
      return false;
    }

    await _speaker.speak(trimmed);
    _lastSpokenAt = at;
    _lastMessageAt[trimmed] = at;
    return true;
  }

  bool _isSpeakableState(WorkoutGuidanceState state) =>
      state == WorkoutGuidanceState.aligning ||
      state == WorkoutGuidanceState.holding;

  Future<void> reset() async {
    _lastSpokenAt = null;
    _lastUnspeakableAt = null;
    _lastMessageAt.clear();
    await _speaker.stop();
  }

  Future<void> dispose() => _speaker.stop();
}
