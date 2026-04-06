import 'dart:math';

import '../constants/session_launch_config.dart';
import '../models/challenge_step_result.dart';
import '../models/daily_challenge.dart';
import '../models/daily_challenge_step.dart';
import '../models/pose_result.dart';
import '../models/pose_template.dart';
import '../models/unlocked_badge.dart';
import 'database_service.dart';
import 'gamification_service.dart';
import 'pose_template_service.dart';

class DailyChallengeStepProcessResult {
  final DailyChallengeBundle bundle;
  final int xpGained;
  final List<UnlockedBadge> unlockedBadges;
  final bool applied;

  const DailyChallengeStepProcessResult({
    required this.bundle,
    required this.xpGained,
    required this.unlockedBadges,
    required this.applied,
  });
}

/// Local offline daily challenge orchestration.
class DailyChallengeService {
  final DatabaseService _databaseService;
  final PoseTemplateService _templateService;
  final GamificationService _gamificationService;

  DailyChallengeService({
    DatabaseService? databaseService,
    PoseTemplateService? templateService,
    GamificationService? gamificationService,
  }) : _databaseService = databaseService ?? DatabaseService.instance,
       _templateService = templateService ?? PoseTemplateService(),
       _gamificationService = gamificationService ?? GamificationService();

  static const int totalSteps = 5;
  static const int maxSkips = 1;
  static const int transitionSeconds =
      SessionLaunchConfig.preSessionCountdownSeconds;
  static const Duration challengeHoldDuration = Duration(seconds: 45);
  static const Duration challengeRestDuration = Duration(seconds: 30);
  static const double challengeScoreThreshold = 70;
  static const double caloriesPerActiveSecond = 0.08;

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
      final steps = await _databaseService.getDailyChallengeSteps(dateKey);
      final pendingCount = steps
          .where((step) => step.status == DailyChallengeStepStatus.pending)
          .length;
      if (pendingCount == 0 &&
          existing.status != DailyChallengeStatus.completed) {
        final now = DateTime.now();
        final repaired = existing.copyWith(
          status: DailyChallengeStatus.completed,
          completedAt: existing.completedAt ?? now,
          updatedAt: now,
        );
        await _databaseService.updateDailyChallenge(repaired);
        return DailyChallengeBundle(challenge: repaired, steps: steps);
      }
      return DailyChallengeBundle(challenge: existing, steps: steps);
    }

    final templates = await _templateService.loadTemplates();
    final sequence = buildDeterministicSequence(
      poseNames: templates.map((t) => t.name).toList(),
      dateKey: dateKey,
      take: totalSteps,
    );

    final createdAt = DateTime.now();
    final challenge = DailyChallenge(
      dateKey: dateKey,
      status: DailyChallengeStatus.inProgress,
      skipCount: 0,
      totalSteps: sequence.length,
      startedAt: createdAt,
      completedAt: null,
      updatedAt: createdAt,
      sequence: sequence,
    );
    final steps = <DailyChallengeStep>[
      for (var i = 0; i < sequence.length; i++)
        DailyChallengeStep(
          dateKey: dateKey,
          stepIndex: i,
          poseName: sequence[i],
          status: DailyChallengeStepStatus.pending,
          bestScore: null,
          holdDuration: null,
          updatedAt: createdAt,
        ),
    ];

    await _databaseService.insertDailyChallenge(
      challenge: challenge,
      steps: steps,
    );
    return DailyChallengeBundle(challenge: challenge, steps: steps);
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
        unlockedBadges: const <UnlockedBadge>[],
        applied: false,
      );
    }
    if (!canSkip(bundle.challenge.skipCount)) {
      return DailyChallengeStepProcessResult(
        bundle: bundle,
        xpGained: 0,
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
    if (!stepResult.passed ||
        !isStepPassing(
          bestScore: stepResult.bestScore,
          holdDurationSeconds: stepResult.holdDuration,
        )) {
      final bundle = await _refreshBundle(dateKey);
      return DailyChallengeStepProcessResult(
        bundle: bundle,
        xpGained: 0,
        unlockedBadges: const <UnlockedBadge>[],
        applied: false,
      );
    }

    final bundle = await getOrCreateChallenge(dateKey: dateKey);
    final step = bundle.steps.firstWhere((s) => s.stepIndex == stepIndex);
    final isPending = step.status == DailyChallengeStepStatus.pending;
    if (!isPending && !allowOverwrite) {
      return DailyChallengeStepProcessResult(
        bundle: bundle,
        xpGained: 0,
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
      unlockedBadges = gamification.unlockedBadges;
    }

    await _syncChallengeCompletion(dateKey: dateKey, now: now);

    final refreshed = await _refreshBundle(dateKey);
    return DailyChallengeStepProcessResult(
      bundle: refreshed,
      xpGained: xpGained,
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
      unlockedBadges = gamification.unlockedBadges;
    }

    await _syncChallengeCompletion(dateKey: dateKey, now: now);
    final refreshed = await _refreshBundle(dateKey);
    return DailyChallengeStepProcessResult(
      bundle: refreshed,
      xpGained: xpGained,
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
    final activeSeconds = _computeActiveExerciseSeconds(bundle.steps);
    final calories = double.parse(
      (activeSeconds * caloriesPerActiveSecond).toStringAsFixed(1),
    );
    final now = DateTime.now();
    final resolvedAll =
        bundle.completedStepsCount + bundle.skippedStepsCount >=
        bundle.steps.length;
    await _databaseService.updateDailyChallenge(
      bundle.challenge.copyWith(
        status: resolvedAll
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
    final nextStatus = shouldComplete
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

  static int _computeActiveExerciseSeconds(List<DailyChallengeStep> steps) {
    final completed = steps
        .where((s) => s.status == DailyChallengeStepStatus.completed)
        .toList(growable: false);
    if (completed.isEmpty) return 0;
    var seconds = 0.0;
    for (final step in completed) {
      seconds +=
          step.holdDuration ?? challengeHoldDuration.inSeconds.toDouble();
    }
    return seconds.round();
  }
}
