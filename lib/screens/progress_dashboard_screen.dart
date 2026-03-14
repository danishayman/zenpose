import 'package:flutter/material.dart';

import '../models/pose_result.dart';
import '../models/unlocked_badge.dart';
import '../models/user_stats.dart';
import '../services/database_service.dart';
import '../theme/zen_theme.dart';

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
    final latestUnlockedBadges = await _databaseService.getLatestUnlockedBadges(
      limit: 5,
    );

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
      child: FutureBuilder<_ProgressData>(
        future: _progressFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Text(
                'Failed to load progress: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _header(context),
                const SizedBox(height: 12),
                _statsOverview(context, data),
                const SizedBox(height: 12),
                _gamification(context, data),
                const SizedBox(height: 12),
                _badges(context, data),
                const SizedBox(height: 12),
                _bestScores(context, data),
                const SizedBox(height: 12),
                _attempts(context, data),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      decoration: ZenDecor.softCard(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progress', style: Theme.of(context).textTheme.headlineMedium),
          Text(
            'Your mindful consistency and alignment trend',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: ZenColors.earth),
          ),
        ],
      ),
    );
  }

  Widget _statsOverview(BuildContext context, _ProgressData data) {
    final average = data.averageScore == null
        ? 'N/A'
        : '${data.averageScore!.toStringAsFixed(1)}%';
    return _sectionCard(
      context: context,
      title: 'Overall',
      child: Row(
        children: [
          Expanded(child: _miniStat('Sessions', '${data.totalSessions}')),
          const SizedBox(width: 8),
          Expanded(child: _miniStat('Completed', '${data.totalCompleted}')),
          const SizedBox(width: 8),
          Expanded(child: _miniStat('Avg', average)),
        ],
      ),
    );
  }

  Widget _gamification(BuildContext context, _ProgressData data) {
    return _sectionCard(
      context: context,
      title: 'Gamification',
      child: Row(
        children: [
          Expanded(
            child: _miniStat('Streak', '${data.userStats.currentStreak}'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _miniStat('Longest', '${data.userStats.longestStreak}'),
          ),
          const SizedBox(width: 8),
          Expanded(child: _miniStat('XP', '${data.userStats.totalXp}')),
          const SizedBox(width: 8),
          Expanded(child: _miniStat('Badges', '${data.unlockedBadgeCount}')),
        ],
      ),
    );
  }

  Widget _badges(BuildContext context, _ProgressData data) {
    return _sectionCard(
      context: context,
      title: 'Latest Badges',
      child: data.latestUnlockedBadges.isEmpty
          ? _empty('No badges unlocked yet.')
          : Column(
              children: data.latestUnlockedBadges.map((badge) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium,
                        color: ZenColors.forest,
                      ),
                      const SizedBox(width: 8),
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
    );
  }

  Widget _bestScores(BuildContext context, _ProgressData data) {
    if (data.bestScores.isEmpty) {
      return _sectionCard(
        context: context,
        title: 'Best Scores',
        child: _empty('Complete sessions to populate best scores.'),
      );
    }
    final entries = data.bestScores.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return _sectionCard(
      context: context,
      title: 'Best Scores',
      child: Column(
        children: entries.map((entry) {
          final score = entry.value ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text(entry.key)),
                    Text('${score.toStringAsFixed(0)}%'),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: (score / 100).clamp(0.0, 1.0),
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(99),
                  backgroundColor: ZenColors.clay.withValues(alpha: 0.35),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    ZenColors.sage,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _attempts(BuildContext context, _ProgressData data) {
    return _sectionCard(
      context: context,
      title: 'Recent Attempts',
      child: data.recentAttempts.isEmpty
          ? _empty('No attempts yet.')
          : Column(
              children: data.recentAttempts.map((result) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          result.poseName,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      Text('${result.bestScore.toStringAsFixed(0)}%'),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _sectionCard({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: ZenDecor.softCard(color: Colors.white),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ZenColors.sand,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: ZenColors.earth,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _empty(String message) =>
      Text(message, style: const TextStyle(color: ZenColors.earth));
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
