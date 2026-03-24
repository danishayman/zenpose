enum WorkoutGuidanceState {
  initializing,
  noUserDetected,
  unstablePose,
  aligning,
  holding,
  completed,
}

/// Immutable UI snapshot for workout guidance on each frame.
class WorkoutGuidanceSnapshot {
  final double score;
  final double holdProgress;
  final WorkoutGuidanceState state;
  final String? primaryCue;
  final String? secondaryCue;
  final bool shouldResetSession;

  const WorkoutGuidanceSnapshot({
    required this.score,
    required this.holdProgress,
    required this.state,
    required this.primaryCue,
    required this.secondaryCue,
    required this.shouldResetSession,
  });

  const WorkoutGuidanceSnapshot.initializing()
    : score = 0,
      holdProgress = 0,
      state = WorkoutGuidanceState.initializing,
      primaryCue = null,
      secondaryCue = null,
      shouldResetSession = false;

  List<String> get cues => <String>[
    if (primaryCue != null && primaryCue!.isNotEmpty) primaryCue!,
    if (secondaryCue != null && secondaryCue!.isNotEmpty) secondaryCue!,
  ];

  String get statusLabel {
    switch (state) {
      case WorkoutGuidanceState.initializing:
        return 'Initializing';
      case WorkoutGuidanceState.noUserDetected:
        return 'Step into frame';
      case WorkoutGuidanceState.unstablePose:
        return 'Hold still';
      case WorkoutGuidanceState.aligning:
        return 'Align your pose';
      case WorkoutGuidanceState.holding:
        return 'Great hold';
      case WorkoutGuidanceState.completed:
        return 'Completed';
    }
  }
}
