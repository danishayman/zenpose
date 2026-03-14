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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Today\'s Challenge'),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: ZenDecor.gradientBackdrop(),
        child: _loading || bundle == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _buildHeaderCard(bundle),
                  const SizedBox(height: 14),
                  _buildStepCard(bundle),
                  const SizedBox(height: 14),
                  _buildStepList(bundle),
                ],
              ),
      ),
    );
  }

  Widget _buildHeaderCard(DailyChallengeBundle bundle) {
    final remaining = bundle.pendingStepsCount;
    return Container(
      decoration: ZenDecor.softCard(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Flow', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '5-pose guided challenge • about 5-6 minutes',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _pill(
                label: 'Done ${bundle.completedStepsCount}',
                color: ZenColors.sage,
              ),
              const SizedBox(width: 8),
              _pill(
                label:
                    'Skipped ${bundle.skippedStepsCount}/${DailyChallengeService.maxSkips}',
                color: ZenColors.earth,
              ),
              const SizedBox(width: 8),
              _pill(label: 'Remaining $remaining', color: ZenColors.forest),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildStepCard(DailyChallengeBundle bundle) {
    final step = _currentStep;
    if (step == null) {
      return Container(
        decoration: ZenDecor.softCard(),
        padding: const EdgeInsets.all(16),
        child: const Text('No pending steps.'),
      );
    }

    return Container(
      decoration: ZenDecor.softCard(color: Colors.white),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${step.stepIndex + 1} of ${bundle.steps.length}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: ZenColors.earth,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(step.poseName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Hold for 45s at >=70% score',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          if (_transitionRemaining > 0) ...[
            Text(
              'Starting in $_transitionRemaining s',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: ZenColors.forest,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _transitionTimer?.cancel();
                      setState(() => _transitionRemaining = 0);
                      unawaited(_launchPoseEvaluator());
                    },
                    child: const Text('Start now'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _skipCurrentStep,
                    child: const Text('Skip'),
                  ),
                ),
              ],
            ),
          ] else ...[
            ElevatedButton(
              onPressed: _launching ? null : _launchPoseEvaluator,
              child: const Text('Open Pose Evaluator'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepList(DailyChallengeBundle bundle) {
    return Container(
      decoration: ZenDecor.softCard(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Challenge Steps',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...bundle.steps.map((step) {
            final isActive = step.stepIndex == _currentStepIndex;
            final status = step.status;
            final icon = switch (status) {
              DailyChallengeStepStatus.completed => Icons.check_circle,
              DailyChallengeStepStatus.skipped => Icons.skip_next_rounded,
              DailyChallengeStepStatus.pending => Icons.radio_button_unchecked,
            };
            final color = switch (status) {
              DailyChallengeStepStatus.completed => ZenColors.forest,
              DailyChallengeStepStatus.skipped => ZenColors.earth,
              DailyChallengeStepStatus.pending => ZenColors.sage,
            };
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isActive
                    ? ZenColors.clay.withValues(alpha: 0.22)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${step.stepIndex + 1}. ${step.poseName}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  Text(
                    status.dbValue,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
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
