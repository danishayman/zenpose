import 'package:flutter/material.dart';

import '../models/profile_challenge_models.dart';
import '../services/profile_challenge_service.dart';
import '../theme/zen_theme.dart';
import '../widgets/rank_up_dialog.dart';

class AllChallengesScreen extends StatefulWidget {
  final String monthKey;
  final ProfileChallengeService challengeService;
  final DateTime Function()? nowBuilder;

  const AllChallengesScreen({
    super.key,
    required this.monthKey,
    required this.challengeService,
    this.nowBuilder,
  });

  @override
  State<AllChallengesScreen> createState() => _AllChallengesScreenState();
}

class _AllChallengesScreenState extends State<AllChallengesScreen> {
  late Future<List<ChallengeProgressSnapshot>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ChallengeProgressSnapshot>> _load() {
    return widget.challengeService.loadMonthlyChallenges(
      monthKey: widget.monthKey,
      now: widget.nowBuilder?.call() ?? DateTime.now(),
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _handleAction(ChallengeProgressSnapshot snapshot) async {
    switch (snapshot.status) {
      case ChallengeLifecycleStatus.notJoined:
        await widget.challengeService.joinChallenge(
          monthKey: snapshot.monthKey,
          challengeId: snapshot.definition.challengeId,
          now: widget.nowBuilder?.call() ?? DateTime.now(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined ${snapshot.definition.title}')),
        );
        await _refresh();
        return;
      case ChallengeLifecycleStatus.claimable:
        final result = await widget.challengeService.claimChallengeReward(
          monthKey: snapshot.monthKey,
          challengeId: snapshot.definition.challengeId,
          now: widget.nowBuilder?.call() ?? DateTime.now(),
        );
        if (!mounted) return;
        await RankUpDialog.showIfRankedUp(
          context,
          didRankUp: result.didRankUp,
          rankAfter: result.rankAfter,
          xpAfter: result.xpAfter,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.applied
                  ? '+${result.xpGranted} XP • ${result.badgeLabel}'
                  : result.message,
            ),
          ),
        );
        await _refresh();
        return;
      case ChallengeLifecycleStatus.joined:
      case ChallengeLifecycleStatus.completed:
      case ChallengeLifecycleStatus.ended:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Challenges')),
      body: Container(
        decoration: ZenDecor.gradientBackdrop(),
        child: FutureBuilder<List<ChallengeProgressSnapshot>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final challenges =
                snapshot.data ?? const <ChallengeProgressSnapshot>[];
            return RefreshIndicator(
              onRefresh: _refresh,
              color: ZenColors.teal,
              child: GridView.builder(
                key: const Key('all-challenges-grid'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                itemCount: challenges.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 268,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemBuilder: (context, index) {
                  final challenge = challenges[index];
                  return _ChallengeCard(
                    snapshot: challenge,
                    onAction: () => _handleAction(challenge),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final ChallengeProgressSnapshot snapshot;
  final VoidCallback onAction;

  const _ChallengeCard({required this.snapshot, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final isActionEnabled =
        snapshot.status == ChallengeLifecycleStatus.notJoined ||
        snapshot.status == ChallengeLifecycleStatus.claimable;
    final accent = _accentColor(snapshot.definition.metricType);

    return Container(
      decoration: BoxDecoration(
        borderRadius: ZenDecor.cardRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            ZenColors.surface1,
            ZenColors.surface1.withValues(alpha: 0.96),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: ZenColors.bark.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _metricIcon(snapshot.definition.metricType),
              color: accent,
              size: 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            snapshot.definition.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(height: 1.2),
          ),
          const SizedBox(height: 6),
          Text(
            snapshot.definition.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Text(
            snapshot.periodLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: ZenDecor.pillRadius,
            child: LinearProgressIndicator(
              value: snapshot.progressRatio,
              minHeight: 6,
              backgroundColor: ZenColors.surface2,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            snapshot.progressLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ZenColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (snapshot.status == ChallengeLifecycleStatus.completed &&
              snapshot.rewardBadgeLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              'Badge: ${snapshot.rewardBadgeLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ZenColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: Key('challenge-action-${snapshot.definition.challengeId}'),
              onPressed: isActionEnabled ? onAction : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isActionEnabled
                    ? ZenColors.forest
                    : ZenColors.sage200,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(40),
              ),
              child: Text(snapshot.buttonLabel),
            ),
          ),
        ],
      ),
    );
  }

  IconData _metricIcon(ChallengeMetricType type) {
    return switch (type) {
      ChallengeMetricType.sessions => Icons.self_improvement_rounded,
      ChallengeMetricType.minutes => Icons.schedule_rounded,
      ChallengeMetricType.scoreCount => Icons.track_changes_rounded,
    };
  }

  Color _accentColor(ChallengeMetricType type) {
    return switch (type) {
      ChallengeMetricType.sessions => ZenColors.teal,
      ChallengeMetricType.minutes => ZenColors.warning,
      ChallengeMetricType.scoreCount => ZenColors.forest,
    };
  }
}
