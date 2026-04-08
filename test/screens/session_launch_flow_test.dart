import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/constants/session_launch_config.dart';
import 'package:zenpose/models/daily_challenge.dart';
import 'package:zenpose/models/daily_challenge_step.dart';
import 'package:zenpose/models/pose_template.dart';
import 'package:zenpose/screens/daily_challenge_runner_screen.dart';
import 'package:zenpose/screens/pose_detail_screen.dart';
import 'package:zenpose/services/daily_challenge_service.dart';
import 'package:zenpose/widgets/pose_thumbnail_image.dart';
import 'package:zenpose/widgets/pre_session_countdown_widgets.dart';

class _FakeDailyChallengeService extends DailyChallengeService {
  DailyChallengeBundle bundle;
  final List<PoseTemplate> templates;
  int reorderCalls = 0;

  _FakeDailyChallengeService({required this.bundle, required this.templates});

  @override
  Future<DailyChallengeBundle> getOrCreateChallenge({
    required String dateKey,
  }) async {
    return bundle;
  }

  @override
  Future<List<PoseTemplate>> loadPoseTemplates() async {
    return templates;
  }

  @override
  Future<DailyChallengeBundle> reorderSteps({
    required String dateKey,
    required List<DailyChallengeStep> orderedSteps,
  }) async {
    reorderCalls += 1;
    final now = DateTime(2026, 3, 24, 11, 0, reorderCalls);
    final reindexed = <DailyChallengeStep>[
      for (var i = 0; i < orderedSteps.length; i++)
        DailyChallengeStep(
          dateKey: dateKey,
          stepIndex: i,
          poseName: orderedSteps[i].poseName,
          status: orderedSteps[i].status,
          bestScore: orderedSteps[i].bestScore,
          holdDuration: orderedSteps[i].holdDuration,
          updatedAt: now,
        ),
    ];
    bundle = DailyChallengeBundle(
      challenge: bundle.challenge.copyWith(
        sequence: reindexed
            .map((step) => step.poseName)
            .toList(growable: false),
        updatedAt: now,
      ),
      steps: reindexed,
    );
    return bundle;
  }
}

PoseTemplate _template() {
  return PoseTemplate(
    templateKey: 'downdog',
    name: 'Downdog',
    meanVector: List<double>.filled(24, 0.0),
    description: 'Test pose',
  );
}

void main() {
  testWidgets('daily challenge starts workout flow only after tapping Start', (
    tester,
  ) async {
    final now = DateTime(2026, 3, 24, 10, 0, 0);
    final challenge = DailyChallenge(
      dateKey: '2026-03-24',
      status: DailyChallengeStatus.inProgress,
      skipCount: 0,
      totalSteps: 1,
      targetHoldSeconds: 20,
      startedAt: now,
      completedAt: null,
      updatedAt: now,
      sequence: const <String>['Downdog'],
    );
    final step = DailyChallengeStep(
      dateKey: '2026-03-24',
      stepIndex: 0,
      poseName: 'Downdog',
      status: DailyChallengeStepStatus.pending,
      bestScore: null,
      holdDuration: null,
      updatedAt: now,
    );
    final service = _FakeDailyChallengeService(
      bundle: DailyChallengeBundle(challenge: challenge, steps: [step]),
      templates: [_template()],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DailyChallengeRunnerScreen(
          dateKey: '2026-03-24',
          challengeService: service,
          evaluatorBuilder: (_) =>
              const Scaffold(body: Center(child: Text('EVALUATOR_STUB'))),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Get Ready'), findsNothing);
    expect(find.text('00:20'), findsOneWidget);
    expect(find.byType(PoseThumbnailImage), findsWidgets);
    expect(find.byType(PoseDemoAnimation), findsNothing);

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.text('Get Ready'), findsOneWidget);

    await tester.pump(
      Duration(seconds: SessionLaunchConfig.preSessionCountdownSeconds),
    );
    await tester.pumpAndSettle();

    expect(find.text('EVALUATOR_STUB'), findsOneWidget);
  });

  testWidgets(
    'daily challenge disables Start when no pending steps even if status is in progress',
    (tester) async {
      final now = DateTime(2026, 3, 24, 10, 0, 0);
      final challenge = DailyChallenge(
        dateKey: '2026-03-24',
        status: DailyChallengeStatus.inProgress,
        skipCount: 0,
        totalSteps: 1,
        startedAt: now,
        completedAt: null,
        updatedAt: now,
        sequence: const <String>['Downdog'],
      );
      final step = DailyChallengeStep(
        dateKey: '2026-03-24',
        stepIndex: 0,
        poseName: 'Downdog',
        status: DailyChallengeStepStatus.completed,
        bestScore: 80,
        holdDuration: 45,
        updatedAt: now,
      );
      final service = _FakeDailyChallengeService(
        bundle: DailyChallengeBundle(challenge: challenge, steps: [step]),
        templates: [_template()],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DailyChallengeRunnerScreen(
            dateKey: '2026-03-24',
            challengeService: service,
            evaluatorBuilder: (_) =>
                const Scaffold(body: Center(child: Text('EVALUATOR_STUB'))),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      expect(find.text('EVALUATOR_STUB'), findsNothing);
    },
  );

  testWidgets(
    'daily challenge supports long-press reordering from drag handle',
    (tester) async {
      final now = DateTime(2026, 3, 24, 10, 0, 0);
      final challenge = DailyChallenge(
        dateKey: '2026-03-24',
        status: DailyChallengeStatus.inProgress,
        skipCount: 0,
        totalSteps: 2,
        targetHoldSeconds: 20,
        startedAt: now,
        completedAt: null,
        updatedAt: now,
        sequence: const <String>['Downdog', 'Tree'],
      );
      final steps = <DailyChallengeStep>[
        DailyChallengeStep(
          dateKey: '2026-03-24',
          stepIndex: 0,
          poseName: 'Downdog',
          status: DailyChallengeStepStatus.pending,
          bestScore: null,
          holdDuration: null,
          updatedAt: now,
        ),
        DailyChallengeStep(
          dateKey: '2026-03-24',
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
        templates: [_template()],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DailyChallengeRunnerScreen(
            dateKey: '2026-03-24',
            challengeService: service,
            evaluatorBuilder: (_) =>
                const Scaffold(body: Center(child: Text('EVALUATOR_STUB'))),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(service.bundle.challenge.sequence, const <String>[
        'Downdog',
        'Tree',
      ]);

      final handles = find.byIcon(Icons.drag_indicator_rounded);
      expect(handles, findsNWidgets(2));

      final gesture = await tester.startGesture(
        tester.getCenter(handles.first),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(0, 220));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(service.reorderCalls, 1);
      expect(service.bundle.challenge.sequence, const <String>[
        'Tree',
        'Downdog',
      ]);
    },
  );

  testWidgets('practice start routes through intro before opening session', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PoseDetailScreen(
          template: _template(),
          sessionScreenBuilder: (_) =>
              const Scaffold(body: Center(child: Text('PRACTICE_STUB'))),
        ),
      ),
    );

    expect(find.byType(PoseThumbnailImage), findsOneWidget);
    expect(find.byType(PoseDemoAnimation), findsNothing);

    await tester.tap(find.text('Start Practice'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Get Ready'), findsOneWidget);
    expect(find.byType(PoseDemoAnimation), findsOneWidget);
    expect(find.text('PRACTICE_STUB'), findsNothing);

    await tester.pump(
      Duration(seconds: SessionLaunchConfig.preSessionCountdownSeconds),
    );
    await tester.pumpAndSettle();

    expect(find.text('PRACTICE_STUB'), findsOneWidget);
  });
}
