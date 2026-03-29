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

void main() {
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

    test('suppresses speech when no user is detected', () async {
      final speaker = _FakeSpeaker();
      final service = VoiceCueService(speaker: speaker);

      final spoken = await service.speakIfAllowed(
        'Step into frame',
        WorkoutGuidanceState.noUserDetected,
      );

      expect(spoken, isFalse);
      expect(speaker.spoken, isEmpty);
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
        'Hold still',
        WorkoutGuidanceState.unstablePose,
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

    test('suppresses speech when pose is unstable', () async {
      final speaker = _FakeSpeaker();
      final service = VoiceCueService(speaker: speaker);

      final spoken = await service.speakIfAllowed(
        'Hold still',
        WorkoutGuidanceState.unstablePose,
      );

      expect(spoken, isFalse);
      expect(speaker.spoken, isEmpty);
    });
  });
}
