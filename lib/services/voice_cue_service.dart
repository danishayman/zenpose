import 'package:flutter_tts/flutter_tts.dart';

import '../models/workout_guidance_snapshot.dart';

abstract class TtsEngine {
  Future<dynamic> setSpeechRate(double rate);
  Future<dynamic> setPitch(double pitch);
  Future<dynamic> setVolume(double volume);
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion);
  Future<dynamic> speak(String message);
  Future<dynamic> stop();
  Future<dynamic> getVoices();
  Future<dynamic> setVoice(Map<String, String> voice);
}

class FlutterTtsEngine implements TtsEngine {
  final FlutterTts _tts;

  FlutterTtsEngine([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  @override
  Future<dynamic> setSpeechRate(double rate) => _tts.setSpeechRate(rate);

  @override
  Future<dynamic> setPitch(double pitch) => _tts.setPitch(pitch);

  @override
  Future<dynamic> setVolume(double volume) => _tts.setVolume(volume);

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) =>
      _tts.awaitSpeakCompletion(awaitCompletion);

  @override
  Future<dynamic> speak(String message) => _tts.speak(message);

  @override
  Future<dynamic> stop() => _tts.stop();

  @override
  Future<dynamic> getVoices() => _tts.getVoices;

  @override
  Future<dynamic> setVoice(Map<String, String> voice) => _tts.setVoice(voice);
}

abstract class VoiceSpeaker {
  Future<void> speak(String message);
  Future<void> stop();
}

class FlutterTtsVoiceSpeaker implements VoiceSpeaker {
  static const Duration defaultPhrasePause = Duration(milliseconds: 600);

  final TtsEngine _engine;
  final Duration phrasePause;
  final Future<void> Function(Duration duration) _wait;

  Future<void>? _configuration;

  FlutterTtsVoiceSpeaker({
    FlutterTts? tts,
    TtsEngine? engine,
    this.phrasePause = defaultPhrasePause,
    Future<void> Function(Duration duration)? wait,
  }) : assert(tts == null || engine == null),
       _engine = engine ?? FlutterTtsEngine(tts),
       _wait = wait ?? Future<void>.delayed;

  Future<void> _ensureConfigured() =>
      _configuration ??= _configureTextToSpeech();

  Future<void> _configureTextToSpeech() async {
    await _engine.setSpeechRate(0.42);
    await _engine.setPitch(1.0);
    await _engine.setVolume(1.0);
    await _engine.awaitSpeakCompletion(true);
    await _selectNaturalVoice();
  }

  Future<void> _selectNaturalVoice() async {
    try {
      final voices = await _engine.getVoices();
      final selected = _selectPreferredVoice(voices);
      if (selected != null) {
        await _engine.setVoice(selected);
      }
    } catch (_) {
      // Device voice metadata varies by platform; default voice is acceptable.
    }
  }

  Map<String, String>? _selectPreferredVoice(dynamic voices) {
    if (voices is! Iterable) return null;

    final candidates = voices
        .whereType<Map<dynamic, dynamic>>()
        .map(_stringVoiceMap)
        .where((voice) => voice.isNotEmpty)
        .toList();
    if (candidates.isEmpty) return null;

    final english = candidates.where(_isEnglishVoice).toList();
    final pool = english.isNotEmpty ? english : candidates;
    pool.sort((a, b) => _voiceScore(b).compareTo(_voiceScore(a)));
    return pool.first;
  }

  Map<String, String> _stringVoiceMap(Map<dynamic, dynamic> voice) {
    return {
      for (final entry in voice.entries)
        if (entry.key != null && entry.value != null)
          entry.key.toString(): entry.value.toString(),
    };
  }

  bool _isEnglishVoice(Map<String, String> voice) {
    final metadata = _voiceMetadata(voice);
    return metadata.contains('locale:en') ||
        metadata.contains('language:en') ||
        metadata.contains(' en-') ||
        metadata.contains('_en_') ||
        metadata.startsWith('en-') ||
        metadata.startsWith('en_');
  }

  int _voiceScore(Map<String, String> voice) {
    final metadata = _voiceMetadata(voice);
    var score = _isEnglishVoice(voice) ? 100 : 0;

    const highQualityKeywords = <String>[
      'google',
      'neural',
      'enhanced',
      'natural',
      'samantha',
      'karen',
      'daniel',
      'serena',
      'jenny',
    ];
    for (final keyword in highQualityKeywords) {
      if (metadata.contains(keyword)) {
        score += 20;
      }
    }

    if (metadata.contains('en-us') ||
        metadata.contains('en-gb') ||
        metadata.contains('en-au')) {
      score += 10;
    }
    return score;
  }

  String _voiceMetadata(Map<String, String> voice) {
    return voice.entries
        .map((entry) => '${entry.key}:${entry.value}')
        .join(' ')
        .toLowerCase();
  }

  @override
  Future<void> speak(String message) async {
    final phrases = _splitIntoPhrases(message);
    if (phrases.isEmpty) return;

    await _ensureConfigured();
    for (var i = 0; i < phrases.length; i++) {
      await _engine.speak(phrases[i]);
      if (i < phrases.length - 1 && phrasePause > Duration.zero) {
        await _wait(phrasePause);
      }
    }
  }

  List<String> _splitIntoPhrases(String message) {
    return RegExp(r'[^.!?]+[.!?]?')
        .allMatches(message)
        .map((match) => match.group(0)?.trim() ?? '')
        .where((phrase) => phrase.isNotEmpty)
        .where((phrase) => RegExp(r'[A-Za-z0-9]').hasMatch(phrase))
        .toList();
  }

  @override
  Future<void> stop() => _engine.stop();
}

/// Voice prompt throttler for corrective cues.
class VoiceCueService {
  final VoiceSpeaker _speaker;
  final Duration cooldown;
  final Duration repeatInterval;
  final Duration postUnspeakableMute;

  DateTime? _lastSpokenAt;
  DateTime? _lastUnspeakableAt;
  bool _isSpeaking = false;
  final Map<String, DateTime> _lastMessageAt = <String, DateTime>{};

  VoiceCueService({
    required VoiceSpeaker speaker,
    this.cooldown = const Duration(seconds: 6),
    this.repeatInterval = const Duration(seconds: 14),
    this.postUnspeakableMute = const Duration(seconds: 2),
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

    if (_isSpeaking) {
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

    _lastSpokenAt = at;
    _lastMessageAt[trimmed] = at;
    _isSpeaking = true;
    try {
      await _speaker.speak(trimmed);
      return true;
    } finally {
      _isSpeaking = false;
    }
  }

  bool _isSpeakableState(WorkoutGuidanceState state) =>
      state == WorkoutGuidanceState.noUserDetected ||
      state == WorkoutGuidanceState.unstablePose ||
      state == WorkoutGuidanceState.aligning ||
      state == WorkoutGuidanceState.holding;

  Future<void> reset() async {
    _lastSpokenAt = null;
    _lastUnspeakableAt = null;
    _isSpeaking = false;
    _lastMessageAt.clear();
    await _speaker.stop();
  }

  Future<void> dispose() => _speaker.stop();
}
