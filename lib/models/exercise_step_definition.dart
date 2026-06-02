class ExerciseStepDefinition {
  final int stepIndex;
  final String poseName;
  final int holdSeconds;
  final int restSeconds;
  final DateTime? updatedAt;

  const ExerciseStepDefinition({
    required this.stepIndex,
    required this.poseName,
    required this.holdSeconds,
    required this.restSeconds,
    required this.updatedAt,
  });

  factory ExerciseStepDefinition.fromMap(Map<String, dynamic> map) {
    return ExerciseStepDefinition(
      stepIndex: _toInt(map['step_index']),
      poseName: map['pose_name']?.toString() ?? '',
      holdSeconds: _toInt(map['hold_seconds'], fallback: 20),
      restSeconds: _toInt(map['rest_seconds'], fallback: 30),
      updatedAt: _parseDate(map['updated_at']),
    );
  }

  Map<String, Object?> toInsertMap({required String exerciseId}) {
    return <String, Object?>{
      'exercise_id': exerciseId,
      'step_index': stepIndex,
      'pose_name': poseName.trim(),
      'hold_seconds': holdSeconds,
      'rest_seconds': restSeconds,
    };
  }

  ExerciseStepDefinition copyWith({
    int? stepIndex,
    String? poseName,
    int? holdSeconds,
    int? restSeconds,
    DateTime? updatedAt,
  }) {
    return ExerciseStepDefinition(
      stepIndex: stepIndex ?? this.stepIndex,
      poseName: poseName ?? this.poseName,
      holdSeconds: holdSeconds ?? this.holdSeconds,
      restSeconds: restSeconds ?? this.restSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static int _toInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
