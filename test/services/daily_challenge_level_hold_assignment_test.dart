import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:zenpose/models/pose_template.dart';
import 'package:zenpose/services/daily_challenge_service.dart';
import 'package:zenpose/services/database_service.dart';
import 'package:zenpose/services/pose_template_service.dart';

class _FakePoseTemplateService extends PoseTemplateService {
  final List<PoseTemplate> templates;

  _FakePoseTemplateService(this.templates);

  @override
  Future<List<PoseTemplate>> loadTemplates() async => templates;
}

PoseTemplate _template(String key, String name) {
  return PoseTemplate(
    templateKey: key,
    name: name,
    meanVector: List<double>.filled(24, 0),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.setDatabaseNameOverrideForTesting(
      'yoga_trainer_daily_challenge_level_hold_test.db',
    );
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
    DatabaseService.setDatabaseNameOverrideForTesting(null);
  });

  Future<String> dbPathForTest() async {
    final root = await getDatabasesPath();
    return p.join(root, DatabaseService.effectiveDatabaseName);
  }

  tearDown(() async {
    await DatabaseService.instance.close();
    final path = await dbPathForTest();
    await deleteDatabase(path);
  });

  test('new daily challenge snapshots hold seconds from XP band', () async {
    final db = DatabaseService.instance;
    await db.database;
    final service = DailyChallengeService(
      databaseService: db,
      templateService: _FakePoseTemplateService(<PoseTemplate>[
        _template('downdog', 'Downdog'),
        _template('tree', 'Tree'),
        _template('plank', 'Plank'),
      ]),
    );

    final beginner = await service.getOrCreateChallenge(dateKey: '2026-04-10');
    expect(beginner.challenge.targetHoldSeconds, equals(20));

    await db.incrementTotalXp(1000);
    final intermediate = await service.getOrCreateChallenge(
      dateKey: '2026-04-11',
    );
    expect(intermediate.challenge.targetHoldSeconds, equals(35));

    await db.incrementTotalXp(2000);
    final advanced = await service.getOrCreateChallenge(dateKey: '2026-04-12');
    expect(advanced.challenge.targetHoldSeconds, equals(45));
  });

  test(
    'existing challenge keeps snapshotted hold seconds after XP changes',
    () async {
      final db = DatabaseService.instance;
      await db.database;
      final service = DailyChallengeService(
        databaseService: db,
        templateService: _FakePoseTemplateService(<PoseTemplate>[
          _template('downdog', 'Downdog'),
          _template('tree', 'Tree'),
        ]),
      );

      final first = await service.getOrCreateChallenge(dateKey: '2026-04-13');
      expect(first.challenge.targetHoldSeconds, equals(20));

      await db.incrementTotalXp(5000);
      final reloaded = await service.getOrCreateChallenge(
        dateKey: '2026-04-13',
      );
      expect(reloaded.challenge.targetHoldSeconds, equals(20));
    },
  );
}
