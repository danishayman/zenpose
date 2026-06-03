import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/body_measurement.dart';
import '../models/pose_result.dart';
import '../models/pose_template.dart';
import '../models/progress_analytics_models.dart';
import '../models/session_history_entry.dart';
import '../models/weekly_workout_goal.dart';
import '../services/database_service.dart';
import '../services/pose_template_service.dart';
import '../services/progress_analytics_service.dart';
import '../theme/zen_theme.dart';
import '../widgets/zen_loading_shimmer.dart';
import '../widgets/zen_section_header.dart';

class ProgressDashboardScreen extends StatefulWidget {
  final Future<List<PoseResult>> Function()? loadAllResults;
  final Future<List<SessionHistoryEntry>> Function()? loadSessionHistory;
  final Future<WeeklyWorkoutGoal> Function()? loadWeeklyGoal;
  final Future<void> Function(int targetWorkouts)? saveWeeklyGoal;
  final Future<List<BodyMeasurement>> Function(BodyMetricType metricType)?
  loadMeasurementHistory;
  final Future<void> Function(BodyMeasurement measurement)? saveMeasurement;
  final Future<List<PoseTemplate>> Function()? loadPoseTemplates;
  final DateTime Function()? nowBuilder;

  const ProgressDashboardScreen({
    super.key,
    this.loadAllResults,
    this.loadSessionHistory,
    this.loadWeeklyGoal,
    this.saveWeeklyGoal,
    this.loadMeasurementHistory,
    this.saveMeasurement,
    this.loadPoseTemplates,
    this.nowBuilder,
  });

  @override
  State<ProgressDashboardScreen> createState() =>
      _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
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
  final ProgressAnalyticsService _analyticsService =
      const ProgressAnalyticsService();
  final PoseTemplateService _poseTemplateService = PoseTemplateService();
  final TextEditingController _exerciseSearchController =
      TextEditingController();

  late Future<_ProgressDashboardData> _future;
  late DateTime _visibleMonth;
  String _exerciseQuery = '';

  @override
  void initState() {
    super.initState();
    final now = _now();
    _visibleMonth = DateTime(now.year, now.month);
    _future = _load();
    _exerciseSearchController.addListener(() {
      setState(
        () => _exerciseQuery = _exerciseSearchController.text
            .trim()
            .toLowerCase(),
      );
    });
  }

  @override
  void dispose() {
    _exerciseSearchController.dispose();
    super.dispose();
  }

  DateTime _now() => widget.nowBuilder?.call() ?? DateTime.now();

  Future<_ProgressDashboardData> _load() async {
    final results =
        await (widget.loadAllResults?.call() ??
            _databaseService.getAllResults());
    final weeklyGoal =
        await (widget.loadWeeklyGoal?.call() ??
            _databaseService.getWeeklyWorkoutGoal());
    final sessionHistory = await _loadSessionHistory(results);
    final measurementEntries = await Future.wait(
      BodyMetricType.coreMetrics.map((metricType) async {
        final history =
            await (widget.loadMeasurementHistory?.call(metricType) ??
                _databaseService.getBodyMeasurementHistory(metricType));
        return MapEntry(metricType, history);
      }),
    );

    List<PoseTemplate> templates;
    try {
      templates =
          await (widget.loadPoseTemplates?.call() ??
              _poseTemplateService.loadTemplates());
    } catch (_) {
      templates = const <PoseTemplate>[];
    }

    return _ProgressDashboardData(
      results: results,
      sessionHistory: sessionHistory,
      weeklyGoal: weeklyGoal,
      measurementHistoryByMetric: <BodyMetricType, List<BodyMeasurement>>{
        for (final entry in measurementEntries) entry.key: entry.value,
      },
      poseTemplates: templates,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _saveWeeklyGoal(int targetWorkouts) async {
    await (widget.saveWeeklyGoal?.call(targetWorkouts) ??
        _databaseService.upsertWeeklyWorkoutGoal(
          targetWorkouts: targetWorkouts,
        ));
    await _refresh();
  }

  Future<List<SessionHistoryEntry>> _loadSessionHistory(
    List<PoseResult> results,
  ) async {
    if (widget.loadSessionHistory != null) {
      return widget.loadSessionHistory!.call();
    }
    if (widget.loadAllResults != null) {
      return _sessionHistoryFromResults(results);
    }
    return _databaseService.getHomeSessionHistory();
  }

  List<SessionHistoryEntry> _sessionHistoryFromResults(
    List<PoseResult> results,
  ) {
    return results
        .map((result) {
          final occurredAt =
              result.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
          return SessionHistoryEntry(
            sessionId:
                'result:${result.id ?? occurredAt.microsecondsSinceEpoch}',
            kind: result.sessionType == PoseResultSessionType.challenge
                ? SessionHistoryKind.challenge
                : SessionHistoryKind.practice,
            activityAt: occurredAt,
            startedAt: occurredAt,
            completed: result.completed,
            durationSeconds: result.holdDuration.round(),
            averageScore: result.bestScore,
            isLegacyPractice: result.sessionType == null,
            poses: <SessionHistoryPoseEntry>[
              SessionHistoryPoseEntry(
                poseName: result.poseName,
                status: result.completed
                    ? SessionHistoryPoseStatus.completed
                    : SessionHistoryPoseStatus.pending,
                bestScore: result.bestScore,
                holdDurationSeconds: result.holdDuration,
              ),
            ],
          );
        })
        .toList(growable: false);
  }

  Future<void> _saveBodyMeasurement(
    BodyMetricType metricType, {
    required double value,
    required DateTime measuredAt,
  }) async {
    final measurement = BodyMeasurement(
      userId: '',
      metricType: metricType,
      value: value,
      unit: metricType.unit,
      measuredAt: measuredAt,
      updatedAt: DateTime.now().toUtc(),
      isSynced: false,
    );
    await (widget.saveMeasurement?.call(measurement) ??
        _databaseService.insertBodyMeasurement(measurement));
    await _refresh();
  }

  String _monthLabel(DateTime month) =>
      '${_monthNames[month.month - 1]} ${month.year}';

  void _shiftVisibleMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  Future<void> _showGoalEditor(int currentTarget) async {
    final controller = TextEditingController(text: '$currentTarget');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set Weekly Goal',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('progress-goal-target-input'),
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sessions per week',
                  hintText: 'e.g. 3',
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('progress-goal-save-button'),
                  onPressed: () async {
                    final parsed = int.tryParse(controller.text.trim());
                    if (parsed == null || parsed <= 0) return;
                    await _saveWeeklyGoal(parsed);
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save Goal'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showMeasurementEditor({
    required BodyMetricType metricType,
    double? initialValue,
  }) async {
    final controller = TextEditingController(
      text: initialValue == null ? '' : initialValue.toStringAsFixed(1),
    );
    var selectedDate = _now();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update ${metricType.label}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: Key('progress-measure-input-${metricType.metricKey}'),
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: metricType.label,
                      suffixText: metricType.unit,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020, 1, 1),
                            lastDate: DateTime(2100, 12, 31),
                          );
                          if (picked == null) return;
                          setSheetState(() => selectedDate = picked);
                        },
                        child: const Text('Pick date'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: Key('progress-measure-save-${metricType.metricKey}'),
                      onPressed: () async {
                        final parsed = double.tryParse(controller.text.trim());
                        if (parsed == null) return;
                        await _saveBodyMeasurement(
                          metricType,
                          value: parsed,
                          measuredAt: selectedDate,
                        );
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                      child: const Text('Save Measurement'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: FutureBuilder<_ProgressDashboardData>(
        future: _future,
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
          final monthlySummary = _analyticsService.buildMonthlySummary(
            results: data.results,
            month: _visibleMonth,
          );
          final weeklyCompleted = _analyticsService
              .countWeeklyCompletedSessions(
                sessions: data.sessionHistory,
                anchorDate: _now(),
              );
          final exercises = _analyticsService.buildExerciseTrends(data.results);
          final filteredExercises = exercises
              .where(
                (entry) =>
                    entry.poseName.toLowerCase().contains(_exerciseQuery),
              )
              .toList(growable: false);
          final measureTrends = <BodyMetricType, MeasureTrendSnapshot>{
            for (final metric in BodyMetricType.coreMetrics)
              metric: _analyticsService.buildMeasureTrend(
                metricType: metric,
                history:
                    data.measurementHistoryByMetric[metric] ??
                    const <BodyMeasurement>[],
              ),
          };
          final templateByPoseName = <String, PoseTemplate>{
            for (final template in data.poseTemplates) ...{
              _normalizeName(template.name): template,
              _normalizeName(template.templateKey): template,
            },
          };

          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: _buildHeader(),
                ),
                const SizedBox(height: 14),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: ZenColors.surface1,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    indicatorColor: ZenColors.teal,
                    indicatorWeight: 2.6,
                    labelColor: ZenColors.textPrimary,
                    unselectedLabelColor: ZenColors.textMuted,
                    tabs: const [
                      Tab(key: Key('progress-tab-overview'), text: 'Overview'),
                      Tab(
                        key: Key('progress-tab-exercises'),
                        text: 'Exercises',
                      ),
                      Tab(key: Key('progress-tab-measures'), text: 'Measures'),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildOverviewTab(
                        monthlySummary: monthlySummary,
                        weeklyCompleted: weeklyCompleted,
                        weeklyGoal: data.weeklyGoal.targetWorkouts,
                      ),
                      _buildExercisesTab(
                        exercises: filteredExercises,
                        templateByPoseName: templateByPoseName,
                      ),
                      _buildMeasuresTab(measureTrends: measureTrends),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Progress', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 4),
        Text(
          'Track your consistency, exercise trends, and body metrics.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildOverviewTab({
    required MonthlyWorkoutSummary monthlySummary,
    required int weeklyCompleted,
    required int weeklyGoal,
  }) {
    final remaining = math.max(0, weeklyGoal - weeklyCompleted);
    final progress = weeklyGoal == 0
        ? 0.0
        : (weeklyCompleted / weeklyGoal).clamp(0.0, 1.0);
    final sparkValues = monthlySummary.dailyPoints
        .map((point) => point.workouts.toDouble())
        .toList();

    return RefreshIndicator(
      color: ZenColors.teal,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          const ZenSectionHeader(title: 'Workouts'),
          const SizedBox(height: 12),
          Container(
            decoration: ZenDecor.elevatedCard(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _monthLabel(_visibleMonth),
                        key: const Key('progress-month-label'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      key: const Key('progress-prev-month'),
                      onPressed: () => _shiftVisibleMonth(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    IconButton(
                      key: const Key('progress-next-month'),
                      onPressed: () => _shiftVisibleMonth(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${monthlySummary.totalWorkouts} workouts',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: ZenColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Completed sessions this month',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 92,
                  child: _MiniSparkline(
                    values: sparkValues,
                    color: ZenColors.teal,
                    fillColor: ZenColors.teal.withValues(alpha: 0.18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const ZenSectionHeader(title: 'This Week'),
          const SizedBox(height: 12),
          Container(
            decoration: ZenDecor.elevatedCard(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$weeklyCompleted / $weeklyGoal sessions completed',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      remaining == 0 ? 'Goal met' : '$remaining left',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: remaining == 0
                            ? ZenColors.success
                            : ZenColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: ZenDecor.pillRadius,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: ZenColors.surface2,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      ZenColors.teal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildCompactMonthCalendar(
            month: _visibleMonth,
            activeDateKeys: monthlySummary.activeDateKeys,
          ),
          const SizedBox(height: 20),
          Container(
            decoration: ZenDecor.elevatedCard(),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Suggested Goal',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$weeklyGoal sessions per week',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  key: const Key('progress-edit-goal-button'),
                  onPressed: () => _showGoalEditor(weeklyGoal),
                  child: const Text('Set Goal'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMonthCalendar({
    required DateTime month,
    required Set<String> activeDateKeys,
  }) {
    final monthStart = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = monthStart.weekday % 7;
    final dayCells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _buildCalendarCell(
          DateTime(month.year, month.month, day),
          activeDateKeys,
        ),
    ];
    final trailing = (7 - (dayCells.length % 7)) % 7;
    for (var i = 0; i < trailing; i++) {
      dayCells.add(const SizedBox.shrink());
    }

    return Container(
      decoration: ZenDecor.elevatedCard(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Calendar', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          const Row(
            children: [
              _WeekdayChip(label: 'S'),
              _WeekdayChip(label: 'M'),
              _WeekdayChip(label: 'T'),
              _WeekdayChip(label: 'W'),
              _WeekdayChip(label: 'T'),
              _WeekdayChip(label: 'F'),
              _WeekdayChip(label: 'S'),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dayCells.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (_, index) => dayCells[index],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCell(DateTime date, Set<String> activeDateKeys) {
    final key = _dateKey(date);
    final isActive = activeDateKeys.contains(key);
    final today = DateTime.now();
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Container(
        key: Key('progress-day-$key-${isActive ? 'active' : 'inactive'}'),
        decoration: BoxDecoration(
          color: isActive ? ZenColors.teal100 : ZenColors.surface1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isToday ? ZenColors.teal : ZenColors.surface2,
            width: isToday ? 1.6 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isActive ? ZenColors.teal : ZenColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildExercisesTab({
    required List<ExerciseTrendSnapshot> exercises,
    required Map<String, PoseTemplate> templateByPoseName,
  }) {
    return RefreshIndicator(
      color: ZenColors.teal,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          TextField(
            key: const Key('progress-exercises-search'),
            controller: _exerciseSearchController,
            decoration: const InputDecoration(
              hintText: 'Search for exercise',
              prefixIcon: Icon(
                Icons.search_rounded,
                color: ZenColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.swap_vert_rounded,
                size: 18,
                color: ZenColors.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                'Recent Performed',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ZenColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (exercises.isEmpty)
            Container(
              decoration: ZenDecor.elevatedCard(),
              padding: const EdgeInsets.all(16),
              child: Text(
                _exerciseQuery.isEmpty
                    ? 'No exercise data yet. Complete a session to see trends.'
                    : 'No exercise found for "$_exerciseQuery".',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            ...exercises.map(
              (entry) => _buildExerciseRow(
                entry,
                templateByPoseName[_normalizeName(entry.poseName)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExerciseRow(
    ExerciseTrendSnapshot exercise,
    PoseTemplate? template,
  ) {
    final trendDelta = exercise.windowTrendDelta;
    final trendColor = !exercise.hasEnoughTrendData || trendDelta == null
        ? ZenColors.textMuted
        : (trendDelta >= 0 ? ZenColors.success : ZenColors.error);
    final trendPrefix = trendDelta != null && trendDelta >= 0 ? '+' : '';
    final trendText = exercise.hasEnoughTrendData && trendDelta != null
        ? '${exercise.trendWindowSize}-session trend $trendPrefix${trendDelta.toStringAsFixed(1)}% · ${exercise.sessionCount} sessions · Avg hold ${exercise.averageHoldDuration.toStringAsFixed(1)}s'
        : 'Not enough data · ${exercise.sessionCount} sessions · Avg hold ${exercise.averageHoldDuration.toStringAsFixed(1)}s';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: ZenDecor.elevatedCard(),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _PoseThumb(template: template),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.poseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Latest ${exercise.latestScore.toStringAsFixed(0)}% · Best ${exercise.bestScore.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  trendText,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: trendColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 132,
            height: 64,
            child: _MiniSparkline(
              values: exercise.recentScores,
              color: ZenColors.teal,
              fillColor: ZenColors.teal.withValues(alpha: 0.14),
              minValue: 0,
              maxValue: 100,
              showEndpoint: true,
              showPointMarkers: true,
              showGrid: true,
              showFrame: true,
              showAxisLabels: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasuresTab({
    required Map<BodyMetricType, MeasureTrendSnapshot> measureTrends,
  }) {
    return RefreshIndicator(
      color: ZenColors.teal,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: BodyMetricType.coreMetrics.map((metricType) {
          final snapshot = measureTrends[metricType]!;
          final latestText = snapshot.latestValue == null
              ? 'No data'
              : '${snapshot.latestValue!.toStringAsFixed(1)} ${metricType.unit}';
          final delta = snapshot.deltaValue;
          final deltaText = delta == null
              ? 'Tap to add measurement'
              : 'Latest change: ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} ${metricType.unit}';
          return InkWell(
            key: Key('progress-measure-row-${metricType.metricKey}'),
            onTap: () => _showMeasurementEditor(
              metricType: metricType,
              initialValue: snapshot.latestValue,
            ),
            borderRadius: ZenDecor.cardRadius,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: ZenDecor.elevatedCard(),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: ZenColors.sage100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      metricType == BodyMetricType.bodyWeight
                          ? Icons.monitor_weight_outlined
                          : Icons.percent_rounded,
                      size: 22,
                      color: ZenColors.forest,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metricType.label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          latestText,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          deltaText,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    height: 48,
                    child: _MiniSparkline(
                      values: snapshot.history.reversed
                          .map((e) => e.value)
                          .toList(),
                      color: ZenColors.teal,
                      fillColor: Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _normalizeName(String value) {
    final lower = value.toLowerCase();
    return lower.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _PoseThumb extends StatelessWidget {
  final PoseTemplate? template;

  const _PoseThumb({required this.template});

  @override
  Widget build(BuildContext context) {
    final asset = template == null
        ? null
        : 'assets/thumbnail/${template!.templateKey}.jpg';
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 52,
        height: 52,
        child: asset == null
            ? _fallback()
            : Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: ZenColors.sage100,
      child: const Icon(
        Icons.self_improvement_rounded,
        color: ZenColors.forest,
      ),
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final Color fillColor;
  final double? minValue;
  final double? maxValue;
  final bool showEndpoint;
  final bool showPointMarkers;
  final bool showGrid;
  final bool showFrame;
  final bool showAxisLabels;

  const _MiniSparkline({
    required this.values,
    required this.color,
    required this.fillColor,
    this.minValue,
    this.maxValue,
    this.showEndpoint = false,
    this.showPointMarkers = false,
    this.showGrid = false,
    this.showFrame = false,
    this.showAxisLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MiniSparklinePainter(
        values: values,
        color: color,
        fillColor: fillColor,
        minValue: minValue,
        maxValue: maxValue,
        showEndpoint: showEndpoint,
        showPointMarkers: showPointMarkers,
        showGrid: showGrid,
        showFrame: showFrame,
        showAxisLabels: showAxisLabels,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _MiniSparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final Color fillColor;
  final double? minValue;
  final double? maxValue;
  final bool showEndpoint;
  final bool showPointMarkers;
  final bool showGrid;
  final bool showFrame;
  final bool showAxisLabels;

  _MiniSparklinePainter({
    required this.values,
    required this.color,
    required this.fillColor,
    required this.minValue,
    required this.maxValue,
    required this.showEndpoint,
    required this.showPointMarkers,
    required this.showGrid,
    required this.showFrame,
    required this.showAxisLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final leftGutter = showAxisLabels ? 22.0 : 0.0;
    final frameRect = Rect.fromLTWH(
      leftGutter + 1,
      1,
      size.width - leftGutter - 2,
      size.height - 2,
    );
    final frameRRect = RRect.fromRectAndRadius(
      frameRect,
      const Radius.circular(6),
    );
    final chartRect = Rect.fromLTWH(
      leftGutter + 4,
      4,
      size.width - leftGutter - 8,
      size.height - 8,
    );

    if (showAxisLabels) {
      _drawAxisLabel(canvas, text: '100', x: 0, y: chartRect.top - 6);
      _drawAxisLabel(canvas, text: '50', x: 4, y: chartRect.center.dy - 6);
      _drawAxisLabel(canvas, text: '0', x: 10, y: chartRect.bottom - 6);
    }

    if (showFrame) {
      final framePaint = Paint()
        ..color = ZenColors.surface2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawRRect(frameRRect, framePaint);
    }

    if (showGrid) {
      final gridPaint = Paint()
        ..color = ZenColors.surface2.withValues(alpha: 0.9)
        ..strokeWidth = 1;
      for (final ratio in const <double>[0.25, 0.5, 0.75]) {
        final y = chartRect.bottom - (chartRect.height * ratio);
        canvas.drawLine(
          Offset(chartRect.left, y),
          Offset(chartRect.right, y),
          gridPaint,
        );
      }
    }

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (values.isEmpty) {
      final y = chartRect.center.dy;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        strokePaint..color = ZenColors.surface2,
      );
      return;
    }

    final lowerBound = minValue ?? values.reduce(math.min);
    final upperBound = maxValue ?? values.reduce(math.max);
    final range = (upperBound - lowerBound).abs();
    final effectiveRange = range < 0.0001 ? 1.0 : range;
    final xStep = values.length == 1
        ? 0.0
        : chartRect.width / (values.length - 1);
    final path = Path();
    var lastX = chartRect.left;
    var lastY = chartRect.center.dy;
    final points = <Offset>[];

    for (var i = 0; i < values.length; i++) {
      final clamped = values[i].clamp(lowerBound, upperBound).toDouble();
      final normalizedY = (clamped - lowerBound) / effectiveRange;
      final x = chartRect.left + (i * xStep);
      final y = chartRect.bottom - (normalizedY * chartRect.height);
      lastX = x;
      lastY = y;
      points.add(Offset(x, y));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    if (fillColor.a > 0) {
      final fillPath = Path.from(path)
        ..lineTo(chartRect.right, chartRect.bottom)
        ..lineTo(chartRect.left, chartRect.bottom)
        ..close();
      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);
    }

    canvas.drawPath(path, strokePaint);
    if (showPointMarkers) {
      final pointFill = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final pointStroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      for (final point in points) {
        canvas.drawCircle(point, 2.2, pointFill);
        canvas.drawCircle(point, 2.2, pointStroke);
      }
    }
    if (showEndpoint && values.isNotEmpty) {
      final pointPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(lastX, lastY), 2.6, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter oldDelegate) {
    if (oldDelegate.color != color ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.showEndpoint != showEndpoint ||
        oldDelegate.showPointMarkers != showPointMarkers ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showFrame != showFrame ||
        oldDelegate.showAxisLabels != showAxisLabels) {
      return true;
    }
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }

  void _drawAxisLabel(
    Canvas canvas, {
    required String text,
    required double x,
    required double y,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: ZenColors.textMuted,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(canvas, Offset(x, y));
  }
}

class _WeekdayChip extends StatelessWidget {
  final String label;

  const _WeekdayChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ZenColors.textMuted,
        ),
      ),
    );
  }
}

class _ProgressDashboardData {
  final List<PoseResult> results;
  final List<SessionHistoryEntry> sessionHistory;
  final WeeklyWorkoutGoal weeklyGoal;
  final Map<BodyMetricType, List<BodyMeasurement>> measurementHistoryByMetric;
  final List<PoseTemplate> poseTemplates;

  const _ProgressDashboardData({
    required this.results,
    required this.sessionHistory,
    required this.weeklyGoal,
    required this.measurementHistoryByMetric,
    required this.poseTemplates,
  });
}
