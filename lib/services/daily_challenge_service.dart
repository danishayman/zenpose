import 'dart:math';

import '../constants/session_launch_config.dart';
import '../models/challenge_step_result.dart';
import '../models/daily_challenge.dart';
import '../models/daily_challenge_step.dart';
import '../models/exercise_definition.dart';
import '../models/pose_result.dart';
import '../models/pose_template.dart';
import '../models/unlocked_badge.dart';
import '../models/user_rank.dart';
import 'admin_management_service.dart';
import 'auth_context.dart';
import 'database_service.dart';
import 'gamification_service.dart';
import 'pose_template_service.dart';
import 'user_rank_service.dart';

class DailyChallengeStepProcessResult {
  final DailyChallengeBundle bundle;
  final int xpGained;
  final int xpBefore;
  final int xpAfter;
  final UserRankTier rankBefore;
  final UserRankTier rankAfter;
  final bool didRankUp;
  final List<UnlockedBadge> unlockedBadges;
  final bool applied;

  const DailyChallengeStepProcessResult({
    required this.bundle,
    required this.xpGained,
    required this.xpBefore,
    required this.xpAfter,
    required this.rankBefore,
    required this.rankAfter,
    required this.didRankUp,
    required this.unlockedBadges,
    required this.applied,
  });
}

class _DailyChallengeStepTarget {
  final String poseName;
  final int targetHoldSeconds;

  const _DailyChallengeStepTarget({
    required this.poseName,
    required this.targetHoldSeconds,
  });
}

/// Local offline daily challenge orchestration.
class DailyChallengeService {
  final DatabaseService _databaseService;
  final PoseTemplateService _templateService;
  final GamificationService _gamificationService;
  final AdminManagementService _adminManagementService;

  DailyChallengeService({
    DatabaseService? databaseService,
    PoseTemplateService? templateService,
    GamificationService? gamificationService,
    AdminManagementService? adminManagementService,
  }) : _databaseService = databaseService ?? DatabaseService.instance,
       _templateService = templateService ?? PoseTemplateService(),
       _gamificationService = gamificationService ?? GamificationService(),
       _adminManagementService =
           adminManagementService ?? AdminManagementService();

  static const int totalSteps = 5;
  static const int maxSkips = 1;
  static const int transitionSeconds =
      SessionLaunchConfig.preSessionCountdownSeconds;
  // Legacy/default fallback for challenge rows created before level-based
  // hold durations were introduced.
  static const Duration challengeHoldDuration = Duration(seconds: 45);
  static const Duration challengeRestDuration = Duration(seconds: 30);
  static const double challengeScoreThreshold = 70;
  static const double caloriesPerActiveSecond = 0.08;

  static const int bronzeChallengeHoldSeconds = 20;
  static const int silverChallengeHoldSeconds = 30;
  static const int goldChallengeHoldSeconds = 35;
  static const int emeraldChallengeHoldSeconds = 40;
  static const int diamondChallengeHoldSeconds = 45;

  static String dateKeyFromDate(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static List<String> buildDeterministicSequence({
    required List<String> poseNames,
    required String dateKey,
    required int take,
  }) {
    final sorted = [...poseNames]..sort();
    final seed = dateKey.codeUnits.fold<int>(17, (acc, u) => (acc * 31) + u);
    final rng = Random(seed);
    sorted.shuffle(rng);
    return sorted.take(min(take, sorted.length)).toList();
  }

  static bool canSkip(int currentSkipCount) => currentSkipCount < maxSkips;

  static UserRankTier rankFromXp(int totalXp) {
    return UserRankService.rankForXp(totalXp);
  }

  static int holdSecondsForRank(UserRankTier rank) {
    return switch (rank) {
      UserRankTier.bronze => bronzeChallengeHoldSeconds,
      UserRankTier.silver => silverChallengeHoldSeconds,
      UserRankTier.gold => goldChallengeHoldSeconds,
      UserRankTier.emerald => emeraldChallengeHoldSeconds,
      UserRankTier.diamond => diamondChallengeHoldSeconds,
    };
  }

  static int holdSecondsForXp(int totalXp) {
    return holdSecondsForRank(rankFromXp(totalXp));
  }

  static int targetHoldSecondsForChallenge(DailyChallenge challenge) {
    return challenge.targetHoldSeconds ?? challengeHoldDuration.inSeconds;
  }

  static int targetHoldSecondsForStep(
    DailyChallengeStep step,
    DailyChallenge challenge,
  ) {
    return step.targetHoldSeconds ?? targetHoldSecondsForChallenge(challenge);
  }

  static Duration targetHoldDurationForStep(
    DailyChallengeStep step,
    DailyChallenge challenge,
  ) {
    return Duration(seconds: targetHoldSecondsForStep(step, challenge));
  }

  static Duration targetHoldDurationForChallenge(DailyChallenge challenge) {
    return Duration(seconds: targetHoldSecondsForChallenge(challenge));
  }

  static bool isStepPassing({
    required double bestScore,
    required double holdDurationSeconds,
    double scoreThreshold = challengeScoreThreshold,
    Duration requiredHold = challengeHoldDuration,
  }) {
    return bestScore >= scoreThreshold &&
        holdDurationSeconds >= requiredHold.inSeconds;
  }

  static bool shouldMarkCompleted({
    required int pendingStepsAfterUpdate,
    int? skipCount,
  }) {
    return pendingStepsAfterUpdate == 0;
  }

  Future<DailyChallengeBundle> getOrCreateTodayChallenge({
    DateTime? now,
  }) async {
    final dateKey = dateKeyFromDate(now ?? DateTime.now());
    return getOrCreateChallenge(dateKey: dateKey);
  }

  Future<DailyChallengeBundle> getOrCreateChallenge({
    required String dateKey,
  }) async {
    final existing = await _databaseService.getDailyChallengeByDateKey(dateKey);
    if (existing != null) {
      final userStats = await _databaseService.getUserStats();
      final rankTargetHoldSeconds = holdSecondsForXp(userStats.totalXp);
      var challenge = existing;
      if (targetHoldSecondsForChallenge(challenge) != rankTargetHoldSeconds) {
        final now = DateTime.now();
        challenge = challenge.copyWith(
          targetHoldSeconds: rankTargetHoldSeconds,
          updatedAt: now,
        );
        await _databaseService.updateDailyChallenge(challenge);
      }
      final loadedSteps = await _databaseService.getDailyChallengeSteps(
        dateKey,
      );
      final steps = await _syncStepTargetsToRank(
        rankTargetHoldSeconds: rankTargetHoldSeconds,
        steps: loadedSteps,
      );
      final pendingCount =
          steps
              .where((step) => step.status == DailyChallengeStepStatus.pending)
              .length;
      if (pendingCount == 0 &&
          challenge.status != DailyChallengeStatus.completed) {
        final now = DateTime.now();
        final repaired = challenge.copyWith(
          status: DailyChallengeStatus.completed,
          completedAt: challenge.completedAt ?? now,
          updatedAt: now,
        );
        await _databaseService.updateDailyChallenge(repaired);
        return DailyChallengeBundle(challenge: repaired, steps: steps);
      }
      return DailyChallengeBundle(challenge: challenge, steps: steps);
    }

    final templates = await _templateService.loadTemplates();
    final userStats = await _databaseService.getUserStats();
    final rankTargetHoldSeconds = holdSecondsForXp(userStats.totalXp);
    final targets = await _buildChallengeStepTargets(
      dateKey: dateKey,
      templates: templates,
      rankTargetHoldSeconds: rankTargetHoldSeconds,
    );
    final sequence = targets.map((target) => target.poseName).toList();

    final createdAt = DateTime.now();
    final challenge = DailyChallenge(
      dateKey: dateKey,
      status: DailyChallengeStatus.inProgress,
      skipCount: 0,
      totalSteps: sequence.length,
      targetHoldSeconds: rankTargetHoldSeconds,
      startedAt: createdAt,
      completedAt: null,
      updatedAt: createdAt,
      sequence: sequence,
    );
    final steps = <DailyChallengeStep>[
      for (var i = 0; i < targets.length; i++)
        DailyChallengeStep(
          dateKey: dateKey,
          stepIndex: i,
          poseName: targets[i].poseName,
          status: DailyChallengeStepStatus.pending,
          bestScore: null,
          holdDuration: null,
          targetHoldSeconds: targets[i].targetHoldSeconds,
          updatedAt: createdAt,
        ),
    ];

    await _databaseService.insertDailyChallenge(
      challenge: challenge,
      steps: steps,
    );
    return DailyChallengeBundle(challenge: challenge, steps: steps);
  }

  Future<DailyChallengeBundle> reorderSteps({
    required String dateKey,
    required List<DailyChallengeStep> orderedSteps,
  }) async {
    final bundle = await getOrCreateChallenge(dateKey: dateKey);
    if (bundle.challenge.isCompleted || bundle.hasStarted) {
      return bundle;
    }
    if (orderedSteps.length != bundle.steps.length) {
      return bundle;
    }
    final currentPoses = bundle.steps
        .map((step) => step.poseName)
        .toList(growable: false);
    final reorderedPoses = orderedSteps
        .map((step) => step.poseName)
        .toList(growable: false);
    if (!_hasSamePoseSet(currentPoses, reorderedPoses)) {
      return bundle;
    }

    final now = DateTime.now();
    final reindexedSteps = <DailyChallengeStep>[
      for (var i = 0; i < orderedSteps.length; i++)
        DailyChallengeStep(
          dateKey: dateKey,
          stepIndex: i,
          poseName: orderedSteps[i].poseName,
          status: orderedSteps[i].status,
          bestScore: orderedSteps[i].bestScore,
          holdDuration: orderedSteps[i].holdDuration,
          targetHoldSeconds: orderedSteps[i].targetHoldSeconds,
          updatedAt: now,
        ),
    ];

    await _databaseService.reorderDailyChallengeSteps(
      dateKey: dateKey,
      orderedSteps: reindexedSteps,
    );
    await _databaseService.updateDailyChallenge(
      bundle.challenge.copyWith(sequence: reorderedPoses, updatedAt: now),
    );
    return _refreshBundle(dateKey);
  }

  Future<DailyChallengeStepProcessResult> skipStep({
    required String dateKey,
    required int stepIndex,
  }) async {
    final bundle = await getOrCreateChallenge(dateKey: dateKey);
    final step = bundle.steps.firstWhere((s) => s.stepIndex == stepIndex);
    if (step.status != DailyChallengeStepStatus.pending) {
      return DailyChallengeStepProcessResult(
        bundle: bundle,
        xpGained: 0,
        xpBefore: 0,
        xpAfter: 0,
        rankBefore: UserRankTier.bronze,
        rankAfter: UserRankTier.bronze,
        didRankUp: false,
        unlockedBadges: const <UnlockedBadge>[],
        applied: false,
      );
    }
    if (!canSkip(bundle.challenge.skipCount)) {
      return DailyChallengeStepProcessResult(
        bundle: bundle,
        xpGained: 0,
        xpBefore: 0,
        xpAfter: 0,
        rankBefore: UserRankTier.bronze,
        rankAfter: UserRankTier.bronze,
        didRankUp: false,
        unlockedBadges: const <UnlockedBadge>[],
        applied: false,
      );
    }

    final now = DateTime.now();
    await _databaseService.updateDailyChallengeStep(
      step.copyWith(status: DailyChallengeStepStatus.skipped, updatedAt: now),
    );

    await _databaseService.updateDailyChallenge(
      bundle.challenge.copyWith(
        skipCount: bundle.challenge.skipCount + 1,
        updatedAt: now,
      ),
    );
    await _syncChallengeCompletion(dateKey: dateKey, now: now);

    final refreshed = await _refreshBundle(dateKey);
    return DailyChallengeStepProcessResult(
      bundle: refreshed,
      xpGained: 0,
      xpBefore: 0,
      xpAfter: 0,
      rankBefore: UserRankTier.bronze,
      rankAfter: UserRankTier.bronze,
      didRankUp: false,
      unlockedBadges: const <UnlockedBadge>[],
      applied: true,
    );
  }

  Future<DailyChallengeStepProcessResult> completeStep({
    required String dateKey,
    required int stepIndex,
    required ChallengeStepResult stepResult,
    bool allowOverwrite = false,
  }) async {
    final bundle = await getOrCreateChallenge(dateKey: dateKey);
    final step = bundle.steps.firstWhere((s) => s.stepIndex == stepIndex);
    final requiredHold = targetHoldDurationForStep(step, bundle.challenge);
    if (!stepResult.passed ||
        !isStepPassing(
          bestScore: stepResult.bestScore,
          holdDurationSeconds: stepResult.holdDuration,
          requiredHold: requiredHold,
        )) {
      return DailyChallengeStepProcessResult(
        bundle: bundle,
        xpGained: 0,
        xpBefore: 0,
        xpAfter: 0,
        rankBefore: UserRankTier.bronze,
        rankAfter: UserRankTier.bronze,
        didRankUp: false,
        unlockedBadges: const <UnlockedBadge>[],
        applied: false,
      );
    }

    final isPending = step.status == DailyChallengeStepStatus.pending;
    if (!isPending && !allowOverwrite) {
      return DailyChallengeStepProcessResult(
        bundle: bundle,
        xpGained: 0,
        xpBefore: 0,
        xpAfter: 0,
        rankBefore: UserRankTier.bronze,
        rankAfter: UserRankTier.bronze,
        didRankUp: false,
        unlockedBadges: const <UnlockedBadge>[],
        applied: false,
      );
    }

    final now = DateTime.now();
    await _databaseService.updateDailyChallengeStep(
      step.copyWith(
        status: DailyChallengeStepStatus.completed,
        bestScore: stepResult.bestScore,
        holdDuration: stepResult.holdDuration,
        updatedAt: now,
      ),
    );

    int xpGained = 0;
    int xpBefore = 0;
    int xpAfter = 0;
    var rankBefore = UserRankTier.bronze;
    var rankAfter = UserRankTier.bronze;
    var didRankUp = false;
    List<UnlockedBadge> unlockedBadges = const <UnlockedBadge>[];
    if (isPending) {
      final poseResult = PoseResult(
        poseName: stepResult.poseName,
        bestScore: stepResult.bestScore,
        holdDuration: stepResult.holdDuration,
        completed: true,
        timestamp: now,
        sessionType: PoseResultSessionType.challenge,
      );
      final insertedId = await _databaseService.insertPoseResult(poseResult);
      final gamification = await _gamificationService.processCompletedSession(
        poseResult.copyWith(id: insertedId),
      );
      xpGained = gamification.xpGained;
      xpBefore = gamification.xpBefore;
      xpAfter = gamification.xpAfter;
      rankBefore = gamification.rankBefore;
      rankAfter = gamification.rankAfter;
      didRankUp = gamification.didRankUp;
      unlockedBadges = gamification.unlockedBadges;
    }

    await _syncChallengeCompletion(dateKey: dateKey, now: now);

    final refreshed = await _refreshBundle(dateKey);
    return DailyChallengeStepProcessResult(
      bundle: refreshed,
      xpGained: xpGained,
      xpBefore: xpBefore,
      xpAfter: xpAfter,
      rankBefore: rankBefore,
      rankAfter: rankAfter,
      didRankUp: didRankUp,
      unlockedBadges: unlockedBadges,
      applied: true,
    );
  }

  Future<DailyChallengeStepProcessResult> completeTimedStep({
    required String dateKey,
    required int stepIndex,
    required ChallengeStepResult stepResult,
    bool allowOverwrite = false,
  }) async {
    final bundle = await getOrCreateChallenge(dateKey: dateKey);
    final step = bundle.steps.firstWhere((s) => s.stepIndex == stepIndex);
    final isPending = step.status == DailyChallengeStepStatus.pending;
    if (!isPending && !allowOverwrite) {
      return DailyChallengeStepProcessResult(
        bundle: bundle,
        xpGained: 0,
        xpBefore: 0,
        xpAfter: 0,
        rankBefore: UserRankTier.bronze,
        rankAfter: UserRankTier.bronze,
        didRankUp: false,
        unlockedBadges: const <UnlockedBadge>[],
        applied: false,
      );
    }

    final now = DateTime.now();
    await _databaseService.updateDailyChallengeStep(
      step.copyWith(
        status: DailyChallengeStepStatus.completed,
        bestScore: stepResult.bestScore,
        holdDuration: stepResult.holdDuration,
        updatedAt: now,
      ),
    );

    int xpGained = 0;
    int xpBefore = 0;
    int xpAfter = 0;
    var rankBefore = UserRankTier.bronze;
    var rankAfter = UserRankTier.bronze;
    var didRankUp = false;
    List<UnlockedBadge> unlockedBadges = const <UnlockedBadge>[];
    if (isPending) {
      final poseResult = PoseResult(
        poseName: stepResult.poseName,
        bestScore: stepResult.bestScore,
        holdDuration: stepResult.holdDuration,
        completed: true,
        timestamp: now,
        sessionType: PoseResultSessionType.challenge,
      );
      final insertedId = await _databaseService.insertPoseResult(poseResult);
      final gamification = await _gamificationService.processCompletedSession(
        poseResult.copyWith(id: insertedId),
      );
      xpGained = gamification.xpGained;
      xpBefore = gamification.xpBefore;
      xpAfter = gamification.xpAfter;
      rankBefore = gamification.rankBefore;
      rankAfter = gamification.rankAfter;
      didRankUp = gamification.didRankUp;
      unlockedBadges = gamification.unlockedBadges;
    }

    await _syncChallengeCompletion(dateKey: dateKey, now: now);
    final refreshed = await _refreshBundle(dateKey);
    return DailyChallengeStepProcessResult(
      bundle: refreshed,
      xpGained: xpGained,
      xpBefore: xpBefore,
      xpAfter: xpAfter,
      rankBefore: rankBefore,
      rankAfter: rankAfter,
      didRankUp: didRankUp,
      unlockedBadges: unlockedBadges,
      applied: true,
    );
  }

  Future<DailyChallengeBundle> saveSessionSummary({
    required String dateKey,
    required Duration elapsed,
    required String? feedback,
  }) async {
    final bundle = await _refreshBundle(dateKey);
    final avgScore = _computeAverageScore(bundle.steps);
    final activeSeconds = _computeActiveExerciseSeconds(
      bundle.steps,
      challenge: bundle.challenge,
    );
    final calories = double.parse(
      (activeSeconds * caloriesPerActiveSecond).toStringAsFixed(1),
    );
    final now = DateTime.now();
    final resolvedAll =
        bundle.completedStepsCount + bundle.skippedStepsCount >=
        bundle.steps.length;
    await _databaseService.updateDailyChallenge(
      bundle.challenge.copyWith(
        status:
            resolvedAll
                ? DailyChallengeStatus.completed
                : bundle.challenge.status,
        completedAt: resolvedAll ? now : bundle.challenge.completedAt,
        sessionAvgScore: avgScore,
        sessionCalories: calories,
        sessionElapsedSeconds: elapsed.inSeconds,
        sessionFeedback: feedback,
        updatedAt: now,
      ),
    );
    return _refreshBundle(dateKey);
  }

  Future<void> _syncChallengeCompletion({
    required String dateKey,
    required DateTime now,
  }) async {
    final refreshed = await _refreshBundle(dateKey);
    final shouldComplete = shouldMarkCompleted(
      pendingStepsAfterUpdate: refreshed.pendingStepsCount,
      skipCount: refreshed.challenge.skipCount,
    );
    final nextStatus =
        shouldComplete
            ? DailyChallengeStatus.completed
            : DailyChallengeStatus.inProgress;
    final isAlreadySynced =
        refreshed.challenge.status == nextStatus &&
        ((shouldComplete && refreshed.challenge.completedAt != null) ||
            (!shouldComplete && refreshed.challenge.completedAt == null));
    if (isAlreadySynced) {
      return;
    }
    await _databaseService.updateDailyChallenge(
      refreshed.challenge.copyWith(
        status: nextStatus,
        completedAt: shouldComplete ? now : null,
        updatedAt: now,
      ),
    );
  }

  Future<DailyChallengeBundle> _refreshBundle(String dateKey) async {
    final challenge = await _databaseService.getDailyChallengeByDateKey(
      dateKey,
    );
    if (challenge == null) {
      return getOrCreateChallenge(dateKey: dateKey);
    }
    final steps = await _databaseService.getDailyChallengeSteps(dateKey);
    return DailyChallengeBundle(challenge: challenge, steps: steps);
  }

  Future<List<PoseTemplate>> loadPoseTemplates() =>
      _templateService.loadTemplates();

  static double? _computeAverageScore(List<DailyChallengeStep> steps) {
    final completed = steps
        .where((s) => s.status == DailyChallengeStepStatus.completed)
        .toList(growable: false);
    if (completed.isEmpty) return null;
    final scores = completed
        .map((s) => s.bestScore)
        .whereType<double>()
        .toList(growable: false);
    if (scores.isEmpty) return null;
    final total = scores.fold<double>(0.0, (sum, score) => sum + score);
    return double.parse((total / scores.length).toStringAsFixed(1));
  }

  static int _computeActiveExerciseSeconds(
    List<DailyChallengeStep> steps, {
    required DailyChallenge challenge,
  }) {
    final completed = steps
        .where((s) => s.status == DailyChallengeStepStatus.completed)
        .toList(growable: false);
    if (completed.isEmpty) return 0;
    var seconds = 0.0;
    for (final step in completed) {
      seconds +=
          step.holdDuration ??
          targetHoldSecondsForStep(step, challenge).toDouble();
    }
    return seconds.round();
  }

  static bool _hasSamePoseSet(List<String> source, List<String> other) {
    if (source.length != other.length) return false;
    final counts = <String, int>{};
    for (final pose in source) {
      counts[pose] = (counts[pose] ?? 0) + 1;
    }
    for (final pose in other) {
      final remaining = counts[pose];
      if (remaining == null || remaining == 0) {
        return false;
      }
      counts[pose] = remaining - 1;
    }
    return counts.values.every((count) => count == 0);
  }

  Future<List<_DailyChallengeStepTarget>> _buildChallengeStepTargets({
    required String dateKey,
    required List<PoseTemplate> templates,
    required int rankTargetHoldSeconds,
  }) async {
    final poseNames = templates.map((t) => t.name).toList(growable: false);
    final fallback = buildDeterministicSequence(
          poseNames: poseNames,
          dateKey: dateKey,
          take: totalSteps,
        )
        .map(
          (poseName) => _DailyChallengeStepTarget(
            poseName: poseName,
            targetHoldSeconds: rankTargetHoldSeconds,
          ),
        )
        .toList(growable: false);
    try {
      final activeExercises = await _adminManagementService.listExercises(
        activeOnly: true,
      );
      final selected = _pickExerciseForDate(
        dateKey: dateKey,
        activeExercises: activeExercises,
      );
      if (selected == null || selected.steps.isEmpty) {
        return fallback;
      }
      final normalizedTemplateNames = <String>{
        for (final template in templates) _normalizePoseName(template.name),
      };
      final steps = selected.steps
          .where(
            (step) => normalizedTemplateNames.contains(
              _normalizePoseName(step.poseName),
            ),
          )
          .toList(growable: false);
      if (steps.isEmpty) {
        return fallback;
      }
      return steps
          .map(
            (step) => _DailyChallengeStepTarget(
              poseName: step.poseName,
              targetHoldSeconds: rankTargetHoldSeconds,
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return fallback;
    }
  }

  ExerciseDefinition? _pickExerciseForDate({
    required String dateKey,
    required List<ExerciseDefinition> activeExercises,
  }) {
    if (activeExercises.isEmpty) return null;
    final key = '$dateKey:${AuthContext.activeUserId}';
    final seed = key.codeUnits.fold<int>(23, (acc, code) => (acc * 37) + code);
    final index = seed.abs() % activeExercises.length;
    return activeExercises[index];
  }

  String _normalizePoseName(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<List<DailyChallengeStep>> _syncStepTargetsToRank({
    required int rankTargetHoldSeconds,
    required List<DailyChallengeStep> steps,
  }) async {
    if (steps.isEmpty) return steps;
    var changed = false;
    final repaired = <DailyChallengeStep>[];
    for (final step in steps) {
      if (step.targetHoldSeconds == rankTargetHoldSeconds) {
        repaired.add(step);
        continue;
      }
      final updated = step.copyWith(targetHoldSeconds: rankTargetHoldSeconds);
      await _databaseService.updateDailyChallengeStep(updated);
      repaired.add(updated);
      changed = true;
    }
    return changed ? repaired : steps;
  }
}
