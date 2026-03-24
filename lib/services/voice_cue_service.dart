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

  DateTime? _lastSpokenAt;
  String? _lastMessage;

  VoiceCueService({
    required VoiceSpeaker speaker,
    this.cooldown = const Duration(seconds: 3),
  }) : _speaker = speaker;

  Future<bool> speakIfAllowed(
    String message,
    WorkoutGuidanceState state, {
    DateTime? now,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return false;
    if (!_isSpeakableState(state)) return false;

    final at = now ?? DateTime.now();
    final last = _lastSpokenAt;
    if (last != null && at.difference(last) < cooldown) {
      return false;
    }
    if (_lastMessage == trimmed &&
        last != null &&
        at.difference(last) < cooldown) {
      return false;
    }

    await _speaker.speak(trimmed);
    _lastSpokenAt = at;
    _lastMessage = trimmed;
    return true;
  }

  bool _isSpeakableState(WorkoutGuidanceState state) =>
      state == WorkoutGuidanceState.aligning ||
      state == WorkoutGuidanceState.holding;

  Future<void> reset() async {
    _lastSpokenAt = null;
    _lastMessage = null;
    await _speaker.stop();
  }

  Future<void> dispose() => _speaker.stop();
}
