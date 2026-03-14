import '../models/badge_definition.dart';

/// Static badge catalog used for local seeding and unlock checks.
class BadgeCatalog {
  static const String firstCompletionId = 'first_completion';
  static const String streak3Id = 'streak_3';
  static const String highScore90Id = 'high_score_90';

  static const List<BadgeDefinition> defaultBadges = <BadgeDefinition>[
    BadgeDefinition(
      id: firstCompletionId,
      name: 'First Flow',
      description: 'Complete your first pose session.',
      criteriaType: 'completed_sessions',
      criteriaValue: 1,
    ),
    BadgeDefinition(
      id: streak3Id,
      name: 'Consistency Starter',
      description: 'Reach a 3-day practice streak.',
      criteriaType: 'streak',
      criteriaValue: 3,
    ),
    BadgeDefinition(
      id: highScore90Id,
      name: 'Precision 90',
      description: 'Score at least 90% in a completed pose session.',
      criteriaType: 'score',
      criteriaValue: 90,
    ),
  ];
}
