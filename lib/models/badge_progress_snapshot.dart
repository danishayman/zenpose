import 'badge_definition.dart';

/// View model for rendering badge progress in profile and achievements UI.
class BadgeProgressSnapshot {
  final BadgeDefinition definition;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final double currentValue;
  final double targetValue;
  final double progressRatio;
  final String progressLabel;

  const BadgeProgressSnapshot({
    required this.definition,
    required this.isUnlocked,
    required this.unlockedAt,
    required this.currentValue,
    required this.targetValue,
    required this.progressRatio,
    required this.progressLabel,
  });
}
