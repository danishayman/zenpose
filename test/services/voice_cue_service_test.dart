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
    test('respects cooldown and avoids rapid duplicate speech', () async {
      final speaker = _FakeSpeaker();
      final service = VoiceCueService(
        speaker: speaker,
        cooldown: const Duration(seconds: 3),
      );
      final t0 = DateTime(2026, 3, 14, 10, 0, 0);

      final first = await service.speakIfAllowed(
        'Straighten your left leg',
        WorkoutGuidanceState.aligning,
        now: t0,
      );
      final second = await service.speakIfAllowed(
        'Straighten your left leg',
        WorkoutGuidanceState.aligning,
        now: t0.add(const Duration(seconds: 1)),
      );
      final third = await service.speakIfAllowed(
        'Straighten your left leg',
        WorkoutGuidanceState.aligning,
        now: t0.add(const Duration(seconds: 4)),
      );

      expect(first, isTrue);
      expect(second, isFalse);
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
