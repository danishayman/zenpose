import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/services/sync_service.dart';

void main() {
  group('SyncService.shouldLocalWin', () {
    test('returns true when remote row is missing', () {
      final decision = SyncService.shouldLocalWin(
        localUpdated: DateTime.utc(2026, 3, 14, 10, 0, 0),
        remoteUpdated: null,
      );
      expect(decision, isTrue);
    });

    test('returns true when local row is newer', () {
      final decision = SyncService.shouldLocalWin(
        localUpdated: DateTime.utc(2026, 3, 14, 11, 0, 0),
        remoteUpdated: DateTime.utc(2026, 3, 14, 10, 59, 59),
      );
      expect(decision, isTrue);
    });

    test('returns false when remote row is newer', () {
      final decision = SyncService.shouldLocalWin(
        localUpdated: DateTime.utc(2026, 3, 14, 9, 0, 0),
        remoteUpdated: DateTime.utc(2026, 3, 14, 9, 0, 1),
      );
      expect(decision, isFalse);
    });
  });
}
