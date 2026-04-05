class WeeklyWorkoutGoal {
  final String userId;
  final int targetWorkouts;
  final DateTime updatedAt;
  final bool isSynced;

  const WeeklyWorkoutGoal({
    required this.userId,
    required this.targetWorkouts,
    required this.updatedAt,
    required this.isSynced,
  });

  factory WeeklyWorkoutGoal.defaultForUser(String userId) {
    return WeeklyWorkoutGoal(
      userId: userId,
      targetWorkouts: 3,
      updatedAt: DateTime.now().toUtc(),
      isSynced: false,
    );
  }

  factory WeeklyWorkoutGoal.fromMap(Map<String, Object?> map) {
    return WeeklyWorkoutGoal(
      userId: map['user_id']?.toString() ?? '',
      targetWorkouts: _toInt(map['target_workouts'], fallback: 3),
      updatedAt: _toDate(map['updated_at']) ?? DateTime.now().toUtc(),
      isSynced: _toBool(map['is_synced']),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'user_id': userId,
      'target_workouts': targetWorkouts,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  WeeklyWorkoutGoal copyWith({
    String? userId,
    int? targetWorkouts,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return WeeklyWorkoutGoal(
      userId: userId ?? this.userId,
      targetWorkouts: targetWorkouts ?? this.targetWorkouts,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  static int _toInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime? _toDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static bool _toBool(Object? value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is num) return value != 0;
    return value?.toString() == 'true';
  }
}
