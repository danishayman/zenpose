enum DailyChallengeStepStatus { pending, completed, skipped }

extension DailyChallengeStepStatusX on DailyChallengeStepStatus {
  String get dbValue {
    switch (this) {
      case DailyChallengeStepStatus.pending:
        return 'pending';
      case DailyChallengeStepStatus.completed:
        return 'completed';
      case DailyChallengeStepStatus.skipped:
        return 'skipped';
    }
  }

  static DailyChallengeStepStatus fromDbValue(String value) {
    switch (value) {
      case 'completed':
        return DailyChallengeStepStatus.completed;
      case 'skipped':
        return DailyChallengeStepStatus.skipped;
      case 'pending':
      default:
        return DailyChallengeStepStatus.pending;
    }
  }
}

class DailyChallengeStep {
  final String dateKey;
  final int stepIndex;
  final String poseName;
  final DailyChallengeStepStatus status;
  final double? bestScore;
  final double? holdDuration;
  final int? targetHoldSeconds;
  final DateTime? updatedAt;

  const DailyChallengeStep({
    required this.dateKey,
    required this.stepIndex,
    required this.poseName,
    required this.status,
    required this.bestScore,
    required this.holdDuration,
    this.targetHoldSeconds,
    required this.updatedAt,
  });

  bool get isResolved => status != DailyChallengeStepStatus.pending;

  factory DailyChallengeStep.fromMap(Map<String, Object?> map) {
    return DailyChallengeStep(
      dateKey: map['date_key']?.toString() ?? '',
      stepIndex: _toInt(map['step_index']),
      poseName: map['pose_name']?.toString() ?? '',
      status: DailyChallengeStepStatusX.fromDbValue(
        map['status']?.toString() ?? 'pending',
      ),
      bestScore: _toDoubleOrNull(map['best_score']),
      holdDuration: _toDoubleOrNull(map['hold_duration']),
      targetHoldSeconds: _toIntOrNull(map['target_hold_seconds']),
      updatedAt: _toDateTime(map['updated_at']),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'date_key': dateKey,
      'step_index': stepIndex,
      'pose_name': poseName,
      'status': status.dbValue,
      'best_score': bestScore,
      'hold_duration': holdDuration,
      'target_hold_seconds': targetHoldSeconds,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  DailyChallengeStep copyWith({
    DailyChallengeStepStatus? status,
    double? bestScore,
    double? holdDuration,
    int? targetHoldSeconds,
    DateTime? updatedAt,
  }) {
    return DailyChallengeStep(
      dateKey: dateKey,
      stepIndex: stepIndex,
      poseName: poseName,
      status: status ?? this.status,
      bestScore: bestScore ?? this.bestScore,
      holdDuration: holdDuration ?? this.holdDuration,
      targetHoldSeconds: targetHoldSeconds ?? this.targetHoldSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _toDoubleOrNull(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _toIntOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static DateTime? _toDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
