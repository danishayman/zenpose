import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/models/body_measurement.dart';
import 'package:zenpose/models/pose_result.dart';
import 'package:zenpose/models/pose_template.dart';
import 'package:zenpose/models/weekly_workout_goal.dart';
import 'package:zenpose/screens/progress_dashboard_screen.dart';
import 'package:zenpose/theme/zen_theme.dart';

void main() {
  final baseResults = <PoseResult>[
    PoseResult(
      poseName: 'Tree',
      bestScore: 86,
      holdDuration: 45,
      completed: true,
      timestamp: DateTime(2026, 4, 5, 9, 0),
    ),
    PoseResult(
      poseName: 'Plank',
      bestScore: 80,
      holdDuration: 40,
      completed: true,
      timestamp: DateTime(2026, 4, 4, 9, 0),
    ),
  ];

  testWidgets('switches across Overview, Exercises, and Measures tabs', (
    tester,
  ) async {
    _setLargeSurface(tester);
    await tester.pumpWidget(
      _app(
        ProgressDashboardScreen(
          loadAllResults: () async => baseResults,
          loadWeeklyGoal: () async => WeeklyWorkoutGoal(
            userId: 'u1',
            targetWorkouts: 3,
            updatedAt: DateTime(2026, 4, 5),
            isSynced: true,
          ),
          loadMeasurementHistory: (_) async => const <BodyMeasurement>[],
          loadPoseTemplates: () async => const <PoseTemplate>[],
          nowBuilder: () => DateTime(2026, 4, 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('progress-tab-overview')), findsOneWidget);
    await tester.tap(find.byKey(const Key('progress-tab-exercises')));
    await tester.pumpAndSettle();
    expect(find.text('Recent Performed'), findsOneWidget);
    await tester.tap(find.byKey(const Key('progress-tab-measures')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('progress-measure-row-body_weight')),
      findsOneWidget,
    );
  });

  testWidgets('filters exercise list using search box', (tester) async {
    _setLargeSurface(tester);
    await tester.pumpWidget(
      _app(
        ProgressDashboardScreen(
          loadAllResults: () async => baseResults,
          loadWeeklyGoal: () async => WeeklyWorkoutGoal(
            userId: 'u1',
            targetWorkouts: 3,
            updatedAt: DateTime(2026, 4, 5),
            isSynced: true,
          ),
          loadMeasurementHistory: (_) async => const <BodyMeasurement>[],
          loadPoseTemplates: () async => const <PoseTemplate>[],
          nowBuilder: () => DateTime(2026, 4, 5),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('progress-tab-exercises')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('progress-exercises-search')),
      'tree',
    );
    await tester.pumpAndSettle();

    expect(find.text('Tree'), findsOneWidget);
    expect(find.text('Plank'), findsNothing);
  });

  testWidgets('shows trend insight and sparse-data insight in Exercises tab', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final results = <PoseResult>[
      ...List<PoseResult>.generate(10, (i) {
        final scores = <double>[60, 62, 64, 66, 68, 70, 72, 74, 76, 78];
        return PoseResult(
          poseName: 'Tree',
          bestScore: scores[i],
          holdDuration: 40,
          completed: true,
          timestamp: DateTime(2026, 4, i + 1, 8, 0),
        );
      }),
      ...List<PoseResult>.generate(4, (i) {
        return PoseResult(
          poseName: 'Plank',
          bestScore: 70 + i.toDouble(),
          holdDuration: 30,
          completed: true,
          timestamp: DateTime(2026, 4, i + 1, 9, 0),
        );
      }),
    ];

    await tester.pumpWidget(
      _app(
        ProgressDashboardScreen(
          loadAllResults: () async => results,
          loadWeeklyGoal: () async => WeeklyWorkoutGoal(
            userId: 'u1',
            targetWorkouts: 3,
            updatedAt: DateTime(2026, 4, 10),
            isSynced: true,
          ),
          loadMeasurementHistory: (_) async => const <BodyMeasurement>[],
          loadPoseTemplates: () async => const <PoseTemplate>[],
          nowBuilder: () => DateTime(2026, 4, 10),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('progress-tab-exercises')));
    await tester.pumpAndSettle();

    expect(find.textContaining('5-session trend +10.0%'), findsOneWidget);
    expect(find.textContaining('10 sessions'), findsOneWidget);
    expect(find.textContaining('Not enough data · 4 sessions'), findsOneWidget);
  });

  testWidgets('updates weekly goal from editor', (tester) async {
    _setLargeSurface(tester);
    var goal = 3;
    await tester.pumpWidget(
      _app(
        ProgressDashboardScreen(
          loadAllResults: () async => baseResults,
          loadWeeklyGoal: () async => WeeklyWorkoutGoal(
            userId: 'u1',
            targetWorkouts: goal,
            updatedAt: DateTime(2026, 4, 5),
            isSynced: true,
          ),
          saveWeeklyGoal: (target) async {
            goal = target;
          },
          loadMeasurementHistory: (_) async => const <BodyMeasurement>[],
          loadPoseTemplates: () async => const <PoseTemplate>[],
          nowBuilder: () => DateTime(2026, 4, 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('progress-edit-goal-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('progress-goal-target-input')),
      '5',
    );
    await tester.tap(find.byKey(const Key('progress-goal-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('5 sessions per week'), findsOneWidget);
  });

  testWidgets('adds body weight measurement from Measures tab', (tester) async {
    _setLargeSurface(tester);
    final measureStore = <BodyMetricType, List<BodyMeasurement>>{
      BodyMetricType.bodyWeight: <BodyMeasurement>[],
      BodyMetricType.bodyFat: <BodyMeasurement>[],
    };

    await tester.pumpWidget(
      _app(
        ProgressDashboardScreen(
          loadAllResults: () async => baseResults,
          loadWeeklyGoal: () async => WeeklyWorkoutGoal(
            userId: 'u1',
            targetWorkouts: 3,
            updatedAt: DateTime(2026, 4, 5),
            isSynced: true,
          ),
          loadMeasurementHistory: (metricType) async =>
              measureStore[metricType] ?? const <BodyMeasurement>[],
          saveMeasurement: (measurement) async {
            final list = measureStore[measurement.metricType]!;
            list.insert(0, measurement.copyWith(userId: 'u1'));
          },
          loadPoseTemplates: () async => const <PoseTemplate>[],
          nowBuilder: () => DateTime(2026, 4, 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('progress-tab-measures')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('progress-measure-row-body_weight')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('progress-measure-input-body_weight')),
      '70.5',
    );
    await tester.tap(
      find.byKey(const Key('progress-measure-save-body_weight')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('progress-tab-measures')));
    await tester.pumpAndSettle();

    expect(find.textContaining('70.5 kg'), findsOneWidget);
  });
}

Widget _app(Widget child) {
  return MaterialApp(
    theme: ZenTheme.build(),
    home: Scaffold(body: child),
  );
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
