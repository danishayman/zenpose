import 'package:flutter/material.dart';

import '../models/pose_result.dart';
import '../models/unlocked_badge.dart';
import '../models/user_stats.dart';
import '../services/database_service.dart';
import '../theme/zen_theme.dart';
import '../widgets/zen_loading_shimmer.dart';
import '../widgets/zen_section_header.dart';
import '../widgets/zen_stat_card.dart';

class ProgressDashboardScreen extends StatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  State<ProgressDashboardScreen> createState() =>
      _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  late Future<_ProgressData> _progressFuture;

  @override
  void initState() {
    super.initState();
    _progressFuture = _loadProgress();
  }

  Future<_ProgressData> _loadProgress() async {
    final results = await _databaseService.getAllResults();
    final poseNames = results.map((r) => r.poseName).toSet().toList()..sort();
    final bestScoreEntries = await Future.wait(
      poseNames.map((poseName) async {
        final score = await _databaseService.getBestScoreForPose(poseName);
        return MapEntry(poseName, score);
      }),
    );

    final bestScores = <String, double?>{
      for (final entry in bestScoreEntries) entry.key: entry.value,
    };
    final totalSessions = results.length;
    final totalCompleted = results.where((r) => r.completed).length;
    final averageScore = totalSessions == 0
        ? null
        : results.map((r) => r.bestScore).reduce((a, b) => a + b) /
              totalSessions;
    final recentAttempts = results.take(8).toList();
    final userStats = await _databaseService.getUserStats();
    final unlockedBadgeCount = await _databaseService.getUnlockedBadgeCount();
    final latestUnlockedBadges =
        await _databaseService.getLatestUnlockedBadges(limit: 5);

    return _ProgressData(
      bestScores: bestScores,
      totalSessions: totalSessions,
      totalCompleted: totalCompleted,
      averageScore: averageScore,
      recentAttempts: recentAttempts,
      userStats: userStats,
      unlockedBadgeCount: unlockedBadgeCount,
      latestUnlockedBadges: latestUnlockedBadges,
    );
  }

  Future<void> _refresh() async {
    setState(() => _progressFuture = _loadProgress());
    await _progressFuture;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: FutureBuilder<_ProgressData>(
        future: _progressFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ZenPageLoadingShimmer();
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Text('Failed to load progress: ${snapshot.error}'),
            );
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            color: ZenColors.teal,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                _header(context),
                const SizedBox(height: 20),
                _statsOverview(data),
                const SizedBox(height: 20),
                _weeklyChart(data),
                const SizedBox(height: 20),
                _gamification(data),
                const SizedBox(height: 20),
                _bestScores(data),
                const SizedBox(height: 20),
                _badges(data),
                const SizedBox(height: 20),
                _attempts(data),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Progress', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 4),
        Text(
          'Your mindful consistency and alignment trend.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _statsOverview(_ProgressData data) {
    final average = data.averageScore == null
        ? 'N/A'
        : '${data.averageScore!.toStringAsFixed(0)}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ZenSectionHeader(title: 'Overview'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ZenStatCard(
                label: 'Sessions',
                value: '${data.totalSessions}',
                icon: Icons.fitness_center_rounded,
                accentColor: ZenColors.teal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ZenStatCard(
                label: 'Completed',
                value: '${data.totalCompleted}',
                icon: Icons.check_circle_outline_rounded,
                accentColor: ZenColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ZenStatCard(
                label: 'Avg Score',
                value: average,
                icon: Icons.analytics_rounded,
                accentColor: ZenColors.forest,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _weeklyChart(_ProgressData data) {
    // Build a 7-day bar chart using CustomPainter — no extra dependency.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ZenSectionHeader(
          title: 'Weekly Activity',
          subtitle: 'Sessions per day',
        ),
        const SizedBox(height: 12),
        Container(
          decoration: ZenDecor.elevatedCard(),
          padding: const EdgeInsets.all(16),
          child: _WeeklyBarChart(results: data.recentAttempts),
        ),
      ],
    );
  }

  Widget _gamification(_ProgressData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ZenSectionHeader(title: 'Achievements'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ZenStatCard(
                label: 'Streak',
                value: '${data.userStats.currentStreak}d',
                icon: Icons.local_fire_department_rounded,
                accentColor: ZenColors.warning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ZenStatCard(
                label: 'Best Streak',
                value: '${data.userStats.longestStreak}d',
                icon: Icons.emoji_events_rounded,
                accentColor: const Color(0xFFC49A1B),
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
                value: '${data.unlockedBadgeCount}',
                icon: Icons.workspace_premium_rounded,
                accentColor: ZenColors.forest,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bestScores(_ProgressData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ZenSectionHeader(
          title: 'Best Scores',
          subtitle: 'Per pose — all time',
        ),
        const SizedBox(height: 12),
        Container(
          decoration: ZenDecor.elevatedCard(),
          padding: const EdgeInsets.all(16),
          child: data.bestScores.isEmpty
              ? _empty(context, 'Complete sessions to populate best scores.')
              : Column(
                  children: (data.bestScores.entries.toList()
                        ..sort((a, b) => a.key.compareTo(b.key)))
                      .map((entry) {
                    final score = entry.value ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                              Text(
                                '${score.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: ZenColors.teal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: ZenDecor.pillRadius,
                            child: LinearProgressIndicator(
                              value: (score / 100).clamp(0.0, 1.0),
                              minHeight: 7,
                              backgroundColor: ZenColors.surface2,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  ZenColors.teal),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _badges(_ProgressData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ZenSectionHeader(
          title: 'Recent Badges',
          subtitle: 'Latest unlocked',
        ),
        const SizedBox(height: 12),
        Container(
          decoration: ZenDecor.elevatedCard(),
          padding: const EdgeInsets.all(16),
          child: data.latestUnlockedBadges.isEmpty
              ? _empty(context, 'No badges unlocked yet.')
              : Column(
                  children: data.latestUnlockedBadges.map((badge) {
                    return Padding(
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
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _attempts(_ProgressData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ZenSectionHeader(
          title: 'Recent Attempts',
          subtitle: 'Last 8 sessions',
        ),
        const SizedBox(height: 12),
        Container(
          decoration: ZenDecor.elevatedCard(),
          padding: const EdgeInsets.all(16),
          child: data.recentAttempts.isEmpty
              ? _empty(context, 'No attempts yet. Start a session!')
              : Column(
                  children: data.recentAttempts
                      .map((result) => _attemptRow(context, result))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _attemptRow(BuildContext context, PoseResult result) {
    final score = result.bestScore;
    final color = score >= 80
        ? ZenColors.success
        : score >= 60
            ? ZenColors.warning
            : ZenColors.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: ZenDecor.chipRadius,
            ),
            child: Icon(
              result.completed
                  ? Icons.check_rounded
                  : Icons.timer_outlined,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.poseName,
                  style: Theme.of(context).textTheme.bodyLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            '${score.toStringAsFixed(0)}%',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, String message) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
      );
}

// ── Custom weekly bar chart ─────────────────────────────────────────────────

class _WeeklyBarChart extends StatelessWidget {
  final List<PoseResult> results;

  const _WeeklyBarChart({required this.results});

  @override
  Widget build(BuildContext context) {
    // Count sessions per weekday (Mon=0 … Sun=6)
    final counts = List<int>.filled(7, 0);
    final now = DateTime.now();
    for (final r in results) {
      final ts = r.timestamp ?? now;
      final diff = now.difference(ts).inDays;
      if (diff < 7) {
        final dayIndex = (ts.weekday - 1) % 7; // Mon=0
        counts[dayIndex]++;
      }
    }
    final maxCount = counts.reduce((a, b) => a > b ? a : b);

    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return SizedBox(
      height: 110,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final isToday = (DateTime.now().weekday - 1) % 7 == i;
          final fraction =
              maxCount == 0 ? 0.0 : counts[i] / maxCount;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (counts[i] > 0)
                    Text(
                      '${counts[i]}',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ZenColors.teal,
                      ),
                    ),
                  const SizedBox(height: 2),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    height: fraction == 0 ? 4 : 70 * fraction,
                    decoration: BoxDecoration(
                      color: isToday ? ZenColors.teal : ZenColors.sage,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isToday
                          ? ZenColors.teal
                          : ZenColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ProgressData {
  final Map<String, double?> bestScores;
  final int totalSessions;
  final int totalCompleted;
  final double? averageScore;
  final List<PoseResult> recentAttempts;
  final UserStats userStats;
  final int unlockedBadgeCount;
  final List<UnlockedBadge> latestUnlockedBadges;

  const _ProgressData({
    required this.bestScores,
    required this.totalSessions,
    required this.totalCompleted,
    required this.averageScore,
    required this.recentAttempts,
    required this.userStats,
    required this.unlockedBadgeCount,
    required this.latestUnlockedBadges,
  });
}
