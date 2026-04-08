import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/models/badge_definition.dart';
import 'package:zenpose/models/badge_progress_snapshot.dart';
import 'package:zenpose/models/pose_result.dart';
import 'package:zenpose/models/profile_challenge_models.dart';
import 'package:zenpose/models/unlocked_badge.dart';
import 'package:zenpose/models/user_stats.dart';
import 'package:zenpose/screens/achievements_screen.dart';
import 'package:zenpose/screens/profile_screen.dart';
import 'package:zenpose/theme/zen_theme.dart';

void main() {
  final stats = UserStats(
    currentStreak: 4,
    longestStreak: 8,
    totalXp: 920,
    lastActiveDate: DateTime(2026, 4, 10),
  );
  final results = <PoseResult>[
    PoseResult(
      poseName: 'Tree',
      bestScore: 88,
      holdDuration: 60,
      completed: true,
      timestamp: DateTime(2026, 4, 10, 8, 0),
    ),
    PoseResult(
      poseName: 'Plank',
      bestScore: 92,
      holdDuration: 90,
      completed: true,
      timestamp: DateTime(2026, 4, 9, 8, 0),
    ),
    PoseResult(
      poseName: 'Warrior 2',
      bestScore: 84,
      holdDuration: 60,
      completed: true,
      timestamp: DateTime(2026, 4, 9, 18, 0),
    ),
  ];
  const definitions = <BadgeDefinition>[
    BadgeDefinition(
      id: 'first_completion',
      name: 'First Breath',
      description: 'Complete your first session',
      criteriaType: 'completed_sessions',
      criteriaValue: 1,
    ),
    BadgeDefinition(
      id: 'sessions_5',
      name: 'Flow Builder',
      description: 'Complete 5 sessions',
      criteriaType: 'completed_sessions',
      criteriaValue: 5,
    ),
    BadgeDefinition(
      id: 'streak_7',
      name: 'Weekly Flow',
      description: 'Reach 7 day streak',
      criteriaType: 'streak',
      criteriaValue: 7,
    ),
  ];
  final unlocked = <UnlockedBadge>[
    UnlockedBadge(
      badgeId: 'first_completion',
      name: 'First Breath',
      description: 'Complete your first session',
      unlockedAt: DateTime(2026, 4, 1),
    ),
  ];

  testWidgets('profile activity tabs switch headline metric', (tester) async {
    _setLargeSurface(tester);
    await tester.pumpWidget(
      _app(
        ProfileScreen(
          loadUserStats: () async => stats,
          loadBadgeCount: () async => 1,
          loadAllResults: () async => results,
          loadBadgeDefinitions: () async => definitions,
          loadUnlockedBadges: () async => unlocked,
          loadChallenges: () async => const <ChallengeProgressSnapshot>[],
          nowBuilder: () => DateTime(2026, 4, 10, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    String headline() => tester
        .widget<Text>(find.byKey(const Key('profile-activity-headline')))
        .data!;

    expect(find.byKey(const Key('profile-activity-card')), findsOneWidget);
    expect(headline(), '1.0 min');

    await tester.tap(find.byKey(const Key('profile-activity-tab-sessions')));
    await tester.pumpAndSettle();
    expect(headline(), '1');

    await tester.tap(find.byKey(const Key('profile-activity-tab-score')));
    await tester.pumpAndSettle();
    expect(headline(), '88.0%');
  });

  testWidgets(
    'profile activity headline uses latest active day when trailing days are empty',
    (tester) async {
      _setLargeSurface(tester);
      await tester.pumpWidget(
        _app(
          ProfileScreen(
            loadUserStats: () async => stats,
            loadBadgeCount: () async => 1,
            loadAllResults: () async => results,
            loadBadgeDefinitions: () async => definitions,
            loadUnlockedBadges: () async => unlocked,
            loadChallenges: () async => const <ChallengeProgressSnapshot>[],
            nowBuilder: () => DateTime(2026, 4, 12, 12),
          ),
        ),
      );
      await tester.pumpAndSettle();

      String headline() => tester
          .widget<Text>(find.byKey(const Key('profile-activity-headline')))
          .data!;

      expect(headline(), '1.0 min');

      await tester.tap(find.byKey(const Key('profile-activity-tab-sessions')));
      await tester.pumpAndSettle();
      expect(headline(), '1');

      await tester.tap(find.byKey(const Key('profile-activity-tab-score')));
      await tester.pumpAndSettle();
      expect(headline(), '88.0%');
    },
  );

  testWidgets('profile achievements preview opens achievements screen', (
    tester,
  ) async {
    _setLargeSurface(tester);
    await tester.pumpWidget(
      _app(
        ProfileScreen(
          loadUserStats: () async => stats,
          loadBadgeCount: () async => 1,
          loadAllResults: () async => results,
          loadBadgeDefinitions: () async => definitions,
          loadUnlockedBadges: () async => unlocked,
          loadChallenges: () async => const <ChallengeProgressSnapshot>[],
          nowBuilder: () => DateTime(2026, 4, 10, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('profile-achievements-preview')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('profile-achievements-view-all')));
    await tester.pumpAndSettle();

    expect(find.byType(AchievementsScreen), findsOneWidget);
    expect(find.byKey(const Key('achievements-grid')), findsOneWidget);
  });

  testWidgets('achievements screen renders locked and unlocked progress', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final badges = <BadgeProgressSnapshot>[
      BadgeProgressSnapshot(
        definition: definitions[0],
        isUnlocked: true,
        unlockedAt: DateTime(2026, 4, 1),
        currentValue: 1,
        targetValue: 1,
        progressRatio: 1,
        progressLabel: '1 of 1',
      ),
      BadgeProgressSnapshot(
        definition: definitions[1],
        isUnlocked: false,
        unlockedAt: null,
        currentValue: 3,
        targetValue: 5,
        progressRatio: 0.6,
        progressLabel: '3 of 5',
      ),
    ];

    await tester.pumpWidget(_app(AchievementsScreen(badges: badges)));
    await tester.pumpAndSettle();

    expect(find.text('First Breath'), findsOneWidget);
    expect(find.text('Flow Builder'), findsOneWidget);
    expect(
      find.byKey(const Key('achievement-progress-first_completion')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('achievement-progress-sessions_5')),
      findsOneWidget,
    );
    expect(find.text('3 of 5'), findsOneWidget);
  });
}

Widget _app(Widget child) {
  return MaterialApp(
    theme: ZenTheme.build(),
    home: Scaffold(body: child),
  );
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
