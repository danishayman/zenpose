import 'dart:async';

import 'package:flutter/material.dart';

import '../models/daily_challenge.dart';
import '../models/daily_challenge_step.dart';
import '../models/pose_template.dart';
import '../services/daily_challenge_service.dart';
import '../theme/zen_theme.dart';
import '../widgets/pose_thumbnail_image.dart';
import 'daily_challenge_workout_flow_screen.dart';

class DailyChallengeRunnerScreen extends StatefulWidget {
  final String dateKey;
  final DailyChallengeService? challengeService;
  final Widget Function(PoseTemplate template)? evaluatorBuilder;

  const DailyChallengeRunnerScreen({
    super.key,
    required this.dateKey,
    this.challengeService,
    this.evaluatorBuilder,
  });

  @override
  State<DailyChallengeRunnerScreen> createState() =>
      _DailyChallengeRunnerScreenState();
}

class _DailyChallengeRunnerScreenState
    extends State<DailyChallengeRunnerScreen> {
  late final DailyChallengeService _challengeService;
  DailyChallengeBundle? _bundle;
  Map<String, PoseTemplate> _templateLookup = <String, PoseTemplate>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _challengeService = widget.challengeService ?? DailyChallengeService();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final bundle = await _challengeService.getOrCreateChallenge(
      dateKey: widget.dateKey,
    );
    final templates = await _challengeService.loadPoseTemplates();
    _templateLookup = _buildTemplateLookup(templates);
    _bundle = bundle;
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Map<String, PoseTemplate> _buildTemplateLookup(List<PoseTemplate> templates) {
    final lookup = <String, PoseTemplate>{};
    for (final template in templates) {
      lookup[_normalizePoseKey(template.name)] = template;
      lookup[_normalizePoseKey(template.templateKey)] = template;
    }
    return lookup;
  }

  String _normalizePoseKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  PoseTemplate? _templateForPose(String poseName) {
    return _templateLookup[_normalizePoseKey(poseName)];
  }

  Future<void> _startFlow() async {
    final bundle = _bundle;
    if (bundle == null || bundle.pendingStepsCount == 0) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailyChallengeWorkoutFlowScreen(
          dateKey: widget.dateKey,
          challengeService: _challengeService,
          evaluatorBuilder: widget.evaluatorBuilder,
        ),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  bool _isReorderEnabled(DailyChallengeBundle bundle) {
    return !bundle.challenge.isCompleted &&
        !bundle.hasStarted &&
        bundle.pendingStepsCount == bundle.steps.length;
  }

  List<DailyChallengeStep> _reindexedSteps(
    List<DailyChallengeStep> orderedSteps,
    String dateKey,
  ) {
    return <DailyChallengeStep>[
      for (var i = 0; i < orderedSteps.length; i++)
        DailyChallengeStep(
          dateKey: dateKey,
          stepIndex: i,
          poseName: orderedSteps[i].poseName,
          status: orderedSteps[i].status,
          bestScore: orderedSteps[i].bestScore,
          holdDuration: orderedSteps[i].holdDuration,
          updatedAt: orderedSteps[i].updatedAt,
        ),
    ];
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final bundle = _bundle;
    if (bundle == null || !_isReorderEnabled(bundle)) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;

    final reordered = List<DailyChallengeStep>.from(bundle.steps);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    final reorderedPoses = reordered
        .map((step) => step.poseName)
        .toList(growable: false);

    setState(() {
      _bundle = DailyChallengeBundle(
        challenge: bundle.challenge.copyWith(sequence: reorderedPoses),
        steps: _reindexedSteps(reordered, bundle.challenge.dateKey),
      );
    });

    try {
      final refreshed = await _challengeService.reorderSteps(
        dateKey: widget.dateKey,
        orderedSteps: reordered,
      );
      if (!mounted) return;
      setState(() => _bundle = refreshed);
    } catch (_) {
      if (!mounted) return;
      setState(() => _bundle = bundle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;
    return Scaffold(
      backgroundColor: ZenColors.surface0,
      appBar: AppBar(
        title: Text('DAY 1', style: Theme.of(context).textTheme.headlineMedium),
        backgroundColor: ZenColors.surface0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: Container(
        decoration: ZenDecor.gradientBackdrop(),
        child: _loading || bundle == null
            ? const Center(child: CircularProgressIndicator())
            : _buildOverview(bundle),
      ),
    );
  }

  Widget _buildOverview(DailyChallengeBundle bundle) {
    final exerciseCount = bundle.steps.length;
    final challengeHoldSeconds =
        DailyChallengeService.targetHoldSecondsForChallenge(bundle.challenge);
    final durationSecs =
        (exerciseCount * challengeHoldSeconds) +
        ((exerciseCount - 1).clamp(0, 999) *
            DailyChallengeService.challengeRestDuration.inSeconds);
    final durationMins = (durationSecs / 60).ceil();
    final isCompleted = bundle.pendingStepsCount == 0;
    final canReorder = _isReorderEnabled(bundle);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      value: '$durationMins mins',
                      label: 'Duration',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      value: '$exerciseCount',
                      label: 'Exercises',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Exercises', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              if (canReorder)
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: bundle.steps.length,
                  onReorder: (oldIndex, newIndex) {
                    unawaited(_onReorder(oldIndex, newIndex));
                  },
                  itemBuilder: (context, index) {
                    final step = bundle.steps[index];
                    return _exerciseTile(
                      step,
                      key: ValueKey(
                        'challenge-step-${step.poseName}-${step.stepIndex}',
                      ),
                      targetHoldSeconds: challengeHoldSeconds,
                      reorderHandle: ReorderableDelayedDragStartListener(
                        index: index,
                        child: const Icon(
                          Icons.drag_indicator_rounded,
                          color: ZenColors.textMuted,
                        ),
                      ),
                    );
                  },
                )
              else
                ...bundle.steps.map(
                  (step) => _exerciseTile(
                    step,
                    targetHoldSeconds: challengeHoldSeconds,
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isCompleted ? null : _startFlow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZenColors.teal,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: ZenColors.surface2,
                  disabledForegroundColor: ZenColors.textMuted,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: Text(isCompleted ? 'Completed' : 'Start'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard({required String value, required String label}) {
    return Container(
      decoration: ZenDecor.softCard(),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: ZenColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontFamily: 'Manrope')),
        ],
      ),
    );
  }

  Widget _exerciseTile(
    DailyChallengeStep step, {
    Key? key,
    required int targetHoldSeconds,
    Widget? reorderHandle,
  }) {
    final template = _templateForPose(step.poseName);
    final statusIcon = switch (step.status) {
      DailyChallengeStepStatus.completed => Icons.check_circle_rounded,
      DailyChallengeStepStatus.skipped => Icons.skip_next_rounded,
      DailyChallengeStepStatus.pending => Icons.drag_indicator_rounded,
    };
    final statusColor = switch (step.status) {
      DailyChallengeStepStatus.completed => ZenColors.success,
      DailyChallengeStepStatus.skipped => ZenColors.warning,
      DailyChallengeStepStatus.pending => ZenColors.textMuted,
    };

    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ZenColors.surface2)),
      ),
      child: Row(
        children: [
          reorderHandle ?? Icon(statusIcon, color: statusColor),
          const SizedBox(width: 10),
          if (template != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 60,
                height: 60,
                child: PoseThumbnailImage(
                  template: template,
                  height: 60,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            )
          else
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: ZenColors.surface2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.self_improvement_rounded,
                color: ZenColors.textMuted,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.poseName,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDurationClock(targetHoldSeconds),
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    color: ZenColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDurationClock(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
