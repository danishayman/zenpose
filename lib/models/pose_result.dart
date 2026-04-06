/// Result of a completed pose attempt.
///
/// [bestScore] is the best similarity score (0–100) achieved during the
/// session. [holdDuration] is in seconds.
enum PoseResultSessionType { challenge, practice }

extension PoseResultSessionTypeX on PoseResultSessionType {
  String get dbValue {
    switch (this) {
      case PoseResultSessionType.challenge:
        return 'challenge';
      case PoseResultSessionType.practice:
        return 'practice';
    }
  }

  static PoseResultSessionType? fromDbValue(String? value) {
    switch (value) {
      case 'challenge':
        return PoseResultSessionType.challenge;
      case 'practice':
        return PoseResultSessionType.practice;
      default:
        return null;
    }
  }
}

class PoseResult {
  final int? id;
  final String poseName;
  final double bestScore;
  final double holdDuration;
  final bool completed;
  final DateTime? timestamp;
  final PoseResultSessionType? sessionType;

  const PoseResult({
    this.id,
    required this.poseName,
    required this.bestScore,
    required this.holdDuration,
    required this.completed,
    this.timestamp,
    this.sessionType,
  });

  factory PoseResult.fromMap(Map<String, Object?> map) {
    final poseName = map['pose_name'] as String?;
    if (poseName == null || poseName.isEmpty) {
      throw const FormatException('Missing pose_name for PoseResult.');
    }

    return PoseResult(
      id: _toInt(map['id']),
      poseName: poseName,
      bestScore: _toDouble(map['best_score']),
      holdDuration: _toDouble(map['hold_duration']),
      completed: _toBool(map['completed']),
      timestamp: _toDateTime(map['timestamp']),
      sessionType: PoseResultSessionTypeX.fromDbValue(
        map['session_type']?.toString(),
      ),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'pose_name': poseName,
      'best_score': bestScore,
      'hold_duration': holdDuration,
      'completed': completed ? 1 : 0,
      'timestamp': timestamp?.toIso8601String(),
      'session_type': sessionType?.dbValue,
    };
    if (includeId && id != null) {
      map['id'] = id;
    }
    return map;
  }

  PoseResult copyWith({
    int? id,
    String? poseName,
    double? bestScore,
    double? holdDuration,
    bool? completed,
    DateTime? timestamp,
    PoseResultSessionType? sessionType,
  }) {
    return PoseResult(
      id: id ?? this.id,
      poseName: poseName ?? this.poseName,
      bestScore: bestScore ?? this.bestScore,
      holdDuration: holdDuration ?? this.holdDuration,
      completed: completed ?? this.completed,
      timestamp: timestamp ?? this.timestamp,
      sessionType: sessionType ?? this.sessionType,
    );
  }

  static int? _toInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double _toDouble(Object? value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static bool _toBool(Object? value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is num) return value != 0;
    final normalized = value?.toString().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }

  static DateTime? _toDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
