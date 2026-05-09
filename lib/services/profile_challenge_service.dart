import 'dart:math';

import '../models/pose_result.dart';
import '../models/profile_challenge_models.dart';
import '../models/user_rank.dart';
import 'database_service.dart';
import 'user_rank_service.dart';

class ProfileChallengeService {
  final DatabaseService _databaseService;

  ProfileChallengeService({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService.instance;

  static const int monthlyChallengeCount = 6;

  static const List<_ChallengeTemplate> _templates = <_ChallengeTemplate>[
    _ChallengeTemplate(
      challengeId: 'sessions_20',
      metricType: ChallengeMetricType.sessions,
      targetValue: 20,
      scoreThreshold: null,
      rewardXp: 120,
      rewardBadgeLabel: 'Session Builder',
    ),
    _ChallengeTemplate(
      challengeId: 'sessions_40',
      metricType: ChallengeMetricType.sessions,
      targetValue: 40,
      scoreThreshold: null,
      rewardXp: 220,
      rewardBadgeLabel: 'Session Keeper',
    ),
    _ChallengeTemplate(
      challengeId: 'minutes_120',
      metricType: ChallengeMetricType.minutes,
      targetValue: 120,
      scoreThreshold: null,
      rewardXp: 140,
      rewardBadgeLabel: 'Flow Time 120',
    ),
    _ChallengeTemplate(
      challengeId: 'minutes_300',
      metricType: ChallengeMetricType.minutes,
      targetValue: 300,
      scoreThreshold: null,
      rewardXp: 260,
      rewardBadgeLabel: 'Flow Time 300',
    ),
    _ChallengeTemplate(
      challengeId: 'minutes_600',
      metricType: ChallengeMetricType.minutes,
      targetValue: 600,
      scoreThreshold: null,
      rewardXp: 380,
      rewardBadgeLabel: 'Flow Time 600',
    ),
    _ChallengeTemplate(
      challengeId: 'score_90_x5',
      metricType: ChallengeMetricType.scoreCount,
      targetValue: 5,
      scoreThreshold: 90,
      rewardXp: 180,
      rewardBadgeLabel: 'Precision 90 x5',
    ),
    _ChallengeTemplate(
      challengeId: 'score_90_x10',
      metricType: ChallengeMetricType.scoreCount,
      targetValue: 10,
      scoreThreshold: 90,
      rewardXp: 280,
      rewardBadgeLabel: 'Precision 90 x10',
    ),
    _ChallengeTemplate(
      challengeId: 'score_95_x3',
      metricType: ChallengeMetricType.scoreCount,
      targetValue: 3,
      scoreThreshold: 95,
      rewardXp: 220,
      rewardBadgeLabel: 'Alignment 95',
    ),
    _ChallengeTemplate(
      challengeId: 'score_95_x6',
      metricType: ChallengeMetricType.scoreCount,
      targetValue: 6,
      scoreThreshold: 95,
      rewardXp: 340,
      rewardBadgeLabel: 'Alignment 95 Master',
    ),
  ];

  Future<List<ChallengeProgressSnapshot>> loadMonthlyChallenges({
    DateTime? now,
    String? monthKey,
  }) async {
    final anchor = now ?? DateTime.now();
    final activeMonthKey = monthKey ?? monthKeyFromDate(anchor);
    final month = monthStartFromKey(activeMonthKey);
    final monthStart = month;
    final monthEnd = DateTime(month.year, month.month + 1, 1);
    final currentMonthStart = DateTime(anchor.year, anchor.month, 1);
    final isEndedMonth = monthStart.isBefore(currentMonthStart);

    final definitions = _buildDefinitionsForMonth(activeMonthKey);
    final states = await _databaseService.getProfileChallengeStatesForMonth(
      activeMonthKey,
    );
    final stateById = {for (final state in states) state.challengeId: state};
    final results = await _databaseService.getAllResults();
    final completedInMonth = _completedResultsForMonth(
      results: results,
      monthStart: monthStart,
      monthEnd: monthEnd,
    );

    final snapshots = definitions
        .map((definition) {
          final currentValue = _currentValueForMetric(
            definition: definition,
            results: completedInMonth,
          );
          final targetValue = definition.targetValue;
          final progressRatio = targetValue <= 0
              ? 1.0
              : (currentValue / targetValue).clamp(0.0, 1.0);
          final reachedTarget = currentValue >= targetValue;
          final state = stateById[definition.challengeId];
          final isJoined = state != null;

          final status = _resolveStatus(
            state: state,
            isJoined: isJoined,
            reachedTarget: reachedTarget,
            isEndedMonth: isEndedMonth,
          );

          return ChallengeProgressSnapshot(
            definition: definition,
            monthKey: activeMonthKey,
            status: status,
            isJoined: isJoined,
            currentValue: currentValue,
            targetValue: targetValue,
            progressRatio: progressRatio,
            progressLabel:
                '${_formatProgress(currentValue)} / ${_formatProgress(targetValue)}',
            periodLabel: monthPeriodLabel(activeMonthKey),
            buttonLabel: _buttonLabel(status),
            rewardBadgeLabel: state?.rewardBadgeLabel,
            rewardXp: definition.rewardXp,
          );
        })
        .toList(growable: false);

    snapshots.sort((a, b) {
      final rankA = _statusRank(a.status);
      final rankB = _statusRank(b.status);
      if (rankA != rankB) return rankA.compareTo(rankB);
      if (a.targetValue != b.targetValue) {
        return a.targetValue.compareTo(b.targetValue);
      }
      return a.definition.title.compareTo(b.definition.title);
    });

    return snapshots;
  }

  List<ChallengeProgressSnapshot> previewChallenges(
    List<ChallengeProgressSnapshot> snapshots, {
    int limit = 3,
  }) {
    if (limit <= 0) return const <ChallengeProgressSnapshot>[];
    return snapshots.take(limit).toList(growable: false);
  }

  Future<void> joinChallenge({
    required String monthKey,
    required String challengeId,
    DateTime? now,
  }) async {
    final existing = await _databaseService.getProfileChallengeState(
      monthKey: monthKey,
      challengeId: challengeId,
    );
    if (existing != null) return;

    final joinedAt = now ?? DateTime.now();
    await _databaseService.upsertProfileChallengeState(
      UserProfileChallengeState(
        userId: '',
        monthKey: monthKey,
        challengeId: challengeId,
        status: UserProfileChallengeStatus.joined,
        joinedAt: joinedAt,
        completedAt: null,
        claimedAt: null,
        rewardBadgeLabel: null,
        updatedAt: joinedAt,
        isSynced: false,
      ),
    );
  }

  Future<ChallengeClaimResult> claimChallengeReward({
    required String monthKey,
    required String challengeId,
    DateTime? now,
  }) async {
    final currentStats = await _databaseService.getUserStats();
    final xpBefore = currentStats.totalXp;
    final rankBefore = UserRankService.rankForXp(xpBefore);
    final snapshots = await loadMonthlyChallenges(now: now, monthKey: monthKey);
    ChallengeProgressSnapshot? snapshot;
    for (final item in snapshots) {
      if (item.definition.challengeId == challengeId) {
        snapshot = item;
        break;
      }
    }
    if (snapshot == null) {
      return const ChallengeClaimResult(
        applied: false,
        xpGranted: 0,
        xpBefore: 0,
        xpAfter: 0,
        rankBefore: UserRankTier.bronze,
        rankAfter: UserRankTier.bronze,
        didRankUp: false,
        badgeLabel: '',
        message: 'Challenge not found.',
      );
    }
    if (snapshot.status == ChallengeLifecycleStatus.completed) {
      return ChallengeClaimResult(
        applied: false,
        xpGranted: 0,
        xpBefore: xpBefore,
        xpAfter: xpBefore,
        rankBefore: rankBefore,
        rankAfter: rankBefore,
        didRankUp: false,
        badgeLabel: snapshot.definition.rewardBadgeLabel,
        message: 'Reward already claimed.',
      );
    }
    if (snapshot.status != ChallengeLifecycleStatus.claimable) {
      return ChallengeClaimResult(
        applied: false,
        xpGranted: 0,
        xpBefore: xpBefore,
        xpAfter: xpBefore,
        rankBefore: rankBefore,
        rankAfter: rankBefore,
        didRankUp: false,
        badgeLabel: snapshot.definition.rewardBadgeLabel,
        message: 'Challenge target not reached yet.',
      );
    }

    final existing = await _databaseService.getProfileChallengeState(
      monthKey: monthKey,
      challengeId: challengeId,
    );
    if (existing == null) {
      return ChallengeClaimResult(
        applied: false,
        xpGranted: 0,
        xpBefore: xpBefore,
        xpAfter: xpBefore,
        rankBefore: rankBefore,
        rankAfter: rankBefore,
        didRankUp: false,
        badgeLabel: snapshot.definition.rewardBadgeLabel,
        message: 'Join this challenge first.',
      );
    }
    if (existing.claimedAt != null) {
      return ChallengeClaimResult(
        applied: false,
        xpGranted: 0,
        xpBefore: xpBefore,
        xpAfter: xpBefore,
        rankBefore: rankBefore,
        rankAfter: rankBefore,
        didRankUp: false,
        badgeLabel: snapshot.definition.rewardBadgeLabel,
        message: 'Reward already claimed.',
      );
    }

    final claimedAt = now ?? DateTime.now();
    await _databaseService.incrementTotalXp(snapshot.definition.rewardXp);
    final updatedStats = await _databaseService.getUserStats();
    final xpAfter = updatedStats.totalXp;
    final rankAfter = UserRankService.rankForXp(xpAfter);
    final didRankUp = UserRankService.didRankUp(
      previousRank: rankBefore,
      currentRank: rankAfter,
    );
    await _databaseService.upsertProfileChallengeState(
      existing.copyWith(
        status: UserProfileChallengeStatus.completed,
        completedAt: claimedAt,
        claimedAt: claimedAt,
        rewardBadgeLabel: snapshot.definition.rewardBadgeLabel,
        updatedAt: claimedAt,
        isSynced: false,
      ),
    );

    return ChallengeClaimResult(
      applied: true,
      xpGranted: snapshot.definition.rewardXp,
      xpBefore: xpBefore,
      xpAfter: xpAfter,
      rankBefore: rankBefore,
      rankAfter: rankAfter,
      didRankUp: didRankUp,
      badgeLabel: snapshot.definition.rewardBadgeLabel,
      message: 'Claimed ${snapshot.definition.rewardBadgeLabel}',
    );
  }

  static String monthKeyFromDate(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$year-$month';
  }

  static DateTime monthStartFromKey(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return DateTime.now();
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;
    return DateTime(year, month, 1);
  }

  static String monthPeriodLabel(String monthKey) {
    final month = monthStartFromKey(monthKey);
    final end = DateTime(month.year, month.month + 1, 0);
    final monthLabel = _monthName(month.month);
    return '$monthLabel 1 to $monthLabel ${end.day}, ${month.year}';
  }

  List<ProfileChallengeDefinition> _buildDefinitionsForMonth(String monthKey) {
    final seed = monthKey.codeUnits.fold<int>(23, (acc, c) => (acc * 31) + c);
    final rng = Random(seed);
    final shuffled = List<_ChallengeTemplate>.from(_templates)..shuffle(rng);
    final month = monthStartFromKey(monthKey);
    final monthLabel = _monthName(month.month);

    return shuffled
        .take(monthlyChallengeCount)
        .map((template) {
          final title = switch (template.metricType) {
            ChallengeMetricType.sessions =>
              '$monthLabel ${template.targetValue.toInt()} Sessions Challenge',
            ChallengeMetricType.minutes =>
              '$monthLabel ${template.targetValue.toInt()} Min Challenge',
            ChallengeMetricType.scoreCount =>
              '$monthLabel ${template.scoreThreshold?.toInt() ?? 90}+ Score Challenge',
          };
          final description = switch (template.metricType) {
            ChallengeMetricType.sessions =>
              'Complete ${template.targetValue.toInt()} sessions this month.',
            ChallengeMetricType.minutes =>
              'Practice for ${template.targetValue.toInt()} total minutes this month.',
            ChallengeMetricType.scoreCount =>
              'Reach ${template.scoreThreshold?.toInt() ?? 90}% or higher ${template.targetValue.toInt()} times this month.',
          };
          return ProfileChallengeDefinition(
            challengeId: template.challengeId,
            title: title,
            description: description,
            metricType: template.metricType,
            targetValue: template.targetValue,
            scoreThreshold: template.scoreThreshold,
            rewardXp: template.rewardXp,
            rewardBadgeLabel: template.rewardBadgeLabel,
          );
        })
        .toList(growable: false);
  }

  List<PoseResult> _completedResultsForMonth({
    required List<PoseResult> results,
    required DateTime monthStart,
    required DateTime monthEnd,
  }) {
    return results
        .where((result) {
          if (!result.completed) return false;
          final ts = result.timestamp?.toLocal();
          if (ts == null) return false;
          return !ts.isBefore(monthStart) && ts.isBefore(monthEnd);
        })
        .toList(growable: false);
  }

  double _currentValueForMetric({
    required ProfileChallengeDefinition definition,
    required List<PoseResult> results,
  }) {
    return switch (definition.metricType) {
      ChallengeMetricType.sessions => results.length.toDouble(),
      ChallengeMetricType.minutes =>
        results.fold<double>(0, (sum, item) => sum + item.holdDuration) / 60.0,
      ChallengeMetricType.scoreCount =>
        results
            .where(
              (item) => item.bestScore >= (definition.scoreThreshold ?? 90),
            )
            .length
            .toDouble(),
    };
  }

  ChallengeLifecycleStatus _resolveStatus({
    required UserProfileChallengeState? state,
    required bool isJoined,
    required bool reachedTarget,
    required bool isEndedMonth,
  }) {
    if (state?.claimedAt != null ||
        state?.status == UserProfileChallengeStatus.completed) {
      return ChallengeLifecycleStatus.completed;
    }
    if (isEndedMonth) {
      return ChallengeLifecycleStatus.ended;
    }
    if (!isJoined) return ChallengeLifecycleStatus.notJoined;
    if (reachedTarget) return ChallengeLifecycleStatus.claimable;
    return ChallengeLifecycleStatus.joined;
  }

  static int _statusRank(ChallengeLifecycleStatus status) {
    return switch (status) {
      ChallengeLifecycleStatus.claimable => 0,
      ChallengeLifecycleStatus.joined => 1,
      ChallengeLifecycleStatus.completed => 2,
      ChallengeLifecycleStatus.notJoined => 3,
      ChallengeLifecycleStatus.ended => 4,
    };
  }

  String _buttonLabel(ChallengeLifecycleStatus status) {
    return switch (status) {
      ChallengeLifecycleStatus.notJoined => 'Join',
      ChallengeLifecycleStatus.joined => 'Joined',
      ChallengeLifecycleStatus.claimable => 'Claim',
      ChallengeLifecycleStatus.completed => 'Completed',
      ChallengeLifecycleStatus.ended => 'Ended',
    };
  }

  String _formatProgress(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.001) {
      return rounded.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  static String _monthName(int month) {
    const names = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[(month - 1).clamp(0, 11)];
  }
}

class _ChallengeTemplate {
  final String challengeId;
  final ChallengeMetricType metricType;
  final double targetValue;
  final double? scoreThreshold;
  final int rewardXp;
  final String rewardBadgeLabel;

  const _ChallengeTemplate({
    required this.challengeId,
    required this.metricType,
    required this.targetValue,
    required this.scoreThreshold,
    required this.rewardXp,
    required this.rewardBadgeLabel,
  });
}
