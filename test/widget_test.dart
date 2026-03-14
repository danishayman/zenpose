import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zenpose/screens/app_shell_screen.dart';
import 'package:zenpose/theme/zen_theme.dart';

void main() {
  testWidgets('bottom tab navigation switches tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ZenTheme.build(),
        home: AppShellScreen(
          tabsOverride: const <Widget>[
            Center(child: Text('HOME_TAB')),
            Center(child: Text('PRACTICE_TAB')),
            Center(child: Text('PROGRESS_TAB')),
            Center(child: Text('PROFILE_TAB')),
          ],
        ),
      ),
    );

    expect(find.text('HOME_TAB'), findsOneWidget);
    expect(find.text('PRACTICE_TAB'), findsNothing);
    expect(find.text('PROGRESS_TAB'), findsNothing);
    expect(find.text('PROFILE_TAB'), findsNothing);

    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();
    expect(find.text('PRACTICE_TAB'), findsOneWidget);

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('PROGRESS_TAB'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('PROFILE_TAB'), findsOneWidget);
  });
}
