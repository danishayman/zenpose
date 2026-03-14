import 'package:flutter/material.dart';

import '../models/daily_challenge.dart';
import '../models/user_stats.dart';
import '../services/daily_challenge_service.dart';
import '../services/database_service.dart';
import '../theme/zen_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load home: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
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
                Text(
                  'ZenPose',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  'Move mindfully, breathe deeply.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: ZenColors.earth),
                ),
                const SizedBox(height: 16),
                _buildChallengeHero(data),
                const SizedBox(height: 14),
                _buildSnapshotCard(data),
                const SizedBox(height: 14),
                _buildTodayPoses(data.challenge),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChallengeHero(_HomeData data) {
    final challenge = data.challenge;
    final status = challenge.challenge.isCompleted
        ? 'Completed'
        : challenge.hasStarted
        ? 'Resume Challenge'
        : 'Start Challenge';

    final subtitle = challenge.challenge.isCompleted
        ? 'You completed today\'s flow. Great consistency.'
        : '5 poses • 45s each • one skip allowed';

    return Container(
      decoration: ZenDecor.softCard(color: Colors.white),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Challenge',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: challenge.steps.isEmpty
                ? 0
                : challenge.completedStepsCount / challenge.steps.length,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: ZenColors.clay.withValues(alpha: 0.35),
            valueColor: const AlwaysStoppedAnimation<Color>(ZenColors.forest),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _openChallenge(data),
              child: Text(status),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotCard(_HomeData data) {
    return Container(
      decoration: ZenDecor.softCard(),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: _statTile('Streak', '${data.userStats.currentStreak} days'),
          ),
          const SizedBox(width: 8),
          Expanded(child: _statTile('XP', '${data.userStats.totalXp}')),
          const SizedBox(width: 8),
          Expanded(child: _statTile('Badges', '${data.badgeCount}')),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: ZenColors.earth,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: ZenColors.bark,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayPoses(DailyChallengeBundle bundle) {
    return Container(
      decoration: ZenDecor.softCard(color: Colors.white),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Pose Sequence',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...bundle.challenge.sequence.asMap().entries.map((entry) {
            final index = entry.key;
            final pose = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: ZenColors.sage.withValues(alpha: 0.2),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ZenColors.forest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(pose, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            );
          }),
        ],
      ),
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
