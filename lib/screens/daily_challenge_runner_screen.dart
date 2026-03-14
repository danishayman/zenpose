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
import '../widgets/zen_section_header.dart';
import 'daily_challenge_summary_screen.dart';
import 'main_screen.dart';

class DailyChallengeRunnerScreen extends StatefulWidget {
  final String dateKey;

  const DailyChallengeRunnerScreen({super.key, required this.dateKey});

  @override
  State<DailyChallengeRunnerScreen> createState() =>
      _DailyChallengeRunnerScreenState();
}

class _DailyChallengeRunnerScreenState
    extends State<DailyChallengeRunnerScreen> {
  final DailyChallengeService _challengeService = DailyChallengeService();

  DailyChallengeBundle? _bundle;
  Map<String, PoseTemplate> _templatesByName = <String, PoseTemplate>{};

  bool _loading = true;
  bool _launching = false;
  int _currentStepIndex = 0;
  int _transitionRemaining = DailyChallengeService.transitionSeconds;
  Timer? _transitionTimer;

  int _sessionXpEarned = 0;
  final List<UnlockedBadge> _sessionBadges = <UnlockedBadge>[];
  late DateTime _sessionStart;

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    _load();
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
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
    _currentStepIndex = _nextPendingStepIndex(bundle);
    _transitionRemaining = DailyChallengeService.transitionSeconds;
    if (!bundle.challenge.isCompleted) {
      _startTransition();
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  int _nextPendingStepIndex(DailyChallengeBundle bundle) {
    for (final step in bundle.steps) {
      if (step.status == DailyChallengeStepStatus.pending) {
        return step.stepIndex;
      }
    }
    return bundle.steps.isEmpty ? 0 : bundle.steps.last.stepIndex;
  }

  DailyChallengeStep? get _currentStep {
    if (_bundle == null) return null;
    return _bundle!.steps.firstWhere(
      (step) => step.stepIndex == _currentStepIndex,
      orElse: () => _bundle!.steps.first,
    );
  }

  void _startTransition() {
    _transitionTimer?.cancel();
    _transitionRemaining = DailyChallengeService.transitionSeconds;
    _transitionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_transitionRemaining <= 1) {
        timer.cancel();
        _transitionRemaining = 0;
        setState(() {});
        unawaited(_launchPoseEvaluator());
        return;
      }
      setState(() => _transitionRemaining -= 1);
    });
  }

  Future<void> _launchPoseEvaluator() async {
    if (_launching) return;
    final step = _currentStep;
    if (step == null) return;
    if (step.status != DailyChallengeStepStatus.pending) return;
    final template = _templatesByName[step.poseName];
    if (template == null) return;

    _launching = true;
    final result = await Navigator.of(context).push<ChallengeStepResult>(
      MaterialPageRoute(
        builder: (_) => MainScreen(
          poseTemplate: template,
          sessionConfig: const PoseSessionConfig(
            holdDuration: DailyChallengeService.challengeHoldDuration,
            scoreThreshold: DailyChallengeService.challengeScoreThreshold,
            persistResult: false,
          ),
          completionActionLabel: 'Continue',
          returnResultOnCompletion: true,
        ),
      ),
    );
    _launching = false;

    if (!mounted || result == null) return;

    final process = await _challengeService.completeStep(
      dateKey: widget.dateKey,
      stepIndex: step.stepIndex,
      stepResult: result,
    );
    _bundle = process.bundle;
    if (process.applied) {
      _sessionXpEarned += process.xpGained;
      _sessionBadges.addAll(process.unlockedBadges);
    }

    if (_bundle!.challenge.isCompleted) {
      await _openSummary();
      return;
    }

    _currentStepIndex = _nextPendingStepIndex(_bundle!);
    _startTransition();
    setState(() {});
  }

  Future<void> _skipCurrentStep() async {
    final bundle = _bundle;
    final step = _currentStep;
    if (bundle == null || step == null) return;
    if (!DailyChallengeService.canSkip(bundle.challenge.skipCount)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already used your one skip.')),
      );
      return;
    }
    final process = await _challengeService.skipStep(
      dateKey: widget.dateKey,
      stepIndex: step.stepIndex,
    );
    _bundle = process.bundle;
    if (_bundle!.challenge.isCompleted) {
      await _openSummary();
      return;
    }
    _currentStepIndex = _nextPendingStepIndex(_bundle!);
    _startTransition();
    setState(() {});
  }

  Future<void> _openSummary() async {
    final bundle = _bundle;
    if (bundle == null) return;
    final elapsed = DateTime.now().difference(_sessionStart);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailyChallengeSummaryScreen(
          completedSteps: bundle.completedStepsCount,
          skippedSteps: bundle.skippedStepsCount,
          totalSteps: bundle.steps.length,
          xpEarned: _sessionXpEarned,
          elapsed: elapsed,
          unlockedBadges: _sessionBadges,
        ),
      ),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;
    return Scaffold(
      backgroundColor: ZenColors.surface0,
      appBar: AppBar(
        title: Text(
          "Today's Challenge",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        backgroundColor: ZenColors.surface0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: ZenDecor.gradientBackdrop(),
        child: _loading || bundle == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  _buildProgressHeader(bundle),
                  const SizedBox(height: 14),
                  _buildCurrentStepCard(bundle),
                  const SizedBox(height: 14),
                  _buildStepList(bundle),
                ],
              ),
      ),
    );
  }

  Widget _buildProgressHeader(DailyChallengeBundle bundle) {
    final progress = bundle.steps.isEmpty
        ? 0.0
        : bundle.completedStepsCount / bundle.steps.length;

    return Container(
      decoration: ZenDecor.elevatedCard(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Daily Flow',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _pill(
                label: '${bundle.completedStepsCount}/${bundle.steps.length}',
                color: ZenColors.teal,
                icon: Icons.check_rounded,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '5-pose guided challenge • approx. 5-6 min',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: ZenDecor.pillRadius,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: ZenColors.surface2,
              valueColor: const AlwaysStoppedAnimation<Color>(ZenColors.teal),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _pill(
                label: 'Done ${bundle.completedStepsCount}',
                color: ZenColors.success,
              ),
              const SizedBox(width: 8),
              _pill(
                label:
                    'Skipped ${bundle.skippedStepsCount}/${DailyChallengeService.maxSkips}',
                color: ZenColors.warning,
              ),
              const SizedBox(width: 8),
              _pill(
                label: 'Left ${bundle.pendingStepsCount}',
                color: ZenColors.textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill({required String label, required Color color, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: ZenDecor.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              fontFamily: 'Manrope',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepCard(DailyChallengeBundle bundle) {
    final step = _currentStep;
    if (step == null) {
      return Container(
        decoration: ZenDecor.elevatedCard(),
        padding: const EdgeInsets.all(16),
        child: Text(
          'No pending steps.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Container(
      decoration: ZenDecor.elevatedCard(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${step.stepIndex + 1} of ${bundle.steps.length}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ZenColors.teal,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(step.poseName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 14,
                color: ZenColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                'Hold 45s at ≥70% pose match',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_transitionRemaining > 0) ...[
            // Countdown display
            Center(
              child: Column(
                children: [
                  Text(
                    '$_transitionRemaining',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      color: ZenColors.teal,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Starting in...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _transitionTimer?.cancel();
                      setState(() => _transitionRemaining = 0);
                      unawaited(_launchPoseEvaluator());
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Start now'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _skipCurrentStep,
                    icon: const Icon(Icons.skip_next_rounded, size: 18),
                    label: const Text('Skip'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ZenColors.earth,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _launching ? null : _launchPoseEvaluator,
                icon: const Icon(Icons.videocam_rounded, size: 18),
                label: const Text('Open Pose Evaluator'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepList(DailyChallengeBundle bundle) {
    return Container(
      decoration: ZenDecor.elevatedCard(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ZenSectionHeader(title: 'Sequence', subtitle: 'All 5 steps'),
          const SizedBox(height: 12),
          ...bundle.steps.map((step) {
            final isActive = step.stepIndex == _currentStepIndex;
            final status = step.status;
            final icon = switch (status) {
              DailyChallengeStepStatus.completed => Icons.check_circle_rounded,
              DailyChallengeStepStatus.skipped => Icons.skip_next_rounded,
              DailyChallengeStepStatus.pending => Icons.radio_button_unchecked,
            };
            final color = switch (status) {
              DailyChallengeStepStatus.completed => ZenColors.success,
              DailyChallengeStepStatus.skipped => ZenColors.warning,
              DailyChallengeStepStatus.pending =>
                isActive ? ZenColors.teal : ZenColors.textMuted,
            };

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: isActive
                    ? ZenColors.teal.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: ZenDecor.chipRadius,
                border: Border.all(
                  color: isActive
                      ? ZenColors.teal.withValues(alpha: 0.30)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${step.stepIndex + 1}. ${step.poseName}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: status == DailyChallengeStepStatus.completed
                            ? ZenColors.textMuted
                            : ZenColors.textPrimary,
                        fontWeight: isActive ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                  if (status != DailyChallengeStepStatus.pending)
                    Text(
                      status.dbValue,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
