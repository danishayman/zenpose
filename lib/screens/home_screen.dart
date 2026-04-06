import 'package:flutter/material.dart';

import '../models/daily_challenge.dart';
import '../models/pose_template.dart';
import '../models/session_history_entry.dart';
import '../models/user_stats.dart';
import '../services/auth_service.dart';
import '../services/daily_challenge_service.dart';
import '../services/database_service.dart';
import '../services/pose_demo_asset_resolver.dart';
import '../services/pose_template_service.dart';
import '../theme/zen_theme.dart';
import '../widgets/zen_loading_shimmer.dart';
import '../widgets/zen_section_header.dart';
import '../widgets/zen_stat_card.dart';
import 'daily_challenge_runner_screen.dart';
import 'streak_calendar_screen.dart';

class HomeScreen extends StatefulWidget {
  final Future<DailyChallengeBundle> Function()? loadTodayChallenge;
  final Future<UserStats> Function()? loadUserStats;
  final Future<int> Function()? loadBadgeCount;
  final Future<List<SessionHistoryEntry>> Function()? loadSessionHistory;
  final Future<List<PoseTemplate>> Function()? loadPoseTemplates;
  final WidgetBuilder? streakCalendarBuilder;

  const HomeScreen({
    super.key,
    this.loadTodayChallenge,
    this.loadUserStats,
    this.loadBadgeCount,
    this.loadSessionHistory,
    this.loadPoseTemplates,
    this.streakCalendarBuilder,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<String> _monthNamesShort = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final DailyChallengeService _challengeService = DailyChallengeService();
  final DatabaseService _databaseService = DatabaseService.instance;
  final PoseTemplateService _poseTemplateService = PoseTemplateService();
  final AuthService _authService = AuthService.instance;

  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final challenge =
        await (widget.loadTodayChallenge?.call() ??
            _challengeService.getOrCreateTodayChallenge());
    final stats =
        await (widget.loadUserStats?.call() ?? _databaseService.getUserStats());
    final badgeCount =
        await (widget.loadBadgeCount?.call() ??
            _databaseService.getUnlockedBadgeCount());
    final sessionHistory =
        await (widget.loadSessionHistory?.call() ??
            _databaseService.getHomeSessionHistory());

    List<PoseTemplate> templates;
    try {
      templates =
          await (widget.loadPoseTemplates?.call() ??
              _poseTemplateService.loadTemplates());
    } catch (_) {
      templates = const <PoseTemplate>[];
    }

    return _HomeData(
      challenge: challenge,
      userStats: stats,
      badgeCount: badgeCount,
      actorName: _resolveActorName(),
      sessionHistory: List<SessionHistoryEntry>.from(sessionHistory)
        ..sort((a, b) => b.activityAt.compareTo(a.activityAt)),
      templateLookup: _buildTemplateLookup(templates),
    );
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

  PoseTemplate? _templateForPose(
    Map<String, PoseTemplate> lookup,
    String poseName,
  ) {
    return lookup[_normalizePoseKey(poseName)];
  }

  String _resolveActorName() {
    final auth = _authService.authState.value;
    final display = auth.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final email = auth.email?.trim();
    if (email != null && email.isNotEmpty) {
      final localPart = email.split('@').first.trim();
      if (localPart.isNotEmpty) return localPart;
    }
    return 'ZenPose User';
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

  Future<void> _openStreakCalendar() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            widget.streakCalendarBuilder ?? (_) => const StreakCalendarScreen(),
      ),
    );
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
                _buildSessionHistory(data),
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
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: ZenColors.textMuted,
            ),
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
        Text('ZenPose', style: Theme.of(context).textTheme.headlineLarge),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: ZenDecor.pillRadius,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
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
          ClipRRect(
            borderRadius: ZenDecor.pillRadius,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
                onTap: _openStreakCalendar,
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

  Widget _buildSessionHistory(_HomeData data) {
    final sessions = data.sessionHistory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ZenSectionHeader(
          title: 'Session History',
          subtitle: 'Your workout log and pose-by-pose scores',
        ),
        const SizedBox(height: 12),
        if (sessions.isEmpty)
          Container(
            decoration: ZenDecor.elevatedCard(),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No session history yet. Complete your first practice to start tracking.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          Column(
            children: sessions
                .map(
                  (session) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildSessionCard(data, session),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }

  Widget _buildSessionCard(_HomeData data, SessionHistoryEntry session) {
    final isChallenge = session.kind == SessionHistoryKind.challenge;
    final title = isChallenge ? 'Daily Yoga Flow' : 'Practice Session';
    final subtitle = isChallenge
        ? session.completed
              ? '${session.completedPoseCount}/${session.poseCount} poses completed'
              : '${session.completedPoseCount}/${session.poseCount} poses done'
        : (session.isLegacyPractice
              ? 'Legacy practice record'
              : 'Focused single-pose practice');
    final statusLabel = session.completed ? 'Completed' : 'In Progress';
    final statusBg = session.completed
        ? ZenColors.successLight
        : ZenColors.warningLight;
    final statusFg = session.completed ? ZenColors.success : ZenColors.warning;
    final avatarInitial = data.actorName.isEmpty
        ? 'Z'
        : data.actorName.substring(0, 1).toUpperCase();

    return Container(
      decoration: ZenDecor.elevatedCard(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[ZenColors.forest, ZenColors.teal],
                  ),
                ),
                child: Center(
                  child: Text(
                    avatarInitial,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.actorName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      _formatHistoryTime(session.activityAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: ZenDecor.pillRadius,
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMetric(
                label: 'Duration',
                value: _formatDuration(session.durationSeconds),
              ),
              _buildMetric(
                label: 'Avg Score',
                value: session.averageScore == null
                    ? '-'
                    : '${session.averageScore!.toStringAsFixed(0)}%',
              ),
              _buildMetric(label: 'Poses', value: '${session.poseCount}'),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: ZenColors.sage200.withValues(alpha: 0.7), height: 1),
          const SizedBox(height: 12),
          _buildPoseGrid(data.templateLookup, session),
        ],
      ),
    );
  }

  Widget _buildMetric({required String label, required String value}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ZenColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: ZenColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoseGrid(
    Map<String, PoseTemplate> lookup,
    SessionHistoryEntry session,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: session.poses.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.75,
      ),
      itemBuilder: (context, index) {
        final pose = session.poses[index];
        final template = _templateForPose(lookup, pose.poseName);
        return Container(
          decoration: BoxDecoration(
            color: ZenColors.surface0,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: ZenColors.sage200.withValues(alpha: 0.55),
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPoseThumbnail(template),
              const SizedBox(height: 6),
              Text(
                pose.poseName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ZenColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _poseStatusLabel(pose),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _poseStatusColor(pose.status),
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPoseThumbnail(PoseTemplate? template) {
    final fallback = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[ZenColors.sage100, ZenColors.teal100],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.self_improvement_rounded,
          size: 22,
          color: ZenColors.forest,
        ),
      ),
    );
    if (template == null) {
      return Expanded(child: fallback);
    }
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          PoseDemoAssetResolver.thumbnailPathForTemplate(template),
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }

  String _poseStatusLabel(SessionHistoryPoseEntry pose) {
    switch (pose.status) {
      case SessionHistoryPoseStatus.skipped:
        return 'Skipped';
      case SessionHistoryPoseStatus.pending:
        return 'Pending';
      case SessionHistoryPoseStatus.completed:
        if (pose.bestScore != null) {
          return '${pose.bestScore!.toStringAsFixed(0)}%';
        }
        return 'Completed';
    }
  }

  Color _poseStatusColor(SessionHistoryPoseStatus status) {
    switch (status) {
      case SessionHistoryPoseStatus.completed:
        return ZenColors.success;
      case SessionHistoryPoseStatus.skipped:
        return ZenColors.warning;
      case SessionHistoryPoseStatus.pending:
        return ZenColors.textMuted;
    }
  }

  String _formatDuration(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    if (safe >= 3600) {
      final hours = safe ~/ 3600;
      final mins = (safe % 3600) ~/ 60;
      if (mins == 0) return '${hours}h';
      return '${hours}h ${mins}m';
    }
    if (safe >= 60) {
      final mins = safe ~/ 60;
      final secs = safe % 60;
      if (secs == 0) return '${mins}m';
      return '${mins}m ${secs}s';
    }
    return '${safe}s';
  }

  String _formatHistoryTime(DateTime timestamp) {
    final local = timestamp.toLocal();
    final now = DateTime.now();
    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day;
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final timePart = '$hour12:$minute $period';
    if (isToday) return 'Today at $timePart';
    if (isYesterday) return 'Yesterday at $timePart';
    final month = _monthNamesShort[local.month - 1];
    return '$month ${local.day}, ${local.year} • $timePart';
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
                        color: isDone ? ZenColors.teal : ZenColors.sage100,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(
                                Icons.check_rounded,
                                size: 15,
                                color: Colors.white,
                              )
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
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: ZenColors.teal,
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
}

class _HomeData {
  final DailyChallengeBundle challenge;
  final UserStats userStats;
  final int badgeCount;
  final String actorName;
  final List<SessionHistoryEntry> sessionHistory;
  final Map<String, PoseTemplate> templateLookup;

  const _HomeData({
    required this.challenge,
    required this.userStats,
    required this.badgeCount,
    required this.actorName,
    required this.sessionHistory,
    required this.templateLookup,
  });
}
