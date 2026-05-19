import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/persistence/database.dart';
import 'package:pv_calculator_app/persistence/project_repository.dart';
import 'package:pv_calculator_app/persistence/schema.dart';
import 'package:pv_calculator_app/persistence/scenario_repository.dart';
import 'package:pv_calculator_app/persistence/simulation_run_repository.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_engine/pv_engine.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() => db.close());

  test('schema bootstrap creates all four tables and pins schema_version', () {
    final tables = db.db
        .select(
          "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
        )
        .map((r) => r['name'] as String)
        .toList();
    expect(
      tables,
      containsAll(<String>[
        'projects',
        'sites',
        'scenarios',
        'simulation_runs',
        'app_meta',
        'component_catalog',
        'irradiance_cache',
      ]),
    );
    final version = db.db
        .select("SELECT value FROM app_meta WHERE key = 'schema_version'")
        .first['value'];
    expect(version, equals(currentSchemaVersion.toString()));
  });

  test('ProjectRepository.createProject auto-creates a default site', () {
    final repo = ProjectRepository(db);
    final project = repo.createProject(name: 'My House', latitudeDeg: 52.5, longitudeDeg: 13.4);
    expect(project.name, equals('My House'));
    final site = repo.defaultSiteFor(project.id);
    expect(site, isNotNull);
    expect(site!.latitudeDeg, closeTo(52.5, 1e-9));
    expect(site.longitudeDeg, closeTo(13.4, 1e-9));
  });

  test('ScenarioRepository round-trips a SimulationConfig and stamps engine version + hash', () {
    final projects = ProjectRepository(db);
    final scenarios = ScenarioRepository(db);
    final project = projects.createProject(name: 'Demo');
    final site = projects.defaultSiteFor(project.id);

    final config = ConfigDraft.demo().build();
    final created = scenarios.create(
      projectId: project.id,
      siteId: site?.id,
      name: 'Base',
      config: config,
    );

    expect(created.engineVersion, equals(kEngineVersion));
    expect(created.inputHash, equals(config.inputHash));

    final reread = scenarios.findById(created.id)!;
    expect(reread.config.toJson(), equals(config.toJson()));
  });

  test('ScenarioRepository.duplicate clones config under the same project with a fresh id', () {
    final projects = ProjectRepository(db);
    final scenarios = ScenarioRepository(db);
    final project = projects.createProject(name: 'P');
    final source = scenarios.create(
      projectId: project.id,
      siteId: projects.defaultSiteFor(project.id)?.id,
      name: 'Base',
      config: ConfigDraft.demo().build(),
    );
    final dup = scenarios.duplicate(source.id);
    expect(dup.id, isNot(equals(source.id)));
    expect(dup.projectId, equals(source.projectId));
    expect(dup.name, isNot(equals(source.name)));
    expect(dup.inputHash, equals(source.inputHash),
        reason: 'unchanged config keeps the same hash');
  });

  test('Project cascade delete removes scenarios and runs', () {
    final projects = ProjectRepository(db);
    final scenarios = ScenarioRepository(db);
    final runs = SimulationRunRepository(db);
    final project = projects.createProject(name: 'X');
    final scenario = scenarios.create(
      projectId: project.id,
      name: 'S',
      config: ConfigDraft.demo().build(),
    );
    runs.recordRun(
      scenarioId: scenario.id,
      startedAt: DateTime.utc(2026),
      finishedAt: DateTime.utc(2026, 1, 1, 0, 0, 1),
      inputHash: scenario.inputHash,
      summary: const SimulationSummary(
        pvDcKwh: 0,
        pvAcKwh: 0,
        loadKwh: 0,
        selfConsumptionKwh: 0,
        batteryChargeKwh: 0,
        batteryDischargeKwh: 0,
        gridImportKwh: 0,
        gridExportKwh: 0,
        curtailedDcKwh: 0,
        curtailedAcKwh: 0,
        curtailedExportKwh: 0,
        finalBatterySocKwh: 0,
        finalBatterySocsKwh: [],
      ),
    );

    projects.deleteProject(project.id);

    expect(scenarios.findById(scenario.id), isNull);
    expect(runs.latestFor(scenario.id), isNull);
    expect(projects.defaultSiteFor(project.id), isNull);
  });

  test('SimulationRunRepository.latestMatching returns the most recent matching hash', () {
    final projects = ProjectRepository(db);
    final scenarios = ScenarioRepository(db);
    final runs = SimulationRunRepository(db);
    final project = projects.createProject(name: 'X');
    final scenario = scenarios.create(
      projectId: project.id,
      name: 'S',
      config: ConfigDraft.demo().build(),
    );

    const empty = SimulationSummary(
      pvDcKwh: 0,
      pvAcKwh: 0,
      loadKwh: 0,
      selfConsumptionKwh: 0,
      batteryChargeKwh: 0,
      batteryDischargeKwh: 0,
      gridImportKwh: 0,
      gridExportKwh: 0,
      curtailedDcKwh: 0,
      curtailedAcKwh: 0,
      curtailedExportKwh: 0,
      finalBatterySocKwh: 0,
      finalBatterySocsKwh: [],
    );
    runs.recordRun(
      scenarioId: scenario.id,
      startedAt: DateTime.utc(2026, 1, 1, 0, 0),
      finishedAt: DateTime.utc(2026, 1, 1, 0, 0, 1),
      inputHash: 'hashA',
      summary: empty,
    );
    runs.recordRun(
      scenarioId: scenario.id,
      startedAt: DateTime.utc(2026, 1, 1, 1, 0),
      finishedAt: DateTime.utc(2026, 1, 1, 1, 0, 1),
      inputHash: 'hashB',
      summary: empty,
    );

    expect(runs.latestMatching(scenario.id, 'hashA')?.inputHash, equals('hashA'));
    expect(runs.latestMatching(scenario.id, 'hashB')?.inputHash, equals('hashB'));
    expect(runs.latestMatching(scenario.id, 'hashC'), isNull);
    expect(runs.latestFor(scenario.id)?.inputHash, equals('hashB'),
        reason: 'latestFor returns the most recently finished run');
  });

  test('summaryFromJson defaults perYearMonthly to const [] when absent', () {
    // Simulates a v4-vintage cache row that pre-dates the per-year
    // monthly buckets: the codec must accept the missing key and
    // return an empty list rather than throwing.
    final legacy = <String, dynamic>{
      'pvDcKwh': 1.0,
      'pvAcKwh': 0.95,
      'loadKwh': 2.0,
      'selfConsumptionKwh': 0.8,
      'batteryChargeKwh': 0.3,
      'batteryDischargeKwh': 0.25,
      'gridImportKwh': 1.2,
      'gridExportKwh': 0.15,
      'curtailedDcKwh': 0.0,
      'curtailedAcKwh': 0.0,
      'curtailedExportKwh': 0.0,
      'finalBatterySocKwh': 1.5,
      'finalBatterySocsKwh': <double>[1.5],
      'microInverterDeliveredKwh': 0.0,
      'microInverterShortfallKwh': 0.0,
      'unservedLoadKwh': 0.0,
      'preRunMode': 'singleWarmUp',
      'preRunActive': false,
      'startSocsUsedKwh': <double>[2.5],
      'convergenceIterations': 0,
      'converged': true,
    };
    final loaded = summaryFromJson(legacy);
    expect(loaded.perYearSummaries, isEmpty);
    expect(loaded.perYearMonthly, isEmpty);
    // Encoding back without per-year fields must drop both keys.
    final reencoded = summaryToJson(loaded);
    expect(reencoded.containsKey('perYearSummaries'), isFalse);
    expect(reencoded.containsKey('perYearMonthly'), isFalse);
  });

  test('summaryToJson + summaryFromJson preserve perYearMonthly buckets', () {
    final per = <List<MonthlyBucket>>[
      for (var y = 1; y <= 3; y++)
        [
          for (var m = 1; m <= 12; m++)
            MonthlyBucket(
              month: m,
              pvAcKwh: y * 100.0 + m,
              loadKwh: 50.0,
              selfConsumptionKwh: 40.0,
              batteryChargeKwh: 10.0,
              batteryDischargeKwh: 8.0,
              gridImportKwh: 20.0,
              gridExportKwh: 5.0,
              curtailedDcKwh: 0.1,
              curtailedAcKwh: 0.05,
              curtailedExportKwh: 0.02,
              importCostEur: 6.0,
              exportRevenueEur: 0.5,
            ),
        ],
    ];
    final original = SimulationSummary(
      pvDcKwh: 1000, pvAcKwh: 950, loadKwh: 600, selfConsumptionKwh: 480,
      batteryChargeKwh: 120, batteryDischargeKwh: 96,
      gridImportKwh: 240, gridExportKwh: 60,
      curtailedDcKwh: 3.6, curtailedAcKwh: 1.8, curtailedExportKwh: 0.72,
      finalBatterySocKwh: 4.0, finalBatterySocsKwh: const [4.0],
      perYearSummaries: List.unmodifiable([
        for (var i = 0; i < 3; i++)
          const SimulationSummary(
            pvDcKwh: 333, pvAcKwh: 316,
            loadKwh: 200, selfConsumptionKwh: 160,
            batteryChargeKwh: 40, batteryDischargeKwh: 32,
            gridImportKwh: 80, gridExportKwh: 20,
            curtailedDcKwh: 1.2, curtailedAcKwh: 0.6, curtailedExportKwh: 0.24,
            finalBatterySocKwh: 4.0, finalBatterySocsKwh: [4.0],
          ),
      ]),
      perYearMonthly: List.unmodifiable(per),
    );
    final reloaded = summaryFromJson(summaryToJson(original));
    expect(reloaded.perYearMonthly, hasLength(3));
    for (var y = 0; y < 3; y++) {
      final round = reloaded.perYearMonthly[y];
      final orig = original.perYearMonthly[y];
      expect(round, hasLength(12));
      for (var m = 0; m < 12; m++) {
        expect(round[m].month, orig[m].month);
        expect(round[m].pvAcKwh, closeTo(orig[m].pvAcKwh, 1e-12));
        expect(round[m].importCostEur, closeTo(orig[m].importCostEur, 1e-12));
        expect(round[m].exportRevenueEur,
            closeTo(orig[m].exportRevenueEur, 1e-12));
      }
    }
  });
}
