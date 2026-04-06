enum SessionHistoryKind { challenge, practice }

enum SessionHistoryPoseStatus { completed, skipped, pending }

class SessionHistoryPoseEntry {
  final String poseName;
  final SessionHistoryPoseStatus status;
  final double? bestScore;
  final double? holdDurationSeconds;

  const SessionHistoryPoseEntry({
    required this.poseName,
    required this.status,
    required this.bestScore,
    required this.holdDurationSeconds,
  });
}

class SessionHistoryEntry {
  final String sessionId;
  final SessionHistoryKind kind;
  final DateTime activityAt;
  final DateTime? startedAt;
  final bool completed;
  final int durationSeconds;
  final double? averageScore;
  final bool isLegacyPractice;
  final List<SessionHistoryPoseEntry> poses;

  const SessionHistoryEntry({
    required this.sessionId,
    required this.kind,
    required this.activityAt,
    required this.startedAt,
    required this.completed,
    required this.durationSeconds,
    required this.averageScore,
    required this.isLegacyPractice,
    required this.poses,
  });

  int get poseCount => poses.length;

  int get completedPoseCount => poses
      .where((pose) => pose.status == SessionHistoryPoseStatus.completed)
      .length;

  bool get hasStarted =>
      poses.any((pose) => pose.status != SessionHistoryPoseStatus.pending) ||
      durationSeconds > 0;
}
