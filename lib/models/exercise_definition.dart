import 'exercise_step_definition.dart';

class ExerciseDefinition {
  final String? id;
  final String name;
  final String description;
  final bool isActive;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ExerciseStepDefinition> steps;

  const ExerciseDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.steps,
  });

  factory ExerciseDefinition.fromMap(Map<String, dynamic> map) {
    final rawSteps = map['exercise_steps'];
    final parsedSteps = rawSteps is List
        ? rawSteps
              .map((row) => ExerciseStepDefinition.fromMap(Map<String, dynamic>.from(row as Map)))
              .toList()
        : <ExerciseStepDefinition>[];
    parsedSteps.sort((a, b) => a.stepIndex.compareTo(b.stepIndex));
    return ExerciseDefinition(
      id: _toNullableTrimmedString(map['id']),
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      isActive: map['is_active'] == true,
      createdBy: _toNullableTrimmedString(map['created_by']),
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
      steps: parsedSteps,
    );
  }

  Map<String, Object?> toExerciseMutationMap({required String currentUserId}) {
    return <String, Object?>{
      'name': name.trim(),
      'description': description.trim(),
      'is_active': isActive,
      'created_by': createdBy ?? currentUserId,
    };
  }

  ExerciseDefinition copyWith({
    String? id,
    String? name,
    String? description,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ExerciseStepDefinition>? steps,
  }) {
    return ExerciseDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      steps: steps ?? this.steps,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static String? _toNullableTrimmedString(Object? value) {
    final str = value?.toString().trim();
    if (str == null || str.isEmpty) return null;
    return str;
  }
}
