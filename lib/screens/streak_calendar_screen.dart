import 'package:flutter/material.dart';

import '../models/pose_result.dart';
import '../models/user_stats.dart';
import '../services/database_service.dart';
import '../theme/zen_theme.dart';
import '../widgets/zen_section_header.dart';

class StreakCalendarScreen extends StatefulWidget {
  final Future<UserStats> Function()? loadUserStats;
  final Future<List<PoseResult>> Function()? loadResults;
  final DateTime Function()? nowBuilder;

  const StreakCalendarScreen({
    super.key,
    this.loadUserStats,
    this.loadResults,
    this.nowBuilder,
  });

  @override
  State<StreakCalendarScreen> createState() => _StreakCalendarScreenState();
}

class _StreakCalendarScreenState extends State<StreakCalendarScreen> {
  static const List<String> _monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final DatabaseService _databaseService = DatabaseService.instance;
  late Future<_StreakCalendarData> _future;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = _now();
    _visibleMonth = DateTime(now.year, now.month);
    _future = _load();
  }

  DateTime _now() => (widget.nowBuilder?.call() ?? DateTime.now()).toLocal();

  Future<_StreakCalendarData> _load() async {
    final userStats =
        await (widget.loadUserStats?.call() ?? _databaseService.getUserStats());
    final results =
        await (widget.loadResults?.call() ?? _databaseService.getAllResults());
    final activeDateKeys = <String>{};
    for (final result in results) {
      if (!result.completed || result.timestamp == null) continue;
      activeDateKeys.add(_dateKey(result.timestamp!));
    }
    return _StreakCalendarData(
      userStats: userStats,
      activeDateKeys: activeDateKeys,
    );
  }

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _monthLabel(DateTime month) =>
      '${_monthNames[month.month - 1]} ${month.year}';

  int _monthActivityCount(Set<String> activeDateKeys, DateTime month) {
    final prefix =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-';
    return activeDateKeys.where((key) => key.startsWith(prefix)).length;
  }

  void _goToPreviousMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Streak')),
      body: Container(
        decoration: ZenDecor.gradientBackdrop(),
        child: FutureBuilder<_StreakCalendarData>(
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
                    'Failed to load streak calendar: ${snapshot.error}',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final data = snapshot.data!;
            final todayKey = _dateKey(_now());
            final monthActivityCount = _monthActivityCount(
              data.activeDateKeys,
              _visibleMonth,
            );
            final hasAnyActivity = data.activeDateKeys.isNotEmpty;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _buildSummary(data.userStats),
                const SizedBox(height: 24),
                const ZenSectionHeader(title: 'Streak Calendar'),
                const SizedBox(height: 12),
                _buildCalendarCard(
                  activeDateKeys: data.activeDateKeys,
                  todayKey: todayKey,
                ),
                const SizedBox(height: 14),
                if (!hasAnyActivity)
                  _buildInfoMessage(
                    context,
                    'Complete a session to start your streak calendar.',
                  )
                else if (monthActivityCount == 0)
                  _buildInfoMessage(
                    context,
                    'No completed sessions in this month yet.',
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummary(UserStats userStats) {
    return Container(
      decoration: ZenDecor.elevatedCard(),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${userStats.currentStreak}',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    color: ZenColors.textPrimary,
                    height: 0.95,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'day streak',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ZenColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Best streak: ${userStats.longestStreak} days',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ZenColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 94,
            height: 94,
            decoration: BoxDecoration(
              color: ZenColors.warningLight,
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              size: 54,
              color: ZenColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard({
    required Set<String> activeDateKeys,
    required String todayKey,
  }) {
    final firstDayOfMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
      1,
    );
    final leadingBlankDays = firstDayOfMonth.weekday % 7;
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final totalUsedCells = leadingBlankDays + daysInMonth;
    final trailingBlankDays = (7 - (totalUsedCells % 7)) % 7;

    final dayCells = <Widget>[
      for (var i = 0; i < leadingBlankDays; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _buildDayCell(
          date: DateTime(_visibleMonth.year, _visibleMonth.month, day),
          activeDateKeys: activeDateKeys,
          todayKey: todayKey,
        ),
      for (var i = 0; i < trailingBlankDays; i++) const SizedBox.shrink(),
    ];

    return Container(
      decoration: ZenDecor.elevatedCard(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('streak-prev-month'),
                onPressed: _goToPreviousMonth,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  _monthLabel(_visibleMonth),
                  key: const Key('streak-month-label'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ZenColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                key: const Key('streak-next-month'),
                onPressed: _goToNextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              _WeekdayLabel(label: 'Su'),
              _WeekdayLabel(label: 'Mo'),
              _WeekdayLabel(label: 'Tu'),
              _WeekdayLabel(label: 'We'),
              _WeekdayLabel(label: 'Th'),
              _WeekdayLabel(label: 'Fr'),
              _WeekdayLabel(label: 'Sa'),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dayCells.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.12,
            ),
            itemBuilder: (_, index) => dayCells[index],
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell({
    required DateTime date,
    required Set<String> activeDateKeys,
    required String todayKey,
  }) {
    final dayKey = _dateKey(date);
    final isActive = activeDateKeys.contains(dayKey);
    final isToday = dayKey == todayKey;
    final stateKey = Key(
      'streak-day-$dayKey-${isActive ? 'active' : 'inactive'}',
    );

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Container(
        key: stateKey,
        decoration: BoxDecoration(
          color: isActive ? ZenColors.warningLight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isToday
                ? ZenColors.teal
                : (isActive
                      ? ZenColors.warning.withValues(alpha: 0.45)
                      : ZenColors.surface2),
            width: isToday ? 1.8 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isActive ? ZenColors.warning : ZenColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoMessage(BuildContext context, String message) {
    return Container(
      decoration: ZenDecor.softCard(),
      padding: const EdgeInsets.all(14),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;

  const _WeekdayLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: ZenColors.textMuted,
        ),
      ),
    );
  }
}

class _StreakCalendarData {
  final UserStats userStats;
  final Set<String> activeDateKeys;

  const _StreakCalendarData({
    required this.userStats,
    required this.activeDateKeys,
  });
}
