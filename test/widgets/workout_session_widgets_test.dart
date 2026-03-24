import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/models/unlocked_badge.dart';
import 'package:zenpose/models/workout_guidance_snapshot.dart';
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
    });
  });

  group('WorkoutFeedbackPanel', () {
    testWidgets('renders primary cue before secondary cue', (tester) async {
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

      final primary = find.text('Primary correction');
      final secondary = find.text('Secondary hint');
      expect(primary, findsOneWidget);
      expect(secondary, findsOneWidget);
      expect(
        tester.getTopLeft(primary).dy,
        lessThan(tester.getTopLeft(secondary).dy),
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
