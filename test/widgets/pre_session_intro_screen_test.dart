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
    name: 'Downdog',
    meanVector: List<double>.filled(24, 0.0),
  );
}

void main() {
  testWidgets('countdown shows values and launches destination once', (
    tester,
  ) async {
    var destinationBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: PreSessionIntroScreen(
          template: _template(),
          countdownSeconds: SessionLaunchConfig.preSessionCountdownSeconds,
          destinationBuilder: (context, template, holdDuration) {
            destinationBuilds += 1;
            return const Scaffold(body: Center(child: Text('DESTINATION')));
          },
        ),
      ),
    );

    expect(find.text('Get Ready'), findsOneWidget);
    expect(
      find.text('${SessionLaunchConfig.preSessionCountdownSeconds}'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('${SessionLaunchConfig.preSessionCountdownSeconds - 1}'),
      findsOneWidget,
    );

    await tester.pump(
      Duration(seconds: SessionLaunchConfig.preSessionCountdownSeconds - 1),
    );
    await tester.pumpAndSettle();

    expect(find.text('DESTINATION'), findsOneWidget);
    expect(destinationBuilds, 1);

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
