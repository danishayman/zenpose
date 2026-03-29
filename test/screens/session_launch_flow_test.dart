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
  final DailyChallengeBundle bundle;
  final List<PoseTemplate> templates;

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
