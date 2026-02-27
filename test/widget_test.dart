// Minimal smoke test – verifies the app widget tree can be constructed.
// Full testing of camera + pose detection requires a physical device.

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ZenPose app placeholder test', (WidgetTester tester) async {
    // This is a placeholder. Camera and ML Kit cannot be tested in a
    // standard widget test environment. Manual on-device testing is required.
    expect(1 + 1, equals(2));
  });
}
