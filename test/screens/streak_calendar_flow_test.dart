import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/models/body_measurement.dart';
import 'package:zenpose/models/daily_challenge.dart';
import 'package:zenpose/models/daily_challenge_step.dart';
import 'package:zenpose/models/pose_result.dart';
import 'package:zenpose/models/pose_template.dart';
import 'package:zenpose/models/profile_challenge_models.dart';
import 'package:zenpose/models/session_history_entry.dart';
import 'package:zenpose/models/user_stats.dart';
import 'package:zenpose/models/weekly_workout_goal.dart';
import 'package:zenpose/screens/home_screen.dart';
import 'package:zenpose/screens/profile_screen.dart';
import 'package:zenpose/screens/progress_dashboard_screen.dart';
import 'package:zenpose/screens/streak_calendar_screen.dart';
import 'package:zenpose/theme/zen_theme.dart';

void main() {
  final baseStats = UserStats(
    currentStreak: 2,
    longestStreak: 6,
    totalXp: 503,
    lastActiveDate: DateTime(2026, 3, 29),
  );
  final challengeBundle = _bundleFor('2026-03-29');
  final completedResults = <PoseResult>[
    PoseResult(
      poseName: 'Tree',
      bestScore: 88,
      holdDuration: 45,
      completed: true,
      timestamp: DateTime(2026, 3, 27, 10, 0),
    ),
    PoseResult(
      poseName: 'Downdog',
      bestScore: 84,
      holdDuration: 45,
      completed: true,
      timestamp: DateTime(2026, 3, 24, 9, 0),
    ),
  ];
  final homeNow = DateTime(2026, 3, 31, 9, 0);
  final homeWeeklyResults = <PoseResult>[
    PoseResult(
      poseName: 'Tree',
      bestScore: 86,
      holdDuration: 45,
      completed: true,
      timestamp: DateTime(2026, 3, 30, 8, 30),
    ),
    PoseResult(
      poseName: 'Plank',
      bestScore: 81,
      holdDuration: 45,
      completed: true,
      timestamp: DateTime(2026, 3, 29, 8, 30),
    ),
    PoseResult(
      poseName: 'Downdog',
      bestScore: 78,
      holdDuration: 45,
      completed: true,
      timestamp: DateTime(2026, 3, 24, 8, 30),
    ),
  ];
  final homeHistory = <SessionHistoryEntry>[
    SessionHistoryEntry(
      sessionId: 'challenge:2026-03-29',
      kind: SessionHistoryKind.challenge,
      activityAt: DateTime(2026, 3, 29, 10, 30),
      startedAt: DateTime(2026, 3, 29, 10, 0),
      completed: false,
      durationSeconds: 95,
      averageScore: 84,
      isLegacyPractice: false,
      poses: const <SessionHistoryPoseEntry>[
        SessionHistoryPoseEntry(
          poseName: 'Tree',
          status: SessionHistoryPoseStatus.completed,
          bestScore: 84,
          holdDurationSeconds: 45,
        ),
        SessionHistoryPoseEntry(
          poseName: 'Plank',
          status: SessionHistoryPoseStatus.pending,
          bestScore: null,
          holdDurationSeconds: null,
        ),
      ],
    ),
    SessionHistoryEntry(
      sessionId: 'practice:1',
      kind: SessionHistoryKind.practice,
      activityAt: DateTime(2026, 3, 28, 20, 0),
      startedAt: DateTime(2026, 3, 28, 20, 0),
      completed: true,
      durationSeconds: 180,
      averageScore: 88,
      isLegacyPractice: true,
      poses: const <SessionHistoryPoseEntry>[
        SessionHistoryPoseEntry(
          poseName: 'Downdog',
          status: SessionHistoryPoseStatus.completed,
          bestScore: 88,
          holdDurationSeconds: 180,
        ),
      ],
    ),
  ];
  final weeklyGoalHistory = <SessionHistoryEntry>[
    SessionHistoryEntry(
      sessionId: 'challenge:2026-03-29',
      kind: SessionHistoryKind.challenge,
      activityAt: DateTime(2026, 3, 29, 10, 30),
      startedAt: DateTime(2026, 3, 29, 10, 0),
      completed: true,
      durationSeconds: 225,
      averageScore: 84,
      isLegacyPractice: false,
      poses: const <SessionHistoryPoseEntry>[
        SessionHistoryPoseEntry(
          poseName: 'Tree',
          status: SessionHistoryPoseStatus.completed,
          bestScore: 84,
          holdDurationSeconds: 45,
        ),
        SessionHistoryPoseEntry(
          poseName: 'Plank',
          status: SessionHistoryPoseStatus.completed,
          bestScore: 82,
          holdDurationSeconds: 45,
        ),
        SessionHistoryPoseEntry(
          poseName: 'Downdog',
          status: SessionHistoryPoseStatus.completed,
          bestScore: 86,
          holdDurationSeconds: 45,
        ),
      ],
    ),
    SessionHistoryEntry(
      sessionId: 'practice:2',
      kind: SessionHistoryKind.practice,
      activityAt: DateTime(2026, 3, 30, 20, 0),
      startedAt: DateTime(2026, 3, 30, 20, 0),
      completed: true,
      durationSeconds: 45,
      averageScore: 90,
      isLegacyPractice: false,
      poses: const <SessionHistoryPoseEntry>[
        SessionHistoryPoseEntry(
          poseName: 'Warrior',
          status: SessionHistoryPoseStatus.completed,
          bestScore: 90,
          holdDurationSeconds: 45,
        ),
      ],
    ),
  ];

  WidgetBuilder testStreakBuilder() =>
      (_) => StreakCalendarScreen(
        loadUserStats: () async => baseStats,
        loadResults: () async => completedResults,
        nowBuilder: () => DateTime(2026, 3, 29),
      );

  HomeScreen buildHome({
    Future<List<SessionHistoryEntry>> Function()? loadSessionHistory,
    Future<List<PoseResult>> Function()? loadAllResults,
    Future<WeeklyWorkoutGoal> Function()? loadWeeklyGoal,
    Future<void> Function(int targetWorkouts)? saveWeeklyGoal,
  }) {
    return HomeScreen(
      loadTodayChallenge: () async => challengeBundle,
      loadUserStats: () async => baseStats,
      loadBadgeCount: () async => 1,
      loadSessionHistory: loadSessionHistory ?? () async => homeHistory,
      loadPoseTemplates: () async => const <PoseTemplate>[],
      loadAllResults: loadAllResults ?? () async => homeWeeklyResults,
      loadWeeklyGoal:
          loadWeeklyGoal ??
          () async => WeeklyWorkoutGoal(
            userId: 'u1',
            targetWorkouts: 3,
            updatedAt: homeNow,
            isSynced: true,
          ),
      saveWeeklyGoal: saveWeeklyGoal,
      nowBuilder: () => homeNow,
      streakCalendarBuilder: testStreakBuilder(),
    );
  }

  testWidgets('tapping Home Day Streak opens streak calendar', (tester) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(_app(buildHome()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Day Streak'));
    await tester.pumpAndSettle();

    expect(find.byType(StreakCalendarScreen), findsOneWidget);
    expect(find.text('Streak Calendar'), findsOneWidget);
  });

  testWidgets('tapping Profile Day Streak opens streak calendar', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _app(
        ProfileScreen(
          loadUserStats: () async => baseStats,
          loadBadgeCount: () async => 1,
          loadAllResults: () async => completedResults,
          loadChallenges: () async => const <ChallengeProgressSnapshot>[],
          streakCalendarBuilder: testStreakBuilder(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Day Streak'));
    await tester.pumpAndSettle();

    expect(find.byType(StreakCalendarScreen), findsOneWidget);
  });

  testWidgets('home screen shows recent session history', (tester) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(_app(buildHome()));
    await tester.pumpAndSettle();

    expect(find.text('Session History'), findsOneWidget);
    expect(find.text('Daily Yoga Flow'), findsOneWidget);
    expect(find.text('Practice Session'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Avg Score'), findsNWidgets(2));
    expect(find.text('Poses'), findsNWidgets(2));
    expect(find.text('84%'), findsWidgets);
  });

  testWidgets('home screen session history empty state appears', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _app(
        buildHome(
          loadSessionHistory: () async => const <SessionHistoryEntry>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No session history yet. Complete your first practice to start tracking.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('progress dashboard renders new tabs', (tester) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _app(
        ProgressDashboardScreen(
          loadAllResults: () async => completedResults,
          loadWeeklyGoal: () async => WeeklyWorkoutGoal(
            userId: 'u1',
            targetWorkouts: 3,
            updatedAt: DateTime(2026, 3, 29),
            isSynced: true,
          ),
          loadMeasurementHistory: (_) async => const <BodyMeasurement>[],
          loadPoseTemplates: () async => const <PoseTemplate>[],
          nowBuilder: () => DateTime(2026, 3, 29),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Exercises'), findsOneWidget);
    expect(find.text('Measures'), findsOneWidget);
  });

  testWidgets('month navigation updates header label', (tester) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _app(
        StreakCalendarScreen(
          loadUserStats: () async => baseStats,
          loadResults: () async => completedResults,
          nowBuilder: () => DateTime(2026, 3, 29),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('March 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('streak-next-month')));
    await tester.pumpAndSettle();
    expect(find.text('April 2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('streak-prev-month')));
    await tester.pumpAndSettle();
    expect(find.text('March 2026'), findsOneWidget);
  });

  testWidgets('active and inactive month states render correctly', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _app(
        StreakCalendarScreen(
          loadUserStats: () async => baseStats,
          loadResults: () async => completedResults,
          nowBuilder: () => DateTime(2026, 3, 29),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('streak-day-2026-03-27-active')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('streak-next-month')));
    await tester.pumpAndSettle();
    expect(
      find.text('No completed sessions in this month yet.'),
      findsOneWidget,
    );
  });

  testWidgets('empty-state message appears when there is no activity', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _app(
        StreakCalendarScreen(
          loadUserStats: () async => baseStats,
          loadResults: () async => const <PoseResult>[],
          nowBuilder: () => DateTime(2026, 3, 29),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Complete a session to start your streak calendar.'),
      findsOneWidget,
    );
  });

  testWidgets('non-tappable stat cards still do not navigate', (tester) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(_app(buildHome()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Total XP'));
    await tester.pumpAndSettle();

    expect(find.byType(StreakCalendarScreen), findsNothing);
  });

  testWidgets('home screen shows weekly goal progress above stats', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _app(buildHome(loadSessionHistory: () async => weeklyGoalHistory)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-goal-progress-card')), findsOneWidget);
    expect(find.text('Weekly Goal'), findsOneWidget);
    expect(find.text('2 / 3 sessions completed'), findsOneWidget);
    expect(find.text('1 left'), findsOneWidget);

    final goalY = tester
        .getTopLeft(find.byKey(const Key('home-goal-progress-card')))
        .dy;
    final statsY = tester.getTopLeft(find.text('Your Stats')).dy;
    expect(goalY, lessThan(statsY));
  });

  testWidgets('home screen shows congrats when weekly goal is met', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _app(
        buildHome(
          loadSessionHistory: () async => weeklyGoalHistory,
          loadWeeklyGoal: () async => WeeklyWorkoutGoal(
            userId: 'u1',
            targetWorkouts: 2,
            updatedAt: homeNow,
            isSynced: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 / 2 sessions completed'), findsOneWidget);
    expect(find.text('Congrats! Goal met 🎉'), findsOneWidget);
  });

  testWidgets('home set goal editor updates weekly target on save', (
    tester,
  ) async {
    _setLargeSurface(tester);
    var goal = 3;

    await tester.pumpWidget(
      _app(
        buildHome(
          loadSessionHistory: () async => weeklyGoalHistory,
          loadWeeklyGoal: () async => WeeklyWorkoutGoal(
            userId: 'u1',
            targetWorkouts: goal,
            updatedAt: homeNow,
            isSynced: true,
          ),
          saveWeeklyGoal: (targetWorkouts) async {
            goal = targetWorkouts;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-edit-goal-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('home-goal-target-input')),
      '5',
    );
    await tester.tap(find.byKey(const Key('home-goal-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('2 / 5 sessions completed'), findsOneWidget);
    expect(find.text('3 left'), findsOneWidget);
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

DailyChallengeBundle _bundleFor(String dateKey) {
  final startedAt = DateTime(2026, 3, 29, 10, 0);
  final challenge = DailyChallenge(
    dateKey: dateKey,
    status: DailyChallengeStatus.inProgress,
    skipCount: 0,
    totalSteps: 1,
    startedAt: startedAt,
    completedAt: null,
    updatedAt: startedAt,
    sequence: const <String>['Tree'],
  );
  final steps = <DailyChallengeStep>[
    DailyChallengeStep(
      dateKey: dateKey,
      stepIndex: 0,
      poseName: 'Tree',
      status: DailyChallengeStepStatus.pending,
      bestScore: null,
      holdDuration: null,
      updatedAt: startedAt,
    ),
  ];
  return DailyChallengeBundle(challenge: challenge, steps: steps);
}
