import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/models/workout_guidance_snapshot.dart';
import 'package:zenpose/services/voice_cue_service.dart';

class _FakeSpeaker implements VoiceSpeaker {
  final List<String> spoken = <String>[];
  int stopCalls = 0;

  @override
  Future<void> speak(String message) async {
    spoken.add(message);
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }
}

class _SlowSpeaker implements VoiceSpeaker {
  final List<String> spoken = <String>[];
  final Completer<void> completer = Completer<void>();

  @override
  Future<void> speak(String message) {
    spoken.add(message);
    return completer.future;
  }

  @override
  Future<void> stop() async {}
}

class _FakeTtsEngine implements TtsEngine {
  final dynamic voices;
  final bool failVoiceLookup;
  final List<String> spoken = <String>[];
  Map<String, String>? selectedVoice;
  int stopCalls = 0;

  _FakeTtsEngine({
    this.voices = const <Map<String, String>>[],
    this.failVoiceLookup = false,
  });

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => null;

  @override
  Future<dynamic> getVoices() async {
    if (failVoiceLookup) {
      throw StateError('Voice lookup unavailable');
    }
    return voices;
  }

  @override
  Future<dynamic> setPitch(double pitch) async => null;

  @override
  Future<dynamic> setSpeechRate(double rate) async => null;

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async {
    selectedVoice = voice;
  }

  @override
  Future<dynamic> setVolume(double volume) async => null;

  @override
  Future<dynamic> speak(String message) async {
    spoken.add(message);
  }

  @override
  Future<dynamic> stop() async {
    stopCalls += 1;
  }
}

void main() {
  group('FlutterTtsVoiceSpeaker', () {
    test(
      'selects a natural English voice and pauses between phrases',
      () async {
        final engine = _FakeTtsEngine(
          voices: const <Map<String, String>>[
            {'name': 'Basic Spanish', 'locale': 'es-ES'},
            {'name': 'Google US English Natural', 'locale': 'en-US'},
            {'name': 'Basic English', 'locale': 'en-US'},
          ],
        );
        final waits = <Duration>[];
        final speaker = FlutterTtsVoiceSpeaker(
          engine: engine,
          wait: (duration) async => waits.add(duration),
        );

        await speaker.speak('Gently raise your right arm. Keep breathing.');

        expect(engine.selectedVoice, <String, String>{
          'name': 'Google US English Natural',
          'locale': 'en-US',
        });
        expect(engine.spoken, <String>[
          'Gently raise your right arm.',
          'Keep breathing.',
        ]);
        expect(waits, <Duration>[FlutterTtsVoiceSpeaker.defaultPhrasePause]);
      },
    );

    test('ignores empty phrase fragments', () async {
      final engine = _FakeTtsEngine();
      final speaker = FlutterTtsVoiceSpeaker(
        engine: engine,
        wait: (_) async {},
      );

      await speaker.speak(' . Ease into the outline. ! Take a slow breath.');

      expect(engine.spoken, <String>[
        'Ease into the outline.',
        'Take a slow breath.',
      ]);
    });

    test('continues speaking when voice lookup fails', () async {
      final engine = _FakeTtsEngine(failVoiceLookup: true);
      final speaker = FlutterTtsVoiceSpeaker(
        engine: engine,
        wait: (_) async {},
      );

      await speaker.speak('Hold still for a moment.');

      expect(engine.selectedVoice, isNull);
      expect(engine.spoken, <String>['Hold still for a moment.']);
    });
  });

  group('VoiceCueService', () {
    test('respects cooldown and same-message repeat interval', () async {
      final speaker = _FakeSpeaker();
      final service = VoiceCueService(
        speaker: speaker,
        cooldown: const Duration(seconds: 3),
        repeatInterval: const Duration(seconds: 12),
      );
      final t0 = DateTime(2026, 3, 14, 10, 0, 0);

      final first = await service.speakIfAllowed(
        'Straighten your left leg',
        WorkoutGuidanceState.aligning,
        now: t0,
      );
      final cooldownBlocked = await service.speakIfAllowed(
        'Raise your right arm',
        WorkoutGuidanceState.aligning,
        now: t0.add(const Duration(seconds: 1)),
      );
      final repeatBlocked = await service.speakIfAllowed(
        'Straighten your left leg',
        WorkoutGuidanceState.aligning,
        now: t0.add(const Duration(seconds: 4)),
      );
      final third = await service.speakIfAllowed(
        'Straighten your left leg',
        WorkoutGuidanceState.aligning,
        now: t0.add(const Duration(seconds: 13)),
      );

      expect(first, isTrue);
      expect(cooldownBlocked, isFalse);
      expect(repeatBlocked, isFalse);
      expect(third, isTrue);
      expect(speaker.spoken, <String>[
        'Straighten your left leg',
        'Straighten your left leg',
      ]);
    });

    test('allows speech when no user is detected', () async {
      final speaker = _FakeSpeaker();
      final service = VoiceCueService(speaker: speaker);

      final spoken = await service.speakIfAllowed(
        'Step into frame',
        WorkoutGuidanceState.noUserDetected,
      );

      expect(spoken, isTrue);
      expect(speaker.spoken, <String>['Step into frame']);
    });

    test('mutes speech shortly after unspeakable states', () async {
      final speaker = _FakeSpeaker();
      final service = VoiceCueService(
        speaker: speaker,
        cooldown: const Duration(seconds: 1),
        repeatInterval: const Duration(seconds: 1),
        postUnspeakableMute: const Duration(milliseconds: 1200),
      );
      final t0 = DateTime(2026, 3, 14, 10, 0, 0);

      final unspeakable = await service.speakIfAllowed(
        'Completed',
        WorkoutGuidanceState.completed,
        now: t0,
      );
      final mutedAfterRecovery = await service.speakIfAllowed(
        'Raise your right arm',
        WorkoutGuidanceState.aligning,
        now: t0.add(const Duration(milliseconds: 500)),
      );
      final allowedLater = await service.speakIfAllowed(
        'Raise your right arm',
        WorkoutGuidanceState.aligning,
        now: t0.add(const Duration(milliseconds: 1500)),
      );

      expect(unspeakable, isFalse);
      expect(mutedAfterRecovery, isFalse);
      expect(allowedLater, isTrue);
      expect(speaker.spoken, <String>['Raise your right arm']);
    });

    test('allows speech when pose is unstable', () async {
      final speaker = _FakeSpeaker();
      final service = VoiceCueService(speaker: speaker);

      final spoken = await service.speakIfAllowed(
        'Hold still',
        WorkoutGuidanceState.unstablePose,
      );

      expect(spoken, isTrue);
      expect(speaker.spoken, <String>['Hold still']);
    });

    test('supports periodic refresh for repeated coaching cues', () async {
      final speaker = _FakeSpeaker();
      final service = VoiceCueService(
        speaker: speaker,
        cooldown: const Duration(seconds: 2),
        repeatInterval: const Duration(seconds: 6),
      );
      final t0 = DateTime(2026, 3, 14, 10, 0, 0);

      final first = await service.speakIfAllowed(
        'Raise your right arm',
        WorkoutGuidanceState.aligning,
        now: t0,
      );
      final blockedRepeat = await service.speakIfAllowed(
        'Raise your right arm',
        WorkoutGuidanceState.aligning,
        now: t0.add(const Duration(seconds: 4)),
      );
      final refreshedRepeat = await service.speakIfAllowed(
        'Raise your right arm',
        WorkoutGuidanceState.aligning,
        now: t0.add(const Duration(seconds: 7)),
      );

      expect(first, isTrue);
      expect(blockedRepeat, isFalse);
      expect(refreshedRepeat, isTrue);
      expect(speaker.spoken, <String>[
        'Raise your right arm',
        'Raise your right arm',
      ]);
    });

    test('blocks new prompts while speech is still playing', () async {
      final speaker = _SlowSpeaker();
      final service = VoiceCueService(
        speaker: speaker,
        cooldown: Duration.zero,
        repeatInterval: Duration.zero,
      );
      final t0 = DateTime(2026, 3, 14, 10, 0, 0);

      final first = service.speakIfAllowed(
        'Raise your right arm',
        WorkoutGuidanceState.aligning,
        now: t0,
      );
      await Future<void>.delayed(Duration.zero);
      final blockedWhileSpeaking = await service.speakIfAllowed(
        'Straighten your left leg',
        WorkoutGuidanceState.aligning,
        now: t0.add(const Duration(seconds: 1)),
      );

      speaker.completer.complete();

      expect(await first, isTrue);
      expect(blockedWhileSpeaking, isFalse);
      expect(speaker.spoken, <String>['Raise your right arm']);
    });
  });
}
