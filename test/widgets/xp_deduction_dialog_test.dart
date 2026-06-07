import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zenpose/models/punishment_models.dart';
import 'package:zenpose/models/user_rank.dart';
import 'package:zenpose/theme/zen_theme.dart';
import 'package:zenpose/widgets/xp_deduction_dialog.dart';

void main() {
  testWidgets('shows deduction breakdown and rank-drop state', (tester) async {
    await _pumpDialog(
      tester,
      result: const PunishmentEvaluationResult(
        applied: true,
        xpDeducted: 24,
        xpBefore: 3020,
        xpAfter: 2996,
        rankBefore: UserRankTier.gold,
        rankAfter: UserRankTier.silver,
        didRankDown: true,
        breakdown: <PenaltyBreakdownItem>[
          PenaltyBreakdownItem(
            reason: PenaltyReason.practicePoorPerformance,
            xpDeducted: 12,
            dateKey: '2026-05-09',
            sourceKey: 'practice:1',
          ),
          PenaltyBreakdownItem(
            reason: PenaltyReason.lowScoreFailures,
            xpDeducted: 12,
            dateKey: '2026-05-09',
            sourceKey: 'daily_threshold',
          ),
        ],
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('XP Deducted'), findsOneWidget);
    expect(find.text('-24 XP'), findsOneWidget);
    expect(find.text('Rank Dropped'), findsOneWidget);
    expect(find.text('Poor Practice: -12'), findsOneWidget);
    expect(find.text('Low Score Failures: -12'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('summarizes repeated penalty reasons', (tester) async {
    await _pumpDialog(
      tester,
      result: const PunishmentEvaluationResult(
        applied: true,
        xpDeducted: 106,
        xpBefore: 13489,
        xpAfter: 13383,
        rankBefore: UserRankTier.gold,
        rankAfter: UserRankTier.gold,
        didRankDown: false,
        breakdown: <PenaltyBreakdownItem>[
          PenaltyBreakdownItem(
            reason: PenaltyReason.missedDay,
            xpDeducted: 22,
            dateKey: '2026-05-10',
            sourceKey: 'auto',
          ),
          PenaltyBreakdownItem(
            reason: PenaltyReason.challengeAbandon,
            xpDeducted: 31,
            dateKey: '2026-05-10',
            sourceKey: 'daily_challenge',
          ),
          PenaltyBreakdownItem(
            reason: PenaltyReason.missedDay,
            xpDeducted: 22,
            dateKey: '2026-05-11',
            sourceKey: 'auto',
          ),
          PenaltyBreakdownItem(
            reason: PenaltyReason.challengeAbandon,
            xpDeducted: 31,
            dateKey: '2026-05-11',
            sourceKey: 'daily_challenge',
          ),
        ],
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('-106 XP'), findsOneWidget);
    expect(find.text('Missed Days x2: -44'), findsOneWidget);
    expect(find.text('Challenges Abandoned x2: -62'), findsOneWidget);
    expect(find.text('2026-05-10 to 2026-05-11'), findsNWidgets(2));
    expect(find.text('Missed Day: -22'), findsNothing);
    expect(find.text('Challenge Abandon: -31'), findsNothing);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required PunishmentEvaluationResult result,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ZenTheme.build(),
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  XpDeductionDialog.showIfNeeded(context, result: result);
                },
                child: const Text('open'),
              ),
            ),
          );
        },
      ),
    ),
  );
}
