import '../models/badge_definition.dart';

/// Static badge catalog used for local seeding and unlock checks.
class BadgeCatalog {
  static const String firstCompletionId = 'first_completion';
  static const String sessions5Id = 'sessions_5';
  static const String sessions25Id = 'sessions_25';
  static const String streak3Id = 'streak_3';
  static const String streak7Id = 'streak_7';
  static const String streak14Id = 'streak_14';
  static const String highScore90Id = 'high_score_90';
  static const String highScore95Id = 'high_score_95';
  static const String highScore98Id = 'high_score_98';

  static const List<BadgeDefinition> defaultBadges = <BadgeDefinition>[
    BadgeDefinition(
      id: firstCompletionId,
      name: 'First Breath',
      description: 'Complete your first pose session.',
      criteriaType: 'completed_sessions',
      criteriaValue: 1,
    ),
    BadgeDefinition(
      id: sessions5Id,
      name: 'Flow Builder',
      description: 'Complete 5 pose sessions.',
      criteriaType: 'completed_sessions',
      criteriaValue: 5,
    ),
    BadgeDefinition(
      id: sessions25Id,
      name: 'Practice Keeper',
      description: 'Complete 25 pose sessions.',
      criteriaType: 'completed_sessions',
      criteriaValue: 25,
    ),
    BadgeDefinition(
      id: streak3Id,
      name: 'Consistency Starter',
      description: 'Reach a 3-day practice streak.',
      criteriaType: 'streak',
      criteriaValue: 3,
    ),
    BadgeDefinition(
      id: streak7Id,
      name: 'Weekly Flow',
      description: 'Reach a 7-day practice streak.',
      criteriaType: 'streak',
      criteriaValue: 7,
    ),
    BadgeDefinition(
      id: streak14Id,
      name: 'Zen Rhythm',
      description: 'Reach a 14-day practice streak.',
      criteriaType: 'streak',
      criteriaValue: 14,
    ),
    BadgeDefinition(
      id: highScore90Id,
      name: 'Precision 90',
      description: 'Score at least 90% in a completed pose session.',
      criteriaType: 'score',
      criteriaValue: 90,
    ),
    BadgeDefinition(
      id: highScore95Id,
      name: 'Alignment 95',
      description: 'Score at least 95% in a completed pose session.',
      criteriaType: 'score',
      criteriaValue: 95,
    ),
    BadgeDefinition(
      id: highScore98Id,
      name: 'Master Balance',
      description: 'Score at least 98% in a completed pose session.',
      criteriaType: 'score',
      criteriaValue: 98,
    ),
  ];
}
