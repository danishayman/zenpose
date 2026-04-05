import 'package:flutter/material.dart';

import '../models/pose_result.dart';
import '../models/user_stats.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../theme/zen_theme.dart';
import '../widgets/zen_loading_shimmer.dart';
import '../widgets/zen_section_header.dart';
import '../widgets/zen_stat_card.dart';
import 'streak_calendar_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Future<UserStats> Function()? loadUserStats;
  final Future<int> Function()? loadBadgeCount;
  final Future<List<PoseResult>> Function()? loadAllResults;
  final WidgetBuilder? streakCalendarBuilder;

  const ProfileScreen({
    super.key,
    this.loadUserStats,
    this.loadBadgeCount,
    this.loadAllResults,
    this.streakCalendarBuilder,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  final AuthService _authService = AuthService.instance;
  late Future<_ProfileData> _future;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
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

    final auth = _authService.authState.value;
    final displayName = _resolveDisplayName(auth);
    final email = auth.email?.trim();

    return _ProfileData(
      stats: stats,
      badgeCount: badgeCount,
      totalSessions: allResults.length,
      displayName: displayName,
      subtitle: (email != null && email.isNotEmpty)
          ? email
          : 'ZenPose practitioner',
      avatarInitial: _avatarInitial(displayName),
      statusText: auth.status == AuthStatus.authenticated
          ? 'Active Practitioner'
          : 'Offline Practitioner',
      isAuthenticated: auth.status == AuthStatus.authenticated,
      accountLabel: (email != null && email.isNotEmpty)
          ? email
          : 'Local profile',
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
              const SizedBox(height: 24),
              if (data != null) ...[
                _buildStats(data),
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
    final initial = data?.avatarInitial ?? 'Z';
    final statusText = data?.statusText ?? 'Active Practitioner';

    return Container(
      decoration: ZenDecor.elevatedCard(),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar circle with initials
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
          Text(displayName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: ZenColors.teal100,
              borderRadius: ZenDecor.pillRadius,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 13,
                  color: ZenColors.teal,
                ),
                const SizedBox(width: 5),
                Text(
                  statusText,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ZenColors.teal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

class _ProfileData {
  final UserStats stats;
  final int badgeCount;
  final int totalSessions;
  final String displayName;
  final String subtitle;
  final String avatarInitial;
  final String statusText;
  final bool isAuthenticated;
  final String accountLabel;

  const _ProfileData({
    required this.stats,
    required this.badgeCount,
    required this.totalSessions,
    required this.displayName,
    required this.subtitle,
    required this.avatarInitial,
    required this.statusText,
    required this.isAuthenticated,
    required this.accountLabel,
  });
}
