import 'dart:convert';

import 'daily_challenge_step.dart';

enum DailyChallengeStatus { inProgress, completed }

extension DailyChallengeStatusX on DailyChallengeStatus {
  String get dbValue {
    switch (this) {
      case DailyChallengeStatus.inProgress:
        return 'in_progress';
      case DailyChallengeStatus.completed:
        return 'completed';
    }
  }

  static DailyChallengeStatus fromDbValue(String value) {
    switch (value) {
      case 'completed':
        return DailyChallengeStatus.completed;
      case 'in_progress':
      default:
        return DailyChallengeStatus.inProgress;
    }
  }
}

class DailyChallenge {
  final String dateKey;
  final DailyChallengeStatus status;
  final int skipCount;
  final int totalSteps;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;
  final List<String> sequence;

  const DailyChallenge({
    required this.dateKey,
    required this.status,
    required this.skipCount,
    required this.totalSteps,
    required this.startedAt,
    required this.completedAt,
    required this.updatedAt,
    required this.sequence,
  });

  bool get isCompleted => status == DailyChallengeStatus.completed;

  factory DailyChallenge.fromMap(Map<String, Object?> map) {
    return DailyChallenge(
      dateKey: map['date_key']?.toString() ?? '',
      status: DailyChallengeStatusX.fromDbValue(
        map['status']?.toString() ?? 'in_progress',
      ),
      skipCount: _toInt(map['skip_count']),
      totalSteps: _toInt(map['total_steps']),
      startedAt: _toDateTime(map['started_at']),
      completedAt: _toDateTime(map['completed_at']),
      updatedAt: _toDateTime(map['updated_at']),
      sequence: _parseSequence(map['sequence_json']?.toString() ?? '[]'),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'date_key': dateKey,
      'status': status.dbValue,
      'skip_count': skipCount,
      'total_steps': totalSteps,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'sequence_json': _sequenceToJson(sequence),
    };
  }

  DailyChallenge copyWith({
    DailyChallengeStatus? status,
    int? skipCount,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) {
    return DailyChallenge(
      dateKey: dateKey,
      status: status ?? this.status,
      skipCount: skipCount ?? this.skipCount,
      totalSteps: totalSteps,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sequence: sequence,
    );
  }

  static String _sequenceToJson(List<String> values) {
    return jsonEncode(values);
  }

  static List<String> _parseSequence(String rawJsonArray) {
    try {
      final decoded = jsonDecode(rawJsonArray);
      if (decoded is! List) return const <String>[];
      return decoded.map((item) => item.toString()).toList();
    } catch (_) {
      return const <String>[];
    }
  }

  static int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _toDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

class DailyChallengeBundle {
  final DailyChallenge challenge;
  final List<DailyChallengeStep> steps;

  const DailyChallengeBundle({required this.challenge, required this.steps});

  int get completedStepsCount => steps
      .where((step) => step.status == DailyChallengeStepStatus.completed)
      .length;
  int get skippedStepsCount => steps
      .where((step) => step.status == DailyChallengeStepStatus.skipped)
      .length;
  int get pendingStepsCount => steps
      .where((step) => step.status == DailyChallengeStepStatus.pending)
      .length;

  bool get hasStarted => completedStepsCount > 0 || skippedStepsCount > 0;

  int get nextPendingStepIndex {
    final nextPending = steps.firstWhere(
      (step) => step.status == DailyChallengeStepStatus.pending,
      orElse: () => steps.last,
    );
    return nextPending.stepIndex;
  }
}
