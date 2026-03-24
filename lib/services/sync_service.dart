import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_context.dart';
import 'auth_service.dart';
import 'database_service.dart';

class SyncRunResult {
  final bool skipped;
  final int uploaded;
  final int pulled;
  final List<String> errors;

  const SyncRunResult({
    required this.skipped,
    required this.uploaded,
    required this.pulled,
    required this.errors,
  });
}

class SyncService {
  SyncService._internal();

  static final SyncService instance = SyncService._internal();

  final DatabaseService _db = DatabaseService.instance;
  final AuthService _auth = AuthService.instance;

  bool _enabled = false;
  bool _syncing = false;
  StreamSubscription<void>? _mutationSub;
  Timer? _periodicTimer;

  static const List<String> _tables = <String>[
    DatabaseService.tablePoseResults,
    DatabaseService.tableUserStats,
    DatabaseService.tableUserBadges,
    DatabaseService.tableDailyChallenges,
    DatabaseService.tableDailyChallengeSteps,
  ];

  static bool shouldLocalWin({
    required DateTime localUpdated,
    DateTime? remoteUpdated,
  }) {
    if (remoteUpdated == null) return true;
    return localUpdated.isAfter(remoteUpdated) ||
        localUpdated.isAtSameMomentAs(remoteUpdated);
  }

  void configure({required bool enabled}) {
    _enabled = enabled;
  }

  Future<void> scheduleAutoSync() async {
    if (!_enabled) return;
    _mutationSub?.cancel();
    _mutationSub = _db.mutationStream.listen((_) {
      unawaited(syncNow());
    });
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      unawaited(syncNow());
    });
    await syncNow();
  }

  Future<void> dispose() async {
    await _mutationSub?.cancel();
    _periodicTimer?.cancel();
  }

  Future<SyncRunResult> syncNow() async {
    if (!_enabled) {
      return const SyncRunResult(
        skipped: true,
        uploaded: 0,
        pulled: 0,
        errors: <String>[],
      );
    }
    if (_syncing) {
      return const SyncRunResult(
        skipped: true,
        uploaded: 0,
        pulled: 0,
        errors: <String>[],
      );
    }
    if (!_auth.authState.value.isAuthenticated) {
      return const SyncRunResult(
        skipped: true,
        uploaded: 0,
        pulled: 0,
        errors: <String>[],
      );
    }

    _syncing = true;
    final client = Supabase.instance.client;
    var uploaded = 0;
    var pulled = 0;
    final errors = <String>[];
    final userId = AuthContext.activeUserId;

    try {
      for (final table in _tables) {
        final unsynced = await _db.getUnsyncedRows(tableName: table);
        for (final localRow in unsynced) {
          try {
            final keys = _keysForRow(table, localRow);
            final remote = await client
                .from(table)
                .select()
                .match(_stringifyMap(keys))
                .maybeSingle();
            final localUpdated = _parseDate(
              localRow[DatabaseService.columnUpdatedAt],
            );
            final remoteUpdated = _parseDate(
              remote?[DatabaseService.columnUpdatedAt],
            );
            if (remote == null ||
                shouldLocalWin(
                  localUpdated: localUpdated,
                  remoteUpdated: remoteUpdated,
                )) {
              await client
                  .from(table)
                  .upsert(
                    _remotePayload(table, localRow),
                    onConflict: _onConflict(table),
                  );
              await _db.markRowSynced(tableName: table, keyValues: keys);
              uploaded += 1;
            } else {
              final remoteRow = Map<String, Object?>.from(remote);
              remoteRow[DatabaseService.columnUserId] = userId;
              await _db.upsertRowFromSync(tableName: table, row: remoteRow);
              await _db.markRowSynced(tableName: table, keyValues: keys);
              pulled += 1;
            }
          } catch (e) {
            errors.add('$table upload: $e');
          }
        }

        try {
          final remoteRows = await client
              .from(table)
              .select()
              .eq(DatabaseService.columnUserId, userId);
          final rows = (remoteRows as List<dynamic>)
              .map((e) => Map<String, Object?>.from(e as Map))
              .toList(growable: false);
          for (final remoteRow in rows) {
            final keys = _keysForRow(table, remoteRow);
            final local = await _db.getRowByKeys(
              tableName: table,
              keyValues: keys,
            );
            if (local == null) {
              await _db.upsertRowFromSync(tableName: table, row: remoteRow);
              pulled += 1;
              continue;
            }
            final remoteUpdated = _parseDate(
              remoteRow[DatabaseService.columnUpdatedAt],
            );
            final localUpdated = _parseDate(
              local[DatabaseService.columnUpdatedAt],
            );
            if (remoteUpdated.isAfter(localUpdated)) {
              await _db.upsertRowFromSync(tableName: table, row: remoteRow);
              pulled += 1;
            }
          }
        } catch (e) {
          errors.add('$table pull: $e');
        }
      }
    } finally {
      _syncing = false;
    }

    return SyncRunResult(
      skipped: false,
      uploaded: uploaded,
      pulled: pulled,
      errors: errors,
    );
  }

  Map<String, Object?> _keysForRow(String table, Map<String, Object?> row) {
    final keys = _db.tableKeyColumns(table);
    return <String, Object?>{for (final key in keys) key: row[key]};
  }

  String _onConflict(String table) => _db.tableKeyColumns(table).join(',');

  Map<String, Object?> _remotePayload(String table, Map<String, Object?> row) {
    final payload = Map<String, Object?>.from(row);
    payload.remove(DatabaseService.columnIsSynced);
    payload.remove(DatabaseService.columnId);
    payload[DatabaseService.columnUserId] = AuthContext.activeUserId;
    return payload;
  }

  Map<String, Object> _stringifyMap(Map<String, Object?> map) {
    return <String, Object>{
      for (final entry in map.entries)
        if (entry.value != null) entry.key: entry.value as Object,
    };
  }

  DateTime _parseDate(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
