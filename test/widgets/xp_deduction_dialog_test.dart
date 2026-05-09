import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zenpose/models/punishment_models.dart';
import 'package:zenpose/models/user_rank.dart';
import 'package:zenpose/theme/zen_theme.dart';
import 'package:zenpose/widgets/xp_deduction_dialog.dart';

void main() {
  testWidgets('shows deduction breakdown and rank-drop state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ZenTheme.build(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    XpDeductionDialog.showIfNeeded(
                      context,
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
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
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
}
