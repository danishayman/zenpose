import '../models/workout_guidance_snapshot.dart';

/// Computes a stable per-frame workout guidance state for the UI.
class WorkoutGuidanceService {
  final Duration lostTrackingGrace;

  DateTime? _lastPoseSeenAt;
  double _lastScore = 0;
  double _lastHoldProgress = 0;

  WorkoutGuidanceService({this.lostTrackingGrace = const Duration(seconds: 2)});

  WorkoutGuidanceSnapshot evaluate({
    required bool cameraReady,
    required bool hasPose,
    required bool poseStable,
    required bool poseCompleted,
    required double score,
    required double holdProgress,
    required double scoreThreshold,
    required List<String> feedbackMessages,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final normalizedScore = score.clamp(0.0, 100.0).toDouble();
    final normalizedHold = holdProgress.clamp(0.0, 1.0).toDouble();
    final cleanedFeedback = feedbackMessages
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toList(growable: false);

    if (!cameraReady) {
      return const WorkoutGuidanceSnapshot.initializing();
    }

    if (poseCompleted) {
      _lastScore = normalizedScore;
      _lastHoldProgress = normalizedHold;
      return WorkoutGuidanceSnapshot(
        score: normalizedScore,
        holdProgress: normalizedHold,
        state: WorkoutGuidanceState.completed,
        primaryCue: null,
        secondaryCue: null,
        shouldResetSession: false,
      );
    }

    if (hasPose) {
      _lastPoseSeenAt = at;
      _lastScore = normalizedScore;
      _lastHoldProgress = normalizedHold;

      if (!poseStable) {
        return WorkoutGuidanceSnapshot(
          score: normalizedScore,
          holdProgress: normalizedHold,
          state: WorkoutGuidanceState.unstablePose,
          primaryCue: 'Hold still',
          secondaryCue: null,
          shouldResetSession: false,
        );
      }

      if (normalizedScore >= scoreThreshold && normalizedHold > 0) {
        return WorkoutGuidanceSnapshot(
          score: normalizedScore,
          holdProgress: normalizedHold,
          state: WorkoutGuidanceState.holding,
          primaryCue: cleanedFeedback.isNotEmpty ? cleanedFeedback.first : null,
          secondaryCue: cleanedFeedback.length > 1 ? cleanedFeedback[1] : null,
          shouldResetSession: false,
        );
      }

      return WorkoutGuidanceSnapshot(
        score: normalizedScore,
        holdProgress: normalizedHold,
        state: WorkoutGuidanceState.aligning,
        primaryCue: cleanedFeedback.isNotEmpty
            ? cleanedFeedback.first
            : 'Match the outline',
        secondaryCue: cleanedFeedback.length > 1 ? cleanedFeedback[1] : null,
        shouldResetSession: false,
      );
    }

    final graceExpired =
        _lastPoseSeenAt == null ||
        at.difference(_lastPoseSeenAt!) > lostTrackingGrace;
    if (graceExpired) {
      _lastScore = 0;
      _lastHoldProgress = 0;
    }

    return WorkoutGuidanceSnapshot(
      score: graceExpired ? 0 : _lastScore,
      holdProgress: graceExpired ? 0 : _lastHoldProgress,
      state: WorkoutGuidanceState.noUserDetected,
      primaryCue: 'Step into frame',
      secondaryCue: null,
      shouldResetSession: graceExpired,
    );
  }

  void reset() {
    _lastPoseSeenAt = null;
    _lastScore = 0;
    _lastHoldProgress = 0;
  }
}
