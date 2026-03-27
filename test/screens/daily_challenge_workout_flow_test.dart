import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/constants/session_launch_config.dart';
import 'package:zenpose/models/challenge_step_result.dart';
import 'package:zenpose/models/daily_challenge.dart';
import 'package:zenpose/models/daily_challenge_step.dart';
import 'package:zenpose/models/pose_template.dart';
import 'package:zenpose/models/unlocked_badge.dart';
import 'package:zenpose/screens/daily_challenge_workout_flow_screen.dart';
import 'package:zenpose/services/daily_challenge_service.dart';

class _FakeDailyChallengeService extends DailyChallengeService {
  DailyChallengeBundle _bundle;
  final List<PoseTemplate> templates;
  final List<bool> overwriteFlags = <bool>[];
  bool throwOnCompleteTimedStep = false;
  int saveSummaryCalls = 0;
  String? savedFeedback;

  _FakeDailyChallengeService({required DailyChallengeBundle bundle, required this.templates})
      : _bundle = bundle;

  @override
  Future<DailyChallengeBundle> getOrCreateChallenge({
    required String dateKey,
  }) async {
    return _bundle;
  }

  @override
  Future<List<PoseTemplate>> loadPoseTemplates() async => templates;

  @override
  Future<DailyChallengeStepProcessResult> completeTimedStep({
    required String dateKey,
    required int stepIndex,
    required ChallengeStepResult stepResult,
    bool allowOverwrite = false,
  }) async {
    if (throwOnCompleteTimedStep) {
      throw StateError('forced failure');
    }
    overwriteFlags.add(allowOverwrite);
    final now = DateTime(2026, 3, 27, 12, 0, overwriteFlags.length);
    final updatedSteps = _bundle.steps.map((step) {
      if (step.stepIndex != stepIndex) return step;
      return step.copyWith(
        status: DailyChallengeStepStatus.completed,
        bestScore: stepResult.bestScore,
        holdDuration: stepResult.holdDuration,
        updatedAt: now,
      );
    }).toList(growable: false);
    final pending = updatedSteps
        .where((s) => s.status == DailyChallengeStepStatus.pending)
        .length;
    final challenge = _bundle.challenge.copyWith(
      status: pending == 0
          ? DailyChallengeStatus.completed
          : DailyChallengeStatus.inProgress,
      completedAt: pending == 0 ? now : null,
      updatedAt: now,
    );
    _bundle = DailyChallengeBundle(challenge: challenge, steps: updatedSteps);
    return DailyChallengeStepProcessResult(
      bundle: _bundle,
      xpGained: allowOverwrite ? 0 : 10,
      unlockedBadges: const <UnlockedBadge>[],
      applied: true,
    );
  }

  @override
  Future<DailyChallengeBundle> saveSessionSummary({
    required String dateKey,
    required Duration elapsed,
    required String? feedback,
  }) async {
    saveSummaryCalls += 1;
    if (feedback != null) {
      savedFeedback = feedback;
    }
    _bundle = DailyChallengeBundle(
      challenge: _bundle.challenge.copyWith(
        sessionAvgScore: 65.0,
        sessionCalories: 7.2,
        sessionElapsedSeconds: elapsed.inSeconds,
        sessionFeedback: feedback ?? _bundle.challenge.sessionFeedback,
      ),
      steps: _bundle.steps,
    );
    return _bundle;
  }
}

PoseTemplate _template(String key, String name) {
  return PoseTemplate(
    templateKey: key,
    name: name,
    meanVector: List<double>.filled(24, 0),
    description: '$name description',
  );
}

class _EvaluatorStub extends StatelessWidget {
  final ChallengeStepNavigationAction action;

  const _EvaluatorStub({required this.action});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(
              ChallengeStepResult(
                poseName: 'Stub',
                bestScore: 65,
                holdDuration: 45,
                passed: true,
                completedAt: DateTime(2026, 3, 27, 12, 0, 0),
                action: action,
              ),
            );
          },
          child: Text(action.name.toUpperCase()),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('flow transitions ready -> exercise -> rest and skip launches next exercise immediately', (
    tester,
  ) async {
    final now = DateTime(2026, 3, 27, 10, 0, 0);
    final challenge = DailyChallenge(
      dateKey: '2026-03-27',
      status: DailyChallengeStatus.inProgress,
      skipCount: 0,
      totalSteps: 2,
      startedAt: now,
      completedAt: null,
      updatedAt: now,
      sequence: const <String>['Downdog', 'Tree'],
    );
    final steps = <DailyChallengeStep>[
      DailyChallengeStep(
        dateKey: '2026-03-27',
        stepIndex: 0,
        poseName: 'Downdog',
        status: DailyChallengeStepStatus.pending,
        bestScore: null,
        holdDuration: null,
        updatedAt: now,
      ),
      DailyChallengeStep(
        dateKey: '2026-03-27',
        stepIndex: 1,
        poseName: 'Tree',
        status: DailyChallengeStepStatus.pending,
        bestScore: null,
        holdDuration: null,
        updatedAt: now,
      ),
    ];
    final service = _FakeDailyChallengeService(
      bundle: DailyChallengeBundle(challenge: challenge, steps: steps),
      templates: <PoseTemplate>[
        _template('downdog', 'Downdog'),
        _template('tree', 'Tree'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DailyChallengeWorkoutFlowScreen(
          dateKey: '2026-03-27',
          challengeService: service,
          evaluatorBuilder: (_) =>
              const _EvaluatorStub(action: ChallengeStepNavigationAction.completed),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    expect(find.text('Get Ready'), findsOneWidget);

    await tester.pump(
      Duration(seconds: SessionLaunchConfig.preSessionCountdownSeconds),
    );
    await tester.pumpAndSettle();
    expect(find.text('COMPLETED'), findsOneWidget);

    await tester.tap(find.text('COMPLETED'));
    await tester.pumpAndSettle();

    expect(find.text('REST'), findsOneWidget);
    expect(find.text('00:30'), findsOneWidget);

    await tester.ensureVisible(find.text('+20s'));
    await tester.tap(find.text('+20s'));
    await tester.pump();
    expect(find.text('00:50'), findsOneWidget);

    await tester.ensureVisible(find.text('Skip'));
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('COMPLETED'), findsOneWidget);
  });

  testWidgets('rest timer ending auto-launches next exercise', (tester) async {
    final now = DateTime(2026, 3, 27, 10, 0, 0);
    final challenge = DailyChallenge(
      dateKey: '2026-03-27',
      status: DailyChallengeStatus.inProgress,
      skipCount: 0,
      totalSteps: 2,
      startedAt: now,
      completedAt: null,
      updatedAt: now,
      sequence: const <String>['Downdog', 'Tree'],
    );
    final steps = <DailyChallengeStep>[
      DailyChallengeStep(
        dateKey: '2026-03-27',
        stepIndex: 0,
        poseName: 'Downdog',
        status: DailyChallengeStepStatus.pending,
        bestScore: null,
        holdDuration: null,
        updatedAt: now,
      ),
      DailyChallengeStep(
        dateKey: '2026-03-27',
        stepIndex: 1,
        poseName: 'Tree',
        status: DailyChallengeStepStatus.pending,
        bestScore: null,
        holdDuration: null,
        updatedAt: now,
      ),
    ];
    final service = _FakeDailyChallengeService(
      bundle: DailyChallengeBundle(challenge: challenge, steps: steps),
      templates: <PoseTemplate>[
        _template('downdog', 'Downdog'),
        _template('tree', 'Tree'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DailyChallengeWorkoutFlowScreen(
          dateKey: '2026-03-27',
          challengeService: service,
          evaluatorBuilder: (_) =>
              const _EvaluatorStub(action: ChallengeStepNavigationAction.completed),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pump(
      Duration(seconds: SessionLaunchConfig.preSessionCountdownSeconds),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('COMPLETED'));
    await tester.pumpAndSettle();
    expect(find.text('REST'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('COMPLETED'), findsOneWidget);
  });

  testWidgets('skip-through-all using next reaches completion without looping', (
    tester,
  ) async {
    final now = DateTime(2026, 3, 27, 10, 0, 0);
    final challenge = DailyChallenge(
      dateKey: '2026-03-27',
      status: DailyChallengeStatus.inProgress,
      skipCount: 0,
      totalSteps: 3,
      startedAt: now,
      completedAt: null,
      updatedAt: now,
      sequence: const <String>['Downdog', 'Tree', 'Goddess'],
    );
    final steps = <DailyChallengeStep>[
      DailyChallengeStep(
        dateKey: '2026-03-27',
        stepIndex: 0,
        poseName: 'Downdog',
        status: DailyChallengeStepStatus.pending,
        bestScore: null,
        holdDuration: null,
        updatedAt: now,
      ),
      DailyChallengeStep(
        dateKey: '2026-03-27',
        stepIndex: 1,
        poseName: 'Tree',
        status: DailyChallengeStepStatus.pending,
        bestScore: null,
        holdDuration: null,
        updatedAt: now,
      ),
      DailyChallengeStep(
        dateKey: '2026-03-27',
        stepIndex: 2,
        poseName: 'Goddess',
        status: DailyChallengeStepStatus.pending,
        bestScore: null,
        holdDuration: null,
        updatedAt: now,
      ),
    ];
    final service = _FakeDailyChallengeService(
      bundle: DailyChallengeBundle(challenge: challenge, steps: steps),
      templates: <PoseTemplate>[
        _template('downdog', 'Downdog'),
        _template('tree', 'Tree'),
        _template('goddess', 'Goddess'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DailyChallengeWorkoutFlowScreen(
          dateKey: '2026-03-27',
          challengeService: service,
          evaluatorBuilder: (_) =>
              const _EvaluatorStub(action: ChallengeStepNavigationAction.next),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    await tester.pump(
      Duration(seconds: SessionLaunchConfig.preSessionCountdownSeconds),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('REST'), findsOneWidget);
    await tester.ensureVisible(find.text('Skip'));
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('REST'), findsOneWidget);
    await tester.ensureVisible(find.text('Skip'));
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();

    expect(find.text('Great session completed!'), findsOneWidget);
    expect(find.text('REST'), findsNothing);
    expect(find.text('Get Ready'), findsNothing);
  });

  testWidgets('previous action rewinds and next completion overwrites previous step', (
    tester,
  ) async {
    final now = DateTime(2026, 3, 27, 10, 0, 0);
    final challenge = DailyChallenge(
      dateKey: '2026-03-27',
      status: DailyChallengeStatus.inProgress,
      skipCount: 0,
      totalSteps: 2,
      startedAt: now,
      completedAt: null,
      updatedAt: now,
      sequence: const <String>['Downdog', 'Tree'],
    );
    final steps = <DailyChallengeStep>[
      DailyChallengeStep(
        dateKey: '2026-03-27',
        stepIndex: 0,
        poseName: 'Downdog',
        status: DailyChallengeStepStatus.completed,
        bestScore: 80,
        holdDuration: 45,
        updatedAt: now,
      ),
      DailyChallengeStep(
        dateKey: '2026-03-27',
        stepIndex: 1,
        poseName: 'Tree',
        status: DailyChallengeStepStatus.pending,
        bestScore: null,
        holdDuration: null,
        updatedAt: now,
      ),
    ];
    final service = _FakeDailyChallengeService(
      bundle: DailyChallengeBundle(challenge: challenge, steps: steps),
      templates: <PoseTemplate>[
        _template('downdog', 'Downdog'),
        _template('tree', 'Tree'),
      ],
    );

    var launchCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DailyChallengeWorkoutFlowScreen(
          dateKey: '2026-03-27',
          challengeService: service,
          evaluatorBuilder: (_) {
            final action = launchCount == 0
                ? ChallengeStepNavigationAction.previous
                : ChallengeStepNavigationAction.completed;
            launchCount += 1;
            return _EvaluatorStub(action: action);
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    expect(find.textContaining('EXERCISE 2/2'), findsOneWidget);

    await tester.pump(
      Duration(seconds: SessionLaunchConfig.preSessionCountdownSeconds),
    );
    await tester.pumpAndSettle();
    expect(find.text('PREVIOUS'), findsOneWidget);
    await tester.tap(find.text('PREVIOUS'));
    await tester.pumpAndSettle();

    expect(find.textContaining('EXERCISE 1/2'), findsOneWidget);

    await tester.pump(
      Duration(seconds: SessionLaunchConfig.preSessionCountdownSeconds),
    );
    await tester.pumpAndSettle();
    expect(find.text('COMPLETED'), findsOneWidget);
    await tester.tap(find.text('COMPLETED'));
    await tester.pumpAndSettle();

    expect(service.overwriteFlags, isNotEmpty);
    expect(service.overwriteFlags.last, isTrue);
  });

  testWidgets('final step opens completion screen and persists feedback on finish', (
    tester,
  ) async {
    final now = DateTime(2026, 3, 27, 10, 0, 0);
    final challenge = DailyChallenge(
      dateKey: '2026-03-27',
      status: DailyChallengeStatus.inProgress,
      skipCount: 0,
      totalSteps: 1,
      startedAt: now,
      completedAt: null,
      updatedAt: now,
      sequence: const <String>['Downdog'],
    );
    final steps = <DailyChallengeStep>[
      DailyChallengeStep(
        dateKey: '2026-03-27',
        stepIndex: 0,
        poseName: 'Downdog',
        status: DailyChallengeStepStatus.pending,
        bestScore: null,
        holdDuration: null,
        updatedAt: now,
      ),
    ];
    final service = _FakeDailyChallengeService(
      bundle: DailyChallengeBundle(challenge: challenge, steps: steps),
      templates: <PoseTemplate>[_template('downdog', 'Downdog')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DailyChallengeWorkoutFlowScreen(
          dateKey: '2026-03-27',
          challengeService: service,
          evaluatorBuilder: (_) =>
              const _EvaluatorStub(action: ChallengeStepNavigationAction.completed),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pump(
      Duration(seconds: SessionLaunchConfig.preSessionCountdownSeconds),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('COMPLETED'));
    await tester.pumpAndSettle();

    expect(find.text('Great session completed!'), findsOneWidget);
    expect(service.saveSummaryCalls, greaterThanOrEqualTo(1));

    await tester.tap(find.text('Too easy'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Back to Home'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Back to Home'));
    await tester.pumpAndSettle();

    expect(service.savedFeedback, equals('too_easy'));
    expect(find.text('Great session completed!'), findsNothing);
  });

  testWidgets(
    'no pending steps at launch routes directly to completion screen',
    (tester) async {
      final now = DateTime(2026, 3, 27, 10, 0, 0);
      final challenge = DailyChallenge(
        dateKey: '2026-03-27',
        status: DailyChallengeStatus.inProgress,
        skipCount: 0,
        totalSteps: 1,
        startedAt: now,
        completedAt: null,
        updatedAt: now,
        sequence: const <String>['Downdog'],
      );
      final steps = <DailyChallengeStep>[
        DailyChallengeStep(
          dateKey: '2026-03-27',
          stepIndex: 0,
          poseName: 'Downdog',
          status: DailyChallengeStepStatus.completed,
          bestScore: 72,
          holdDuration: 45,
          updatedAt: now,
        ),
      ];
      final service = _FakeDailyChallengeService(
        bundle: DailyChallengeBundle(challenge: challenge, steps: steps),
        templates: <PoseTemplate>[_template('downdog', 'Downdog')],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DailyChallengeWorkoutFlowScreen(
            dateKey: '2026-03-27',
            challengeService: service,
            evaluatorBuilder: (_) =>
                const _EvaluatorStub(action: ChallengeStepNavigationAction.next),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Great session completed!'), findsOneWidget);
      expect(find.text('REST'), findsNothing);
    },
  );

  testWidgets('save failure does not leave infinite loading state', (tester) async {
    final now = DateTime(2026, 3, 27, 10, 0, 0);
    final challenge = DailyChallenge(
      dateKey: '2026-03-27',
      status: DailyChallengeStatus.inProgress,
      skipCount: 0,
      totalSteps: 1,
      startedAt: now,
      completedAt: null,
      updatedAt: now,
      sequence: const <String>['Downdog'],
    );
    final steps = <DailyChallengeStep>[
      DailyChallengeStep(
        dateKey: '2026-03-27',
        stepIndex: 0,
        poseName: 'Downdog',
        status: DailyChallengeStepStatus.pending,
        bestScore: null,
        holdDuration: null,
        updatedAt: now,
      ),
    ];
    final service = _FakeDailyChallengeService(
      bundle: DailyChallengeBundle(challenge: challenge, steps: steps),
      templates: <PoseTemplate>[_template('downdog', 'Downdog')],
    )..throwOnCompleteTimedStep = true;

    await tester.pumpWidget(
      MaterialApp(
        home: DailyChallengeWorkoutFlowScreen(
          dateKey: '2026-03-27',
          challengeService: service,
          evaluatorBuilder: (_) =>
              const _EvaluatorStub(action: ChallengeStepNavigationAction.completed),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pump(
      Duration(seconds: SessionLaunchConfig.preSessionCountdownSeconds),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('COMPLETED'));
    await tester.pumpAndSettle();

    expect(find.text('Get Ready'), findsOneWidget);
    expect(find.text('Great session completed!'), findsNothing);
  });
}
