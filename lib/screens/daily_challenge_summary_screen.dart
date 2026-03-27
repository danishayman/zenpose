import 'package:flutter/material.dart';

import '../models/unlocked_badge.dart';
import '../theme/zen_theme.dart';
import '../widgets/zen_section_header.dart';

typedef DailySummaryCompleteHandler = Future<void> Function(String feedback);

class DailyChallengeSummaryScreen extends StatefulWidget {
  final String dayLabel;
  final int completedSteps;
  final int skippedSteps;
  final int totalSteps;
  final int xpEarned;
  final Duration elapsed;
  final List<UnlockedBadge> unlockedBadges;
  final double? averageScore;
  final double? calories;
  final String? initialFeedback;
  final DailySummaryCompleteHandler onComplete;

  const DailyChallengeSummaryScreen({
    super.key,
    required this.dayLabel,
    required this.completedSteps,
    required this.skippedSteps,
    required this.totalSteps,
    required this.xpEarned,
    required this.elapsed,
    required this.unlockedBadges,
    required this.averageScore,
    required this.calories,
    required this.onComplete,
    this.initialFeedback,
  });

  @override
  State<DailyChallengeSummaryScreen> createState() =>
      _DailyChallengeSummaryScreenState();
}

class _DailyChallengeSummaryScreenState extends State<DailyChallengeSummaryScreen> {
  late String _selectedFeedback;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedFeedback = widget.initialFeedback ?? 'just_right';
  }

  @override
  Widget build(BuildContext context) {
    final minutes = widget.elapsed.inMinutes;
    final seconds = widget.elapsed.inSeconds % 60;
    final durationLabel = '$minutes:${seconds.toString().padLeft(2, '0')}';
    final completionRate = widget.totalSteps == 0
        ? 0
        : (widget.completedSteps / widget.totalSteps * 100).round();
    final avgScoreLabel = widget.averageScore == null
        ? '-'
        : '${widget.averageScore!.toStringAsFixed(1)}%';
    final calorieLabel = widget.calories == null
        ? '-'
        : widget.calories!.toStringAsFixed(1);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: ZenDecor.gradientBackdrop(),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _buildHeroCard(completionRate),
              const SizedBox(height: 16),
              _buildMetricsCard(
                exercisesLabel: '${widget.completedSteps}/${widget.totalSteps}',
                calorieLabel: calorieLabel,
                timeLabel: durationLabel,
                avgScoreLabel: avgScoreLabel,
              ),
              const SizedBox(height: 16),
              _buildFeedbackCard(context),
              const SizedBox(height: 16),
              _buildBadgesCard(context),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _completeAndReturnHome,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.home_rounded),
                  label: Text(_saving ? 'Saving...' : 'Back to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(int completionRate) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ZenColors.forest, ZenColors.teal],
        ),
        borderRadius: ZenDecor.cardRadius,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.dayLabel,
            style: const TextStyle(
              fontFamily: 'Manrope',
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Great session completed!",
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 34,
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                '$completionRate%',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 42,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'completion',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCard({
    required String exercisesLabel,
    required String calorieLabel,
    required String timeLabel,
    required String avgScoreLabel,
  }) {
    return Container(
      decoration: ZenDecor.elevatedCard(),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Row(
        children: [
          _metricCell(label: 'Exercises', value: exercisesLabel),
          _divider(),
          _metricCell(label: 'Calories', value: calorieLabel),
          _divider(),
          _metricCell(label: 'Time', value: timeLabel),
          _divider(),
          _metricCell(label: 'Avg Score', value: avgScoreLabel),
        ],
      ),
    );
  }

  Widget _metricCell({required String label, required String value}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Manrope',
              color: ZenColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Manrope',
              color: ZenColors.teal,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 46,
      color: ZenColors.surface2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildFeedbackCard(BuildContext context) {
    return Container(
      decoration: ZenDecor.elevatedCard(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ZenSectionHeader(title: 'How do you feel?'),
          const SizedBox(height: 4),
          Text(
            'Your feedback helps us improve your next daily workout.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _feedbackChoice(
                key: 'too_hard',
                emoji: '😮‍💨',
                label: 'Too hard',
              ),
              const SizedBox(width: 8),
              _feedbackChoice(
                key: 'just_right',
                emoji: '🙂',
                label: 'Just right',
              ),
              const SizedBox(width: 8),
              _feedbackChoice(
                key: 'too_easy',
                emoji: '😌',
                label: 'Too easy',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _feedbackChoice({
    required String key,
    required String emoji,
    required String label,
  }) {
    final selected = _selectedFeedback == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFeedback = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? ZenColors.teal100 : ZenColors.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? ZenColors.teal : ZenColors.surface2,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  color: selected ? ZenColors.forest : ZenColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgesCard(BuildContext context) {
    return Container(
      decoration: ZenDecor.elevatedCard(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ZenSectionHeader(
            title: 'Unlocked Badges',
            subtitle: 'Earned this session',
          ),
          const SizedBox(height: 12),
          if (widget.unlockedBadges.isEmpty)
            Text(
              'No new badges this session. Keep going!',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...widget.unlockedBadges.map(
              (badge) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: ZenColors.sage100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: ZenColors.forest,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        badge.name,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _completeAndReturnHome() async {
    setState(() => _saving = true);
    try {
      await widget.onComplete(_selectedFeedback);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
