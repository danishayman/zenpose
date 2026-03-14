import 'package:flutter/material.dart';

import '../models/user_stats.dart';
import '../services/database_service.dart';
import '../theme/zen_theme.dart';
import '../widgets/zen_loading_shimmer.dart';
import '../widgets/zen_section_header.dart';
import '../widgets/zen_stat_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  late Future<_ProfileData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProfileData> _load() async {
    final stats = await _databaseService.getUserStats();
    final badgeCount = await _databaseService.getUnlockedBadgeCount();
    final allResults = await _databaseService.getAllResults();
    return _ProfileData(
      stats: stats,
      badgeCount: badgeCount,
      totalSessions: allResults.length,
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
              _buildAvatar(context),
              const SizedBox(height: 24),
              if (data != null) ...[
                _buildStats(data),
                const SizedBox(height: 24),
              ],
              _buildSettingsSection(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
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
            child: const Center(
              child: Text(
                'Y',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('Yogi', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'ZenPose practitioner',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: ZenColors.teal100,
              borderRadius: ZenDecor.pillRadius,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.verified_rounded, size: 13, color: ZenColors.teal),
                SizedBox(width: 5),
                Text(
                  'Active Practitioner',
                  style: TextStyle(
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

  Widget _buildSettingsSection(BuildContext context) {
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
                  value: true,
                  onChanged: (_) {},
                  activeColor: ZenColors.teal,
                ),
              ),
              Divider(height: 1, color: ZenColors.surface2),
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
                onTap: () {},
              ),
              Divider(height: 1, color: ZenColors.surface2),
              _settingsRow(
                context,
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right_rounded,
                  color: ZenColors.textMuted, size: 20)
              : null),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
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

  const _ProfileData({
    required this.stats,
    required this.badgeCount,
    required this.totalSessions,
  });
}
