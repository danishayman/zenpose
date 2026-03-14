import 'package:flutter/material.dart';

import '../models/daily_challenge.dart';
import '../models/user_stats.dart';
import '../services/daily_challenge_service.dart';
import '../services/database_service.dart';
import '../theme/zen_theme.dart';
import '../widgets/zen_loading_shimmer.dart';
import '../widgets/zen_section_header.dart';
import '../widgets/zen_stat_card.dart';
import 'daily_challenge_runner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DailyChallengeService _challengeService = DailyChallengeService();
  final DatabaseService _databaseService = DatabaseService.instance;

  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final challenge = await _challengeService.getOrCreateTodayChallenge();
    final stats = await _databaseService.getUserStats();
    final badgeCount = await _databaseService.getUnlockedBadgeCount();
    return _HomeData(
      challenge: challenge,
      userStats: stats,
      badgeCount: badgeCount,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _openChallenge(_HomeData data) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailyChallengeRunnerScreen(
          dateKey: data.challenge.challenge.dateKey,
        ),
      ),
    );
    await _refresh();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ZenPageLoadingShimmer();
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _buildError(snapshot.error);
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            color: ZenColors.teal,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                _buildGreeting(),
                const SizedBox(height: 20),
                _buildChallengeHero(data),
                const SizedBox(height: 20),
                _buildQuickStats(data),
                const SizedBox(height: 24),
                _buildTodaySequence(data.challenge),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: ZenColors.textMuted),
            const SizedBox(height: 16),
            Text(
              'Failed to load home',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton(onPressed: _refresh, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_greeting()} 🌿',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ZenColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'ZenPose',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 2),
        Text(
          'Move mindfully, breathe deeply.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildChallengeHero(_HomeData data) {
    final challenge = data.challenge;
    final isCompleted = challenge.challenge.isCompleted;
    final progress = challenge.steps.isEmpty
        ? 0.0
        : challenge.completedStepsCount / challenge.steps.length;

    final statusLabel = isCompleted
        ? 'Completed ✓'
        : challenge.hasStarted
            ? 'Resume Challenge'
            : 'Start Challenge';

    return Container(
      decoration: ZenDecor.heroGradient(),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: ZenDecor.pillRadius,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded,
                        size: 13, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      "Today's Challenge",
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            isCompleted
                ? 'Challenge complete!'
                : '${challenge.steps.length} poses • 45s each',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isCompleted
                ? 'You nailed today\'s flow. Great consistency!'
                : '${challenge.completedStepsCount} of ${challenge.steps.length} poses done',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
          const SizedBox(height: 18),
          // Progress bar
          ClipRRect(
            borderRadius: ZenDecor.pillRadius,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _openChallenge(data),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: ZenColors.forest,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(statusLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(_HomeData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ZenSectionHeader(title: 'Your Stats'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ZenStatCard(
                label: 'Day Streak',
                value: '${data.userStats.currentStreak}',
                icon: Icons.local_fire_department_rounded,
                accentColor: ZenColors.warning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ZenStatCard(
                label: 'Total XP',
                value: '${data.userStats.totalXp}',
                icon: Icons.star_rounded,
                accentColor: ZenColors.teal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ZenStatCard(
                label: 'Badges',
                value: '${data.badgeCount}',
                icon: Icons.workspace_premium_rounded,
                accentColor: ZenColors.forest,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTodaySequence(DailyChallengeBundle bundle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ZenSectionHeader(
          title: "Today's Sequence",
          subtitle: 'Your guided pose flow',
        ),
        const SizedBox(height: 12),
        Container(
          decoration: ZenDecor.elevatedCard(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: bundle.challenge.sequence.asMap().entries.map((entry) {
              final index = entry.key;
              final poseName = entry.value;
              final isDone = index < bundle.completedStepsCount;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? ZenColors.teal
                            : ZenColors.sage100,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check_rounded,
                                size: 15, color: Colors.white)
                            : Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: ZenColors.forest,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        poseName,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isDone
                                  ? ZenColors.textMuted
                                  : ZenColors.textPrimary,
                            ),
                      ),
                    ),
                    if (isDone)
                      const Icon(Icons.check_circle_rounded,
                          size: 16, color: ZenColors.teal),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _HomeData {
  final DailyChallengeBundle challenge;
  final UserStats userStats;
  final int badgeCount;

  const _HomeData({
    required this.challenge,
    required this.userStats,
    required this.badgeCount,
  });
}
