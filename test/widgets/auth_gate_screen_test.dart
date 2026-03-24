import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/screens/auth_gate_screen.dart';
import 'package:zenpose/services/auth_service.dart';

void main() {
  testWidgets('auth gate shows app shell when auth is unconfigured', (
    tester,
  ) async {
    AuthService.instance.configure(enabled: false);
    await tester.binding.setSurfaceSize(const Size(1200, 2200));

    await tester.pumpWidget(const MaterialApp(home: AuthGateScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
}
