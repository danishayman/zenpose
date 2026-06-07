import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/constants/session_launch_config.dart';
import 'package:zenpose/models/pose_template.dart';
import 'package:zenpose/screens/pre_session_intro_screen.dart';
import 'package:zenpose/widgets/pose_thumbnail_image.dart';
import 'package:zenpose/widgets/pre_session_countdown_widgets.dart';

PoseTemplate _template({String key = 'downdog'}) {
  return PoseTemplate(
    templateKey: key,
    name: key == 'plank' ? 'Plank' : 'Downdog',
    meanVector: List<double>.filled(24, 0.0),
  );
}

void main() {
  testWidgets('instructions show and camera opens only after tapping button', (
    tester,
  ) async {
    var destinationBuilds = 0;
    Duration? launchedHoldDuration;

    await tester.pumpWidget(
      MaterialApp(
        home: PreSessionIntroScreen(
          template: _template(key: 'plank'),
          countdownSeconds: SessionLaunchConfig.preSessionCountdownSeconds,
          destinationBuilder: (context, template, holdDuration) {
            destinationBuilds += 1;
            launchedHoldDuration = holdDuration;
            return const Scaffold(body: Center(child: Text('DESTINATION')));
          },
        ),
      ),
    );

    expect(find.text('How to do Plank'), findsOneWidget);
    expect(find.text('Place hands under shoulders.'), findsOneWidget);
    expect(find.text('Step both feet back.'), findsOneWidget);
    expect(find.text('Keep body in one line.'), findsOneWidget);
    expect(find.text('Tighten your core.'), findsOneWidget);
    expect(find.text('Open Camera'), findsOneWidget);
    expect(find.text('DESTINATION'), findsNothing);

    await tester.pump(
      Duration(seconds: SessionLaunchConfig.preSessionCountdownSeconds + 3),
    );
    await tester.pumpAndSettle();

    expect(find.text('DESTINATION'), findsNothing);
    expect(destinationBuilds, 0);

    tester.widget<Slider>(find.byType(Slider)).onChanged?.call(60);
    await tester.pump();
    expect(find.text('60s'), findsOneWidget);

    await tester.tap(find.text('Open Camera'));
    await tester.pumpAndSettle();

    expect(find.text('DESTINATION'), findsOneWidget);
    expect(destinationBuilds, 1);
    expect(launchedHoldDuration, const Duration(seconds: 60));

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(destinationBuilds, 1);
  });

  testWidgets('missing gif falls back to placeholder without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PoseDemoAnimation(template: _template(key: 'missing_pose')),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.self_improvement_rounded), findsOneWidget);
  });

  testWidgets('missing thumbnail falls back to placeholder without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PoseThumbnailImage(template: _template(key: 'missing_pose')),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.self_improvement_rounded), findsOneWidget);
  });
}
