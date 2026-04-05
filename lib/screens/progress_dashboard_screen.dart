import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/body_measurement.dart';
import '../models/pose_result.dart';
import '../models/pose_template.dart';
import '../models/progress_analytics_models.dart';
import '../models/weekly_workout_goal.dart';
import '../services/database_service.dart';
import '../services/pose_template_service.dart';
import '../services/progress_analytics_service.dart';
import '../theme/zen_theme.dart';
import '../widgets/zen_loading_shimmer.dart';
import '../widgets/zen_section_header.dart';

class ProgressDashboardScreen extends StatefulWidget {
  final Future<List<PoseResult>> Function()? loadAllResults;
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
                  labelText: 'Workouts per week',
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
          final weeklyCompleted = _analyticsService.countWeeklyCompleted(
            results: data.results,
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
            for (final template in data.poseTemplates)
              _normalizeName(template.name): template,
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
                        '$weeklyCompleted / $weeklyGoal workouts completed',
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
                        '$weeklyGoal workouts per week',
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
    final deltaColor = exercise.deltaScore >= 0
        ? ZenColors.success
        : ZenColors.error;
    final deltaPrefix = exercise.deltaScore >= 0 ? '+' : '';

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
                  'Δ $deltaPrefix${exercise.deltaScore.toStringAsFixed(1)}% · Avg hold ${exercise.averageHoldDuration.toStringAsFixed(1)}s',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: deltaColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            height: 54,
            child: _MiniSparkline(
              values: exercise.recentScores,
              color: ZenColors.teal,
              fillColor: Colors.transparent,
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

  const _MiniSparkline({
    required this.values,
    required this.color,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MiniSparklinePainter(
        values: values,
        color: color,
        fillColor: fillColor,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _MiniSparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final Color fillColor;

  _MiniSparklinePainter({
    required this.values,
    required this.color,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (values.isEmpty) {
      final y = size.height * 0.5;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        strokePaint..color = ZenColors.surface2,
      );
      return;
    }

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = (maxValue - minValue).abs();
    final effectiveRange = range < 0.0001 ? 1.0 : range;
    final xStep = values.length == 1 ? 0.0 : size.width / (values.length - 1);
    final path = Path();

    for (var i = 0; i < values.length; i++) {
      final normalizedY = (values[i] - minValue) / effectiveRange;
      final x = i * xStep;
      final y = size.height - (normalizedY * (size.height - 4)) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    if (fillColor.a > 0) {
      final fillPath = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);
    }

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter oldDelegate) {
    if (oldDelegate.color != color || oldDelegate.fillColor != fillColor) {
      return true;
    }
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
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
  final WeeklyWorkoutGoal weeklyGoal;
  final Map<BodyMetricType, List<BodyMeasurement>> measurementHistoryByMetric;
  final List<PoseTemplate> poseTemplates;

  const _ProgressDashboardData({
    required this.results,
    required this.weeklyGoal,
    required this.measurementHistoryByMetric,
    required this.poseTemplates,
  });
}
