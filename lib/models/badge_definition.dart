/// Static metadata for a gamification badge.
class BadgeDefinition {
  final String id;
  final String name;
  final String description;
  final String criteriaType;
  final double criteriaValue;

  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.criteriaType,
    required this.criteriaValue,
  });

  factory BadgeDefinition.fromMap(Map<String, Object?> map) {
    return BadgeDefinition(
      id: map['badge_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      criteriaType: map['criteria_type']?.toString() ?? '',
      criteriaValue: _toDouble(map['criteria_value']),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'badge_id': id,
      'name': name,
      'description': description,
      'criteria_type': criteriaType,
      'criteria_value': criteriaValue,
    };
  }

  static double _toDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
