import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/models/unlocked_badge.dart';
import 'package:zenpose/models/workout_guidance_snapshot.dart';
import 'package:zenpose/theme/zen_theme.dart';
import 'package:zenpose/widgets/workout_session_widgets.dart';

void main() {
  group('WorkoutStatusHud', () {
    testWidgets('shows explicit status text for no-user-detected state', (
      tester,
    ) async {
      const snapshot = WorkoutGuidanceSnapshot(
        score: 0,
        holdProgress: 0,
        state: WorkoutGuidanceState.noUserDetected,
        primaryCue: 'Step into frame',
        secondaryCue: null,
        shouldResetSession: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WorkoutStatusHud(
              snapshot: snapshot,
              holdSeconds: 0.0,
              durationSeconds: 45.0,
              scoreThreshold: 70.0,
            ),
          ),
        ),
      );

      expect(find.text('Step into frame'), findsOneWidget);
      final hudContainer = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(WorkoutStatusHud),
              matching: find.byType(Container),
            )
            .first,
      );
      final hudDecoration = hudContainer.decoration as BoxDecoration;
      expect(
        hudDecoration.color,
        equals(ZenColors.bark.withValues(alpha: 0.66)),
      );
    });

    testWidgets('uses display score/progress overrides when provided', (
      tester,
    ) async {
      const snapshot = WorkoutGuidanceSnapshot(
        score: 10,
        holdProgress: 0.1,
        state: WorkoutGuidanceState.aligning,
        primaryCue: null,
        secondaryCue: null,
        shouldResetSession: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WorkoutStatusHud(
              snapshot: snapshot,
              holdSeconds: 0.0,
              durationSeconds: 45.0,
              scoreThreshold: 70.0,
              displayScore: 66.0,
              displayProgress: 0.6,
            ),
          ),
        ),
      );

      expect(find.text('66%'), findsOneWidget);
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, closeTo(0.6, 0.0001));
    });
  });

  group('WorkoutFeedbackPanel', () {
    testWidgets('renders only primary cue in a fixed single slot', (
      tester,
    ) async {
      const snapshot = WorkoutGuidanceSnapshot(
        score: 72,
        holdProgress: 0.3,
        state: WorkoutGuidanceState.aligning,
        primaryCue: 'Primary correction',
        secondaryCue: 'Secondary hint',
        shouldResetSession: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WorkoutFeedbackPanel(snapshot: snapshot, visible: true),
          ),
        ),
      );

      expect(find.text('Primary correction'), findsOneWidget);
      expect(find.text('Secondary hint'), findsNothing);
      final guidanceContainer = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(WorkoutFeedbackPanel),
              matching: find.byType(Container),
            )
            .first,
      );
      final guidanceDecoration = guidanceContainer.decoration as BoxDecoration;
      expect(
        guidanceDecoration.color,
        equals(ZenColors.bark.withValues(alpha: 0.66)),
      );
      expect(
        tester.getSize(find.byType(WorkoutFeedbackPanel)).height,
        closeTo(92.0, 0.01),
      );
    });
  });

  group('WorkoutRewardSummary', () {
    testWidgets('shows XP and unlocked badge names', (tester) async {
      final badges = <UnlockedBadge>[
        UnlockedBadge(
          badgeId: 'first_completion',
          name: 'First Flow',
          description: 'Complete your first workout',
          unlockedAt: DateTime(2026, 3, 14, 12, 0, 0),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutRewardSummary(xpGained: 140, unlockedBadges: badges),
          ),
        ),
      );

      expect(find.text('XP +140'), findsOneWidget);
      expect(find.text('First Flow'), findsOneWidget);
    });
  });
}
