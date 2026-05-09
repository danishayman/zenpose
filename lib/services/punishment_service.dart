import '../models/pose_result.dart';
import '../models/punishment_models.dart';
import '../services/user_rank_service.dart';
import 'database_service.dart';

class PunishmentService {
  final DatabaseService _databaseService;

  PunishmentService({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService.instance;

  static const int missedDayBasePenalty = 10;
  static const int challengeAbandonBasePenalty = 14;
  static const int lowScoreFailuresThresholdPenalty = 10;

  static const int poorPracticeAttempt1Penalty = 8;
  static const int poorPracticeAttempt2Penalty = 12;
  static const int poorPracticeAttempt3PlusPenalty = 16;

  Future<PunishmentEvaluationResult> evaluate({
    required PenaltyApplicationTrigger trigger,
    DateTime? now,
    PoseResult? practiceResult,
    double? qualityGateScore,
  }) async {
    final anchor = now ?? DateTime.now();
    final initialStats = await _databaseService.getUserStats();
    final xpBefore = initialStats.totalXp;
    final rankBefore = UserRankService.rankForXp(xpBefore);
    final breakdown = <PenaltyBreakdownItem>[];

    if (trigger == PenaltyApplicationTrigger.appOpen ||
        trigger == PenaltyApplicationTrigger.postSession) {
      await _applyInactivityPenalties(anchor: anchor, breakdown: breakdown);
    }

    if (practiceResult != null) {
      await _applyPracticePoorPerformancePenalty(
        result: practiceResult,
        qualityGateScore: qualityGateScore,
        breakdown: breakdown,
      );
    }

    final updatedStats = await _databaseService.getUserStats();
    final xpAfter = updatedStats.totalXp;
    final rankAfter = UserRankService.rankForXp(xpAfter);
    final totalDeducted = xpBefore - xpAfter;

    return PunishmentEvaluationResult(
      applied: totalDeducted > 0,
      xpDeducted: totalDeducted > 0 ? totalDeducted : 0,
      xpBefore: xpBefore,
      xpAfter: xpAfter,
      rankBefore: rankBefore,
      rankAfter: rankAfter,
      didRankDown: UserRankService.didRankDown(
        previousRank: rankBefore,
        currentRank: rankAfter,
      ),
      breakdown: List<PenaltyBreakdownItem>.unmodifiable(breakdown),
    );
  }

  Future<void> _applyInactivityPenalties({
    required DateTime anchor,
    required List<PenaltyBreakdownItem> breakdown,
  }) async {
    final stats = await _databaseService.getUserStats();
    final lastActiveDate = stats.lastActiveDate;
    if (lastActiveDate == null) return;

    final today = DateTime(anchor.year, anchor.month, anchor.day);
    final lastActive = DateTime(
      lastActiveDate.year,
      lastActiveDate.month,
      lastActiveDate.day,
    );
    final missedDays = today.difference(lastActive).inDays - 1;
    if (missedDays <= 0) return;

    for (var dayOffset = 1; dayOffset <= missedDays; dayOffset++) {
      final missedDate = lastActive.add(Duration(days: dayOffset));
      final dateKey = _dateKey(missedDate);
      await _applyPenaltyIfNeeded(
        dateKey: dateKey,
        reason: PenaltyReason.missedDay,
        sourceKey: 'auto',
        basePenalty: missedDayBasePenalty,
        breakdown: breakdown,
      );

      final challenge = await _databaseService
          .getAnyIncompleteChallengeByDateKey(dateKey);
      if (challenge != null && challenge.startedAt != null) {
        await _applyPenaltyIfNeeded(
          dateKey: dateKey,
          reason: PenaltyReason.challengeAbandon,
          sourceKey: 'daily_challenge',
          basePenalty: challengeAbandonBasePenalty,
          breakdown: breakdown,
        );
      }
    }
  }

  Future<void> _applyPracticePoorPerformancePenalty({
    required PoseResult result,
    required double? qualityGateScore,
    required List<PenaltyBreakdownItem> breakdown,
  }) async {
    final gate = qualityGateScore ?? 70.0;
    if (result.bestScore >= gate) return;

    final at = result.timestamp ?? DateTime.now();
    final dateKey = _dateKey(at);
    final sourceKey = 'practice:${result.id ?? at.microsecondsSinceEpoch}';

    final alreadyApplied = await _databaseService.hasPenaltyLedgerEntry(
      dateKey: dateKey,
      reason: PenaltyReason.practicePoorPerformance,
      sourceKey: sourceKey,
    );
    final alreadyAppliedRepeated = await _databaseService.hasPenaltyLedgerEntry(
      dateKey: dateKey,
      reason: PenaltyReason.practiceRepeatedPoorPerformance,
      sourceKey: sourceKey,
    );
    if (alreadyApplied || alreadyAppliedRepeated) return;

    final attemptCount = await _databaseService.countPenaltyLedgerEntriesForDay(
      dateKey: dateKey,
      reasons: const <PenaltyReason>[
        PenaltyReason.practicePoorPerformance,
        PenaltyReason.practiceRepeatedPoorPerformance,
      ],
    );
    final attemptNumber = attemptCount + 1;
    final basePenalty = switch (attemptNumber) {
      1 => poorPracticeAttempt1Penalty,
      2 => poorPracticeAttempt2Penalty,
      _ => poorPracticeAttempt3PlusPenalty,
    };
    final reason = attemptNumber >= 3
        ? PenaltyReason.practiceRepeatedPoorPerformance
        : PenaltyReason.practicePoorPerformance;

    await _applyPenaltyIfNeeded(
      dateKey: dateKey,
      reason: reason,
      sourceKey: sourceKey,
      basePenalty: basePenalty,
      breakdown: breakdown,
    );

    if (attemptNumber == 3) {
      await _applyPenaltyIfNeeded(
        dateKey: dateKey,
        reason: PenaltyReason.lowScoreFailures,
        sourceKey: 'daily_threshold',
        basePenalty: lowScoreFailuresThresholdPenalty,
        breakdown: breakdown,
      );
    }
  }

  Future<void> _applyPenaltyIfNeeded({
    required String dateKey,
    required PenaltyReason reason,
    required String sourceKey,
    required int basePenalty,
    required List<PenaltyBreakdownItem> breakdown,
  }) async {
    if (basePenalty <= 0) return;
    final exists = await _databaseService.hasPenaltyLedgerEntry(
      dateKey: dateKey,
      reason: reason,
      sourceKey: sourceKey,
    );
    if (exists) return;

    final statsBefore = await _databaseService.getUserStats();
    final rankBefore = UserRankService.rankForXp(statsBefore.totalXp);
    final multiplier = UserRankService.penaltyMultiplierForRank(rankBefore);
    final plannedDeduction = (basePenalty * multiplier).round();
    if (plannedDeduction <= 0) return;

    final adjustment = await _databaseService.adjustTotalXp(-plannedDeduction);
    final actualDeducted = adjustment.xpBefore - adjustment.xpAfter;
    if (actualDeducted <= 0) {
      return;
    }

    await _databaseService.insertPenaltyLedgerEntry(
      dateKey: dateKey,
      reason: reason,
      sourceKey: sourceKey,
      xpDelta: -actualDeducted,
    );
    breakdown.add(
      PenaltyBreakdownItem(
        reason: reason,
        xpDeducted: actualDeducted,
        dateKey: dateKey,
        sourceKey: sourceKey,
      ),
    );
  }

  static String _dateKey(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
