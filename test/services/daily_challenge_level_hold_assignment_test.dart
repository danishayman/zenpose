import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:zenpose/models/exercise_definition.dart';
import 'package:zenpose/models/exercise_step_definition.dart';
import 'package:zenpose/models/pose_template.dart';
import 'package:zenpose/services/admin_management_service.dart';
import 'package:zenpose/services/daily_challenge_service.dart';
import 'package:zenpose/services/database_service.dart';
import 'package:zenpose/services/pose_template_service.dart';

class _FakePoseTemplateService extends PoseTemplateService {
  final List<PoseTemplate> templates;

  _FakePoseTemplateService(this.templates);

  @override
  Future<List<PoseTemplate>> loadTemplates() async => templates;
}

class _FakeAdminManagementService extends AdminManagementService {
  final List<ExerciseDefinition> exercises;

  _FakeAdminManagementService(this.exercises);

  @override
  Future<List<ExerciseDefinition>> listExercises({
    bool activeOnly = false,
  }) async {
    if (!activeOnly) return exercises;
    return exercises.where((exercise) => exercise.isActive).toList();
  }
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

  test('new daily challenge snapshots hold seconds from rank tier', () async {
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

    final bronze = await service.getOrCreateChallenge(dateKey: '2026-04-10');
    expect(bronze.challenge.targetHoldSeconds, equals(20));
    expect(
      bronze.steps.map((step) => step.targetHoldSeconds).toList(),
      everyElement(20),
    );

    await db.incrementTotalXp(1000);
    final silver = await service.getOrCreateChallenge(dateKey: '2026-04-11');
    expect(silver.challenge.targetHoldSeconds, equals(30));
    expect(
      silver.steps.map((step) => step.targetHoldSeconds).toList(),
      everyElement(30),
    );

    await db.incrementTotalXp(2000);
    final gold = await service.getOrCreateChallenge(dateKey: '2026-04-12');
    expect(gold.challenge.targetHoldSeconds, equals(35));
    expect(
      gold.steps.map((step) => step.targetHoldSeconds).toList(),
      everyElement(35),
    );

    await db.incrementTotalXp(4000);
    final emerald = await service.getOrCreateChallenge(dateKey: '2026-04-13');
    expect(emerald.challenge.targetHoldSeconds, equals(40));
    expect(
      emerald.steps.map((step) => step.targetHoldSeconds).toList(),
      everyElement(40),
    );

    await db.incrementTotalXp(5000);
    final diamond = await service.getOrCreateChallenge(dateKey: '2026-04-14');
    expect(diamond.challenge.targetHoldSeconds, equals(45));
    expect(
      diamond.steps.map((step) => step.targetHoldSeconds).toList(),
      everyElement(45),
    );
  });

  test(
    'existing bronze challenge repairs stale challenge and step hold seconds',
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
      expect(first.steps.first.targetHoldSeconds, isNotNull);

      await db.updateDailyChallenge(
        first.challenge.copyWith(targetHoldSeconds: 45),
      );
      final staleTargets = <int>[25, 30, 45];
      for (var i = 0; i < first.steps.length; i++) {
        await db.updateDailyChallengeStep(
          first.steps[i].copyWith(
            targetHoldSeconds: staleTargets[i % staleTargets.length],
          ),
        );
      }

      final repaired = await service.getOrCreateChallenge(
        dateKey: '2026-04-13',
      );
      expect(repaired.challenge.targetHoldSeconds, equals(20));
      expect(
        repaired.steps.map((step) => step.targetHoldSeconds).toList(),
        everyElement(20),
      );
    },
  );

  test(
    'existing diamond challenge repairs stale low step hold seconds',
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
      await db.incrementTotalXp(12000);
      final reloaded = await service.getOrCreateChallenge(
        dateKey: '2026-04-13',
      );
      expect(first.challenge.targetHoldSeconds, equals(20));
      expect(reloaded.challenge.targetHoldSeconds, equals(45));
      expect(
        reloaded.steps.map((step) => step.targetHoldSeconds).toList(),
        everyElement(45),
      );
    },
  );

  test(
    'local repair normalizes stale pulled challenge and step targets',
    () async {
      final db = DatabaseService.instance;
      await db.database;
      final service = DailyChallengeService(
        databaseService: db,
        templateService: _FakePoseTemplateService(<PoseTemplate>[
          _template('chair', 'Chair'),
          _template('tree', 'Tree'),
        ]),
      );

      final first = await service.getOrCreateChallenge(dateKey: '2026-04-16');
      await db.updateDailyChallenge(
        first.challenge.copyWith(targetHoldSeconds: 45),
      );
      for (var i = 0; i < first.steps.length; i++) {
        await db.updateDailyChallengeStep(
          first.steps[i].copyWith(targetHoldSeconds: i.isEven ? 25 : 30),
        );
      }

      final changed = await db.normalizeDailyChallengeTargetsForActiveUser(
        targetHoldSeconds: 20,
      );
      final repairedChallenge = await db.getDailyChallengeByDateKey(
        '2026-04-16',
      );
      final repairedSteps = await db.getDailyChallengeSteps('2026-04-16');

      expect(changed, greaterThan(0));
      expect(repairedChallenge?.targetHoldSeconds, equals(20));
      expect(
        repairedSteps.map((step) => step.targetHoldSeconds).toList(),
        everyElement(20),
      );
    },
  );

  test('admin exercise step hold seconds use exact rank target', () async {
    final db = DatabaseService.instance;
    await db.database;
    await db.incrementTotalXp(12000);
    final service = DailyChallengeService(
      databaseService: db,
      templateService: _FakePoseTemplateService(<PoseTemplate>[
        _template('tree', 'Tree'),
        _template('plank', 'Plank'),
      ]),
      adminManagementService: _FakeAdminManagementService(<ExerciseDefinition>[
        ExerciseDefinition(
          id: 'flow-1',
          name: 'Custom Flow',
          description: '',
          isActive: true,
          createdBy: null,
          createdAt: null,
          updatedAt: null,
          steps: const <ExerciseStepDefinition>[
            ExerciseStepDefinition(
              stepIndex: 0,
              poseName: 'Tree',
              holdSeconds: 12,
              restSeconds: 30,
              updatedAt: null,
            ),
            ExerciseStepDefinition(
              stepIndex: 1,
              poseName: 'Plank',
              holdSeconds: 50,
              restSeconds: 30,
              updatedAt: null,
            ),
          ],
        ),
      ]),
    );

    final bundle = await service.getOrCreateChallenge(dateKey: '2026-04-15');

    expect(bundle.challenge.sequence, equals(<String>['Tree', 'Plank']));
    expect(
      bundle.steps.map((step) => step.targetHoldSeconds).toList(),
      equals(<int>[45, 45]),
    );
  });
}
