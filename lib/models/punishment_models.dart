import 'user_rank.dart';

enum PenaltyApplicationTrigger { appOpen, postSession, practiceImmediate }

enum PenaltyReason {
  missedDay,
  challengeAbandon,
  practicePoorPerformance,
  practiceRepeatedPoorPerformance,
  lowScoreFailures,
}

extension PenaltyReasonX on PenaltyReason {
  String get dbValue {
    switch (this) {
      case PenaltyReason.missedDay:
        return 'missed_day';
      case PenaltyReason.challengeAbandon:
        return 'challenge_abandon';
      case PenaltyReason.practicePoorPerformance:
        return 'practice_poor_performance';
      case PenaltyReason.practiceRepeatedPoorPerformance:
        return 'practice_repeated_poor_performance';
      case PenaltyReason.lowScoreFailures:
        return 'low_score_failures';
    }
  }

  String get label {
    switch (this) {
      case PenaltyReason.missedDay:
        return 'Missed Day';
      case PenaltyReason.challengeAbandon:
        return 'Challenge Abandon';
      case PenaltyReason.practicePoorPerformance:
        return 'Poor Practice';
      case PenaltyReason.practiceRepeatedPoorPerformance:
        return 'Repeated Poor Practice';
      case PenaltyReason.lowScoreFailures:
        return 'Low Score Failures';
    }
  }

  static PenaltyReason fromDbValue(String raw) {
    switch (raw) {
      case 'missed_day':
        return PenaltyReason.missedDay;
      case 'challenge_abandon':
        return PenaltyReason.challengeAbandon;
      case 'practice_poor_performance':
        return PenaltyReason.practicePoorPerformance;
      case 'practice_repeated_poor_performance':
        return PenaltyReason.practiceRepeatedPoorPerformance;
      case 'low_score_failures':
      default:
        return PenaltyReason.lowScoreFailures;
    }
  }
}

class PenaltyBreakdownItem {
  final PenaltyReason reason;
  final int xpDeducted;
  final String dateKey;
  final String sourceKey;

  const PenaltyBreakdownItem({
    required this.reason,
    required this.xpDeducted,
    required this.dateKey,
    required this.sourceKey,
  });
}

class PunishmentEvaluationResult {
  final bool applied;
  final int xpDeducted;
  final int xpBefore;
  final int xpAfter;
  final UserRankTier rankBefore;
  final UserRankTier rankAfter;
  final bool didRankDown;
  final List<PenaltyBreakdownItem> breakdown;

  const PunishmentEvaluationResult({
    required this.applied,
    required this.xpDeducted,
    required this.xpBefore,
    required this.xpAfter,
    required this.rankBefore,
    required this.rankAfter,
    required this.didRankDown,
    required this.breakdown,
  });
}

class XpAdjustmentSnapshot {
  final int xpBefore;
  final int xpAfter;

  const XpAdjustmentSnapshot({required this.xpBefore, required this.xpAfter});
}
