import 'dart:async';

import 'package:flutter/material.dart';

import '../models/challenge_step_result.dart';
import '../models/daily_challenge.dart';
import '../models/daily_challenge_step.dart';
import '../models/pose_session_config.dart';
import '../models/pose_template.dart';
import '../models/unlocked_badge.dart';
import '../services/daily_challenge_service.dart';
import '../theme/zen_theme.dart';
import '../widgets/pre_session_countdown_widgets.dart';
import 'daily_challenge_summary_screen.dart';
import 'main_screen.dart';

enum _WorkoutPhase { ready, exercise, rest, completed }

class DailyChallengeWorkoutFlowScreen extends StatefulWidget {
  final String dateKey;
  final DailyChallengeService? challengeService;
  final Widget Function(PoseTemplate template)? evaluatorBuilder;

  const DailyChallengeWorkoutFlowScreen({
    super.key,
    required this.dateKey,
    this.challengeService,
    this.evaluatorBuilder,
  });

  @override
  State<DailyChallengeWorkoutFlowScreen> createState() =>
      _DailyChallengeWorkoutFlowScreenState();
}

class _DailyChallengeWorkoutFlowScreenState
    extends State<DailyChallengeWorkoutFlowScreen> {
  static const int _readyCountdownSeconds = 10;

  late final DailyChallengeService _challengeService;
  DailyChallengeBundle? _bundle;
  Map<String, PoseTemplate> _templatesByName = <String, PoseTemplate>{};
  bool _loading = true;
  bool _launching = false;
  int? _currentStepIndex;
  int _readyCycle = 0;
  _WorkoutPhase _phase = _WorkoutPhase.ready;
  Timer? _restTimer;
  int _restRemainingSeconds =
      DailyChallengeService.challengeRestDuration.inSeconds;
  int _sessionRestSeconds =
      DailyChallengeService.challengeRestDuration.inSeconds;
  final Set<int> _redoStepIndexes = <int>{};

  int _sessionXpEarned = 0;
  final List<UnlockedBadge> _sessionBadges = <UnlockedBadge>[];
  late DateTime _sessionStart;
  bool _sessionFinished = false;

  @override
  void initState() {
    super.initState();
    _challengeService = widget.challengeService ?? DailyChallengeService();
    _sessionStart = DateTime.now();
    _load();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final bundle = await _challengeService.getOrCreateChallenge(
      dateKey: widget.dateKey,
    );
    final templates = await _challengeService.loadPoseTemplates();
    _templatesByName = {for (final t in templates) t.name: t};
    _bundle = bundle;
    _currentStepIndex = _firstPendingStepIndex(bundle);
    _phase = _currentStepIndex == null
        ? _WorkoutPhase.completed
        : _WorkoutPhase.ready;
    _readyCycle = 0;
    if (!mounted) return;
    setState(() => _loading = false);
    if (_currentStepIndex == null) {
      unawaited(_openSummary());
    }
  }

  int? _firstPendingStepIndex(DailyChallengeBundle bundle) {
    for (final step in bundle.steps) {
      if (step.status == DailyChallengeStepStatus.pending) {
        return step.stepIndex;
      }
    }
    return null;
  }

  DailyChallengeStep? _stepByIndex(int? stepIndex) {
    final bundle = _bundle;
    if (bundle == null || stepIndex == null) return null;
    for (final step in bundle.steps) {
      if (step.stepIndex == stepIndex) {
        return step;
      }
    }
    return null;
  }

  DailyChallengeStep? get _currentStep {
    return _stepByIndex(_currentStepIndex);
  }

  bool _isSessionResolved(DailyChallengeBundle bundle) {
    return bundle.pendingStepsCount == 0;
  }

  DailyChallengeStep? get _upcomingPendingStep {
    final bundle = _bundle;
    if (bundle == null || _isSessionResolved(bundle)) return null;
    final current = _currentStep;
    if (current != null && current.status == DailyChallengeStepStatus.pending) {
      return current;
    }
    final nextPendingIndex = _firstPendingStepIndex(bundle);
    return _stepByIndex(nextPendingIndex);
  }

  Future<void> _advanceAfterStepSaved() async {
    final bundle = _bundle;
    if (bundle == null) return;
    final nextPendingIndex = _firstPendingStepIndex(bundle);
    if (nextPendingIndex == null) {
      await _openSummary();
      return;
    }
    _currentStepIndex = nextPendingIndex;
    _startRestPhase();
  }

  void _returnToReadyPhase() {
    if (!mounted) return;
    setState(() {
      _phase = _WorkoutPhase.ready;
      _readyCycle += 1;
    });
  }

  Future<void> _launchExercise() async {
    final bundle = _bundle;
    if (bundle != null && _isSessionResolved(bundle)) {
      await _openSummary();
      return;
    }
    if (_launching) return;
    var step = _currentStep;
    final bundleForStep = _bundle;
    if (bundleForStep != null &&
        (step == null ||
            (step.status != DailyChallengeStepStatus.pending &&
                !_redoStepIndexes.contains(step.stepIndex)))) {
      _currentStepIndex = _firstPendingStepIndex(bundleForStep);
      step = _currentStep;
    }
    if (step == null) {
      await _openSummary();
      return;
    }
    final template = _templatesByName[step.poseName];
    if (template == null) {
      _returnToReadyPhase();
      return;
    }

    _launching = true;
    ChallengeStepResult? result;
    if (mounted) {
      setState(() => _phase = _WorkoutPhase.exercise);
    }
    try {
      final challengeHoldDuration = _resolvedChallengeHoldDuration();
      final evaluator =
          widget.evaluatorBuilder?.call(template) ??
          MainScreen(
            poseTemplate: template,
            sessionConfig: PoseSessionConfig(
              mode: PoseSessionMode.timed,
              holdDuration: challengeHoldDuration,
              timedDuration: challengeHoldDuration,
              scoreThreshold: DailyChallengeService.challengeScoreThreshold,
              persistResult: false,
            ),
            completionActionLabel: 'Continue',
            returnResultOnCompletion: true,
          );

      result = await Navigator.of(
        context,
      ).push<ChallengeStepResult>(MaterialPageRoute(builder: (_) => evaluator));
    } catch (error) {
      debugPrint('Failed to launch exercise session: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to continue workout. Please try again.'),
          ),
        );
      }
      _returnToReadyPhase();
      return;
    } finally {
      _launching = false;
    }

    if (!mounted) return;
    if (result == null) {
      _returnToReadyPhase();
      return;
    }

    if (result.action == ChallengeStepNavigationAction.previous) {
      final currentIndex = _currentStepIndex ?? step.stepIndex;
      if (currentIndex > 0) {
        final rewoundIndex = currentIndex - 1;
        _currentStepIndex = rewoundIndex;
        _redoStepIndexes.add(rewoundIndex);
      }
      _returnToReadyPhase();
      return;
    }

    final shouldOverwrite =
        _redoStepIndexes.remove(step.stepIndex) ||
        step.status != DailyChallengeStepStatus.pending;
    try {
      final process = await _challengeService.completeTimedStep(
        dateKey: widget.dateKey,
        stepIndex: step.stepIndex,
        stepResult: result,
        allowOverwrite: shouldOverwrite,
      );
      _bundle = process.bundle;
      if (process.applied) {
        _sessionXpEarned += process.xpGained;
        _sessionBadges.addAll(process.unlockedBadges);
      }
    } catch (error) {
      debugPrint('Failed to save exercise result: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this exercise. Please try again.'),
          ),
        );
      }
      _returnToReadyPhase();
      return;
    }

    await _advanceAfterStepSaved();
  }

  void _startRestPhase() {
    _restTimer?.cancel();
    final nextStep = _upcomingPendingStep;
    if (nextStep == null) {
      unawaited(_openSummary());
      return;
    }
    _currentStepIndex = nextStep.stepIndex;
    setState(() {
      _phase = _WorkoutPhase.rest;
      _restRemainingSeconds = _sessionRestSeconds;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_restRemainingSeconds <= 1) {
        timer.cancel();
        setState(() => _restRemainingSeconds = 0);
        unawaited(_launchExercise());
        return;
      }
      setState(() => _restRemainingSeconds -= 1);
    });
  }

  Future<void> _editRestTime() async {
    var selected = _sessionRestSeconds.toDouble();
    final updated = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Rest Time'),
          content: StatefulBuilder(
            builder: (context, setLocalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${selected.round()} seconds',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    min: 10,
                    max: 90,
                    divisions: 16,
                    value: selected,
                    onChanged: (value) {
                      setLocalState(() => selected = value);
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(selected.round()),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
    if (updated == null || updated <= 0 || !mounted) return;
    setState(() {
      _sessionRestSeconds = updated;
      _restRemainingSeconds = updated;
    });
  }

  Future<void> _openSummary() async {
    if (_sessionFinished) return;
    _sessionFinished = true;
    _restTimer?.cancel();
    final bundle = _bundle;
    if (bundle == null) {
      _sessionFinished = false;
      return;
    }
    if (mounted) {
      setState(() => _phase = _WorkoutPhase.completed);
    }
    final elapsed = DateTime.now().difference(_sessionStart);
    final summarized = DailyChallengeBundle(
      challenge: bundle.challenge.copyWith(
        sessionAvgScore: _estimateAverageScore(bundle),
        sessionCalories: _estimateCalories(bundle),
        sessionElapsedSeconds: elapsed.inSeconds,
      ),
      steps: bundle.steps,
    );
    _bundle = summarized;

    // Persist in background so the completion screen opens immediately.
    unawaited(
      _challengeService
          .saveSessionSummary(
            dateKey: widget.dateKey,
            elapsed: elapsed,
            feedback: null,
          )
          .then((updated) {
            if (!mounted) return;
            _bundle = updated;
          })
          .catchError((_) {}),
    );
    final goHome = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DailyChallengeSummaryScreen(
          dayLabel: 'Day 1 • Daily Workout',
          completedSteps: summarized.completedStepsCount,
          skippedSteps: summarized.skippedStepsCount,
          totalSteps: summarized.steps.length,
          xpEarned: _sessionXpEarned,
          elapsed: elapsed,
          unlockedBadges: _sessionBadges,
          averageScore: summarized.challenge.sessionAvgScore,
          calories: summarized.challenge.sessionCalories,
          initialFeedback: summarized.challenge.sessionFeedback,
          onComplete: (feedback) => _challengeService.saveSessionSummary(
            dateKey: widget.dateKey,
            elapsed: elapsed,
            feedback: feedback,
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (goHome == true) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    _sessionFinished = false;
  }

  double? _estimateAverageScore(DailyChallengeBundle bundle) {
    final scores = bundle.steps
        .where((s) => s.status == DailyChallengeStepStatus.completed)
        .map((s) => s.bestScore)
        .whereType<double>()
        .toList(growable: false);
    if (scores.isEmpty) return null;
    final total = scores.fold<double>(0, (sum, score) => sum + score);
    return double.parse((total / scores.length).toStringAsFixed(1));
  }

  double? _estimateCalories(DailyChallengeBundle bundle) {
    final completed = bundle.steps
        .where((s) => s.status == DailyChallengeStepStatus.completed)
        .toList(growable: false);
    if (completed.isEmpty) return null;
    var activeSeconds = 0.0;
    final fallbackHoldSeconds =
        DailyChallengeService.targetHoldSecondsForChallenge(bundle.challenge);
    for (final step in completed) {
      activeSeconds += step.holdDuration ?? fallbackHoldSeconds.toDouble();
    }
    return double.parse(
      (activeSeconds * DailyChallengeService.caloriesPerActiveSecond)
          .toStringAsFixed(1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;
    return Scaffold(
      backgroundColor: ZenColors.surface0,
      appBar: AppBar(
        title: Text(
          "Today's Workout",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        backgroundColor: ZenColors.surface0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: Container(
        decoration: ZenDecor.gradientBackdrop(),
        child: _loading || bundle == null
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(top: false, child: _buildPhaseBody(bundle)),
      ),
    );
  }

  Widget _buildPhaseBody(DailyChallengeBundle bundle) {
    switch (_phase) {
      case _WorkoutPhase.ready:
        return _buildReady(bundle);
      case _WorkoutPhase.exercise:
        return const Center(child: CircularProgressIndicator());
      case _WorkoutPhase.rest:
        return _buildRest(bundle);
      case _WorkoutPhase.completed:
        return const SizedBox.shrink();
    }
  }

  Widget _buildReady(DailyChallengeBundle bundle) {
    final step = _currentStep;
    if (step == null) {
      unawaited(_openSummary());
      return const Center(child: CircularProgressIndicator());
    }
    final template = _templatesByName[step.poseName];
    if (template == null) {
      return const Center(child: Text('Missing exercise template.'));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      children: [
        Text(
          'EXERCISE ${step.stepIndex + 1}/${bundle.steps.length}',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: ZenColors.teal,
            letterSpacing: 0.7,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(step.poseName, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          'Get ready, then start your ${_resolvedChallengeHoldSeconds()}-second timed set.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        PreSessionCountdownPanel(
          key: ValueKey<String>('ready-${step.stepIndex}-$_readyCycle'),
          template: template,
          countdownSeconds: _readyCountdownSeconds,
          showStartNowButton: true,
          startNowLabel: 'Start Now',
          onCountdownComplete: _launchExercise,
        ),
      ],
    );
  }

  Widget _buildRest(DailyChallengeBundle bundle) {
    final nextStep = _upcomingPendingStep;
    final nextTemplate = nextStep == null
        ? null
        : _templatesByName[nextStep.poseName];
    final showPreview =
        nextTemplate != null && MediaQuery.of(context).size.height >= 760;
    return Column(
      children: [
        if (showPreview)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: PoseDemoAnimation(
              template: nextTemplate,
              height: 210,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[ZenColors.forest, ZenColors.teal],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (nextStep != null) ...[
                  Text(
                    'NEXT ${nextStep.stepIndex + 1}/${bundle.steps.length}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Manrope',
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nextStep.poseName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Manrope',
                      height: 1.1,
                    ),
                  ),
                ],
                const Spacer(),
                const Text(
                  'REST',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Manrope',
                  ),
                ),
                Text(
                  _formatClock(_restRemainingSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Manrope',
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _editRestTime,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('Edit Rest Time'),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _restRemainingSeconds += 20);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('+20s'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _restTimer?.cancel();
                          unawaited(_launchExercise());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ZenColors.surface1,
                          foregroundColor: ZenColors.forest,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Skip'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatClock(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  int _resolvedChallengeHoldSeconds() {
    final bundle = _bundle;
    if (bundle == null) {
      return DailyChallengeService.challengeHoldDuration.inSeconds;
    }
    return DailyChallengeService.targetHoldSecondsForChallenge(
      bundle.challenge,
    );
  }

  Duration _resolvedChallengeHoldDuration() {
    return Duration(seconds: _resolvedChallengeHoldSeconds());
  }
}
