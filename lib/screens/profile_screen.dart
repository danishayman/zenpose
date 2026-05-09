import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/badge_definition.dart';
import '../models/badge_progress_snapshot.dart';
import '../models/pose_result.dart';
import '../models/profile_challenge_models.dart';
import '../models/profile_activity_models.dart';
import '../models/unlocked_badge.dart';
import '../models/user_rank.dart';
import '../models/user_stats.dart';
import '../services/achievements_service.dart';
import '../services/auth_service.dart';
import '../services/badge_catalog.dart';
import '../services/database_service.dart';
import '../services/profile_challenge_service.dart';
import '../services/profile_activity_service.dart';
import '../services/user_rank_service.dart';
import '../theme/zen_theme.dart';
import '../widgets/zen_badge_medallion.dart';
import '../widgets/zen_loading_shimmer.dart';
import '../widgets/rank_up_dialog.dart';
import '../widgets/zen_section_header.dart';
import '../widgets/zen_stat_card.dart';
import 'achievements_screen.dart';
import 'all_challenges_screen.dart';
import 'streak_calendar_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Future<UserStats> Function()? loadUserStats;
  final Future<int> Function()? loadBadgeCount;
  final Future<List<PoseResult>> Function()? loadAllResults;
  final Future<List<BadgeDefinition>> Function()? loadBadgeDefinitions;
  final Future<List<UnlockedBadge>> Function()? loadUnlockedBadges;
  final Future<List<ChallengeProgressSnapshot>> Function()? loadChallenges;
  final ProfileChallengeService? challengeService;
  final WidgetBuilder? streakCalendarBuilder;
  final DateTime Function()? nowBuilder;

  const ProfileScreen({
    super.key,
    this.loadUserStats,
    this.loadBadgeCount,
    this.loadAllResults,
    this.loadBadgeDefinitions,
    this.loadUnlockedBadges,
    this.loadChallenges,
    this.challengeService,
    this.streakCalendarBuilder,
    this.nowBuilder,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  final AuthService _authService = AuthService.instance;
  final AchievementsService _achievementsService = const AchievementsService();
  late final ProfileChallengeService _profileChallengeService;
  final ProfileActivityService _activityService =
      const ProfileActivityService();

  late Future<_ProfileData> _future;
  bool _notificationsEnabled = true;
  ProfileActivityMetric _selectedMetric = ProfileActivityMetric.duration;

  @override
  void initState() {
    super.initState();
    _profileChallengeService =
        widget.challengeService ?? ProfileChallengeService();
    _authService.authState.addListener(_handleAuthStateChanged);
    _syncNotificationSettingFromAuth();
    _future = _load();
  }

  @override
  void dispose() {
    _authService.authState.removeListener(_handleAuthStateChanged);
    super.dispose();
  }

  void _handleAuthStateChanged() {
    if (!mounted) return;
    _syncNotificationSettingFromAuth();
    setState(() => _future = _load());
  }

  void _syncNotificationSettingFromAuth() {
    final auth = _authService.authState.value;
    _notificationsEnabled = auth.status == AuthStatus.authenticated;
  }

  Future<_ProfileData> _load() async {
    final stats =
        await (widget.loadUserStats?.call() ?? _databaseService.getUserStats());
    final badgeCount =
        await (widget.loadBadgeCount?.call() ??
            _databaseService.getUnlockedBadgeCount());
    final allResults =
        await (widget.loadAllResults?.call() ??
            _databaseService.getAllResults());
    final now = widget.nowBuilder?.call() ?? DateTime.now();

    List<BadgeDefinition> badgeDefinitions;
    try {
      badgeDefinitions =
          await (widget.loadBadgeDefinitions?.call() ??
              _databaseService.getBadgeDefinitions());
      if (badgeDefinitions.isEmpty) {
        badgeDefinitions = BadgeCatalog.defaultBadges;
      }
    } catch (_) {
      badgeDefinitions = BadgeCatalog.defaultBadges;
    }

    List<UnlockedBadge> unlockedBadges;
    try {
      unlockedBadges =
          await (widget.loadUnlockedBadges?.call() ??
              _databaseService.getUnlockedBadges());
    } catch (_) {
      unlockedBadges = const <UnlockedBadge>[];
    }

    final badgeSnapshots = _achievementsService.buildBadgeProgress(
      definitions: badgeDefinitions,
      unlockedBadges: unlockedBadges,
      results: allResults,
      userStats: stats,
    );
    final previewBadges = _achievementsService.previewBadges(
      badgeSnapshots,
      limit: 3,
    );

    final activitySeries = {
      for (final metric in ProfileActivityMetric.values)
        metric: _activityService.buildSeries(
          results: allResults,
          metric: metric,
          now: now,
          days: 10,
        ),
    };
    final challengeSnapshots =
        await (widget.loadChallenges?.call() ??
            _profileChallengeService.loadMonthlyChallenges(now: now));
    final challengePreview = _profileChallengeService.previewChallenges(
      challengeSnapshots,
      limit: 3,
    );
    final challengeMonthKey = ProfileChallengeService.monthKeyFromDate(now);

    final auth = _authService.authState.value;
    final displayName = _resolveDisplayName(auth);
    final rankTier = UserRankService.rankForXp(stats.totalXp);
    final email = auth.email?.trim();
    final unlockedCountFromSnapshots = badgeSnapshots
        .where((badge) => badge.isUnlocked)
        .length;
    final effectiveBadgeCount = math.max(
      badgeCount,
      unlockedCountFromSnapshots,
    );

    return _ProfileData(
      stats: stats,
      badgeCount: effectiveBadgeCount,
      totalSessions: allResults.length,
      displayName: displayName,
      subtitle: (email != null && email.isNotEmpty)
          ? email
          : 'ZenPose practitioner',
      rankTier: rankTier,
      avatarInitial: _avatarInitial(displayName),
      isAuthenticated: auth.status == AuthStatus.authenticated,
      accountLabel: (email != null && email.isNotEmpty)
          ? email
          : 'Local profile',
      badgeSnapshots: badgeSnapshots,
      previewBadges: previewBadges,
      activitySeries: activitySeries,
      challengeSnapshots: challengeSnapshots,
      challengePreview: challengePreview,
      challengeMonthKey: challengeMonthKey,
    );
  }

  String _resolveDisplayName(AuthState auth) {
    final explicit = auth.displayName?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    final email = auth.email?.trim();
    if (email != null && email.isNotEmpty) {
      final localPart = email.split('@').first.trim();
      if (localPart.isNotEmpty) {
        return localPart;
      }
    }
    return 'ZenPose User';
  }

  String _avatarInitial(String displayName) {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return 'Z';
    return trimmed.substring(0, 1).toUpperCase();
  }

  Future<void> _openStreakCalendar() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            widget.streakCalendarBuilder ?? (_) => const StreakCalendarScreen(),
      ),
    );
  }

  Future<void> _openAchievements(List<BadgeProgressSnapshot> badges) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AchievementsScreen(badges: badges)),
    );
  }

  Future<void> _openAllChallenges(_ProfileData data) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AllChallengesScreen(
          monthKey: data.challengeMonthKey,
          challengeService: _profileChallengeService,
          nowBuilder: widget.nowBuilder,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _future = _load());
  }

  Future<void> _handleChallengeAction(
    ChallengeProgressSnapshot snapshot,
  ) async {
    switch (snapshot.status) {
      case ChallengeLifecycleStatus.notJoined:
        await _profileChallengeService.joinChallenge(
          monthKey: snapshot.monthKey,
          challengeId: snapshot.definition.challengeId,
          now: widget.nowBuilder?.call() ?? DateTime.now(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined ${snapshot.definition.title}')),
        );
        setState(() => _future = _load());
        return;
      case ChallengeLifecycleStatus.claimable:
        final result = await _profileChallengeService.claimChallengeReward(
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
        setState(() => _future = _load());
        return;
      case ChallengeLifecycleStatus.joined:
      case ChallengeLifecycleStatus.completed:
      case ChallengeLifecycleStatus.ended:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: FutureBuilder<_ProfileData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ZenPageLoadingShimmer();
          }
          final data = snapshot.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              Text('Profile', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 20),
              _buildAvatar(context, data),
              const SizedBox(height: 20),
              if (data != null) ...[
                _buildProfileActivity(data),
                const SizedBox(height: 24),
                _buildStats(data),
                const SizedBox(height: 24),
                _buildAchievementsPreview(data),
                const SizedBox(height: 24),
                _buildChallengesSection(data),
                const SizedBox(height: 24),
              ],
              _buildSettingsSection(context, data),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, _ProfileData? data) {
    final displayName = data?.displayName ?? 'ZenPose User';
    final subtitle = data?.subtitle ?? 'ZenPose practitioner';
    final rankTier = data?.rankTier ?? UserRankTier.bronze;
    final initial = data?.avatarInitial ?? 'Z';

    return Container(
      decoration: ZenDecor.elevatedCard(),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ZenColors.forest, ZenColors.teal],
              ),
              boxShadow: [
                BoxShadow(
                  color: ZenColors.teal.withValues(alpha: 0.30),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Image.asset(
            rankTier.badgeAssetPath,
            width: 64,
            height: 64,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.workspace_premium_rounded,
              size: 48,
              color: ZenColors.forest,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${rankTier.label} Rank',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: ZenColors.forest,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(displayName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildProfileActivity(_ProfileData data) {
    final series = data.activitySeries[_selectedMetric]!;
    final values = series.points.map((p) => p.value).toList(growable: false);
    final headline = _headlineForMetric(series);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ZenSectionHeader(
          title: 'Profile Activity',
          subtitle: 'Last 10 days',
        ),
        const SizedBox(height: 12),
        Container(
          key: const Key('profile-activity-card'),
          decoration: ZenDecor.elevatedCard(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                key: const Key('profile-activity-headline'),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: ZenColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _metricSubtitle(_selectedMetric),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 144,
                child: _ProfileTrendChart(
                  values: values,
                  lineColor: ZenColors.teal,
                  fillColor: ZenColors.teal.withValues(alpha: 0.16),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    _dayLabel(series.points.first.day),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    _dayLabel(series.points.last.day),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _metricTabButton(
                      key: const Key('profile-activity-tab-duration'),
                      label: 'Duration',
                      metric: ProfileActivityMetric.duration,
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metricTabButton(
                      key: const Key('profile-activity-tab-score'),
                      label: 'Score',
                      metric: ProfileActivityMetric.score,
                      icon: Icons.track_changes_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metricTabButton(
                      key: const Key('profile-activity-tab-sessions'),
                      label: 'Sessions',
                      metric: ProfileActivityMetric.sessions,
                      icon: Icons.self_improvement_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricTabButton({
    required Key key,
    required String label,
    required ProfileActivityMetric metric,
    required IconData icon,
  }) {
    final selected = _selectedMetric == metric;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? ZenColors.teal100 : ZenColors.surface1,
        borderRadius: ZenDecor.pillRadius,
        border: Border.all(
          color: selected ? ZenColors.teal : ZenColors.surface2,
        ),
      ),
      child: InkWell(
        key: key,
        borderRadius: ZenDecor.pillRadius,
        onTap: () => setState(() => _selectedMetric = metric),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? ZenColors.teal : ZenColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? ZenColors.teal : ZenColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _headlineForMetric(ProfileActivitySeries series) {
    if (series.points.isEmpty) return '0';
    final latest = _latestNonZeroValue(series.points);
    return switch (series.metric) {
      ProfileActivityMetric.duration => '${latest.toStringAsFixed(1)} min',
      ProfileActivityMetric.score => '${latest.toStringAsFixed(1)}%',
      ProfileActivityMetric.sessions => latest.toStringAsFixed(0),
    };
  }

  double _latestNonZeroValue(List<ProfileActivityPoint> points) {
    const epsilon = 0.0001;
    for (var i = points.length - 1; i >= 0; i--) {
      if (points[i].value.abs() > epsilon) {
        return points[i].value;
      }
    }
    return points.last.value;
  }

  String _metricSubtitle(ProfileActivityMetric metric) {
    return switch (metric) {
      ProfileActivityMetric.duration => 'Daily practice duration',
      ProfileActivityMetric.score => 'Average completed-session score',
      ProfileActivityMetric.sessions => 'Completed sessions per day',
    };
  }

  String _dayLabel(DateTime day) {
    final month = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '$d/$month';
  }

  Widget _buildStats(_ProfileData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ZenSectionHeader(title: 'Your Stats'),
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
                label: 'Day Streak',
                value: '${data.stats.currentStreak}',
                icon: Icons.local_fire_department_rounded,
                accentColor: ZenColors.warning,
                onTap: _openStreakCalendar,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ZenStatCard(
                label: 'Total XP',
                value: '${data.stats.totalXp}',
                icon: Icons.star_rounded,
                accentColor: const Color(0xFFC49A1B),
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

  Widget _buildAchievementsPreview(_ProfileData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZenSectionHeader(
          title: 'Achievements',
          trailing: TextButton(
            key: const Key('profile-achievements-view-all'),
            onPressed: () => _openAchievements(data.badgeSnapshots),
            child: const Text('View All'),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          key: const Key('profile-achievements-preview'),
          decoration: ZenDecor.elevatedCard(),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: data.previewBadges.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No badges yet. Complete a session to unlock your first achievement.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : Row(
                  children: data.previewBadges
                      .asMap()
                      .entries
                      .map((entry) {
                        final index = entry.key;
                        final badge = entry.value;
                        return Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _PreviewBadgeTile(snapshot: badge),
                              ),
                              if (index != data.previewBadges.length - 1)
                                Container(
                                  width: 1,
                                  height: 120,
                                  color: ZenColors.surface2,
                                ),
                            ],
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
        ),
      ],
    );
  }

  Widget _buildChallengesSection(_ProfileData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZenSectionHeader(
          title: 'Challenges',
          subtitle: 'Monthly goals',
          trailing: TextButton(
            key: const Key('profile-challenges-view-all'),
            onPressed: () => _openAllChallenges(data),
            child: const Text('View All'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 254,
          child: data.challengePreview.isEmpty
              ? Container(
                  key: const Key('profile-challenges-preview-empty'),
                  decoration: ZenDecor.elevatedCard(),
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No active challenges for this month.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              : ListView.separated(
                  key: const Key('profile-challenges-preview'),
                  scrollDirection: Axis.horizontal,
                  itemCount: data.challengePreview.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final snapshot = data.challengePreview[index];
                    return _ProfileChallengePreviewCard(
                      snapshot: snapshot,
                      onAction: () => _handleChallengeAction(snapshot),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context, _ProfileData? data) {
    final accountLabel = data?.accountLabel ?? 'Local profile';
    final isAuthenticated = data?.isAuthenticated ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ZenSectionHeader(title: 'Settings'),
        const SizedBox(height: 12),
        Container(
          decoration: ZenDecor.elevatedCard(),
          child: Column(
            children: [
              _settingsRow(
                context,
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                trailing: Switch(
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                  },
                  activeThumbColor: ZenColors.teal,
                ),
              ),
              Divider(height: 1, color: ZenColors.surface2),
              _settingsRow(
                context,
                icon: Icons.account_circle_outlined,
                label: 'Account',
                trailing: SizedBox(
                  width: 150,
                  child: Text(
                    accountLabel,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ZenColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Divider(height: 1, color: ZenColors.surface2),
              if (isAuthenticated) ...[
                _settingsRow(
                  context,
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  onTap: _signOut,
                ),
                Divider(height: 1, color: ZenColors.surface2),
              ],
              _settingsRow(
                context,
                icon: Icons.info_outline_rounded,
                label: 'About ZenPose',
                onTap: () => _showAbout(context),
              ),
              Divider(height: 1, color: ZenColors.surface2),
              _settingsRow(
                context,
                icon: Icons.star_outline_rounded,
                label: 'Rate the App',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('In-app rating is coming soon.'),
                    ),
                  );
                },
              ),
              Divider(height: 1, color: ZenColors.surface2),
              _settingsRow(
                context,
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Privacy policy link will be added soon.'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
    }
  }

  Widget _settingsRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: ZenColors.sage100,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: ZenColors.forest, size: 18),
      ),
      title: Text(label, style: Theme.of(context).textTheme.bodyLarge),
      trailing:
          trailing ??
          (onTap != null
              ? const Icon(
                  Icons.chevron_right_rounded,
                  color: ZenColors.textMuted,
                  size: 20,
                )
              : null),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('ZenPose'),
        content: const Text(
          'A real-time yoga pose detection app powered by Google ML Kit. '
          'Practice mindfully, track your progress, and improve your form.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _PreviewBadgeTile extends StatelessWidget {
  final BadgeProgressSnapshot snapshot;

  const _PreviewBadgeTile({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ZenHexBadgeMedallion(snapshot: snapshot, size: 72),
          const SizedBox(height: 6),
          Text(
            snapshot.definition.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ProfileChallengePreviewCard extends StatelessWidget {
  final ChallengeProgressSnapshot snapshot;
  final VoidCallback onAction;

  const _ProfileChallengePreviewCard({
    required this.snapshot,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(snapshot.definition.metricType);
    final canTap =
        snapshot.status == ChallengeLifecycleStatus.notJoined ||
        snapshot.status == ChallengeLifecycleStatus.claimable;

    return Container(
      width: 234,
      decoration: ZenDecor.elevatedCard(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconForMetric(snapshot.definition.metricType),
                  color: accent,
                ),
              ),
              const Spacer(),
              Text(
                '+${snapshot.rewardXp} XP',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            snapshot.definition.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            snapshot.periodLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: ZenDecor.pillRadius,
            child: LinearProgressIndicator(
              value: snapshot.progressRatio,
              minHeight: 6,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
              backgroundColor: ZenColors.surface2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            snapshot.progressLabel,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
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
              key: Key(
                'profile-challenge-action-${snapshot.definition.challengeId}',
              ),
              onPressed: canTap ? onAction : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(38),
                backgroundColor: canTap ? ZenColors.forest : ZenColors.sage200,
              ),
              child: Text(snapshot.buttonLabel),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForMetric(ChallengeMetricType type) {
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

class _ProfileTrendChart extends StatelessWidget {
  final List<double> values;
  final Color lineColor;
  final Color fillColor;

  const _ProfileTrendChart({
    required this.values,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ProfileTrendChartPainter(
        values: values,
        lineColor: lineColor,
        fillColor: fillColor,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ProfileTrendChartPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color fillColor;

  _ProfileTrendChartPainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = ZenColors.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = (size.height - 10) * (i / 3) + 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.isEmpty) return;

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = (maxValue - minValue).abs() < 0.0001
        ? 1.0
        : (maxValue - minValue);
    final xStep = values.length == 1 ? 0.0 : size.width / (values.length - 1);
    final topPadding = 10.0;
    final usableHeight = size.height - 18;

    final path = Path();
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = i * xStep;
      final normalized = (values[i] - minValue) / range;
      final y = topPadding + ((1 - normalized) * usableHeight);
      final point = Offset(x, y);
      points.add(point);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final markerPaint = Paint()..color = lineColor;
    for (final point in points) {
      canvas.drawCircle(point, 3.2, markerPaint);
      canvas.drawCircle(
        point,
        1.5,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProfileTrendChartPainter oldDelegate) {
    if (oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor) {
      return true;
    }
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}

class _ProfileData {
  final UserStats stats;
  final int badgeCount;
  final int totalSessions;
  final String displayName;
  final String subtitle;
  final UserRankTier rankTier;
  final String avatarInitial;
  final bool isAuthenticated;
  final String accountLabel;
  final List<BadgeProgressSnapshot> badgeSnapshots;
  final List<BadgeProgressSnapshot> previewBadges;
  final Map<ProfileActivityMetric, ProfileActivitySeries> activitySeries;
  final List<ChallengeProgressSnapshot> challengeSnapshots;
  final List<ChallengeProgressSnapshot> challengePreview;
  final String challengeMonthKey;

  const _ProfileData({
    required this.stats,
    required this.badgeCount,
    required this.totalSessions,
    required this.displayName,
    required this.subtitle,
    required this.rankTier,
    required this.avatarInitial,
    required this.isAuthenticated,
    required this.accountLabel,
    required this.badgeSnapshots,
    required this.previewBadges,
    required this.activitySeries,
    required this.challengeSnapshots,
    required this.challengePreview,
    required this.challengeMonthKey,
  });
}
