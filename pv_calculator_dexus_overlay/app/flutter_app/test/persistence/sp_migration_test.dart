import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/persistence/database.dart';
import 'package:pv_calculator_app/persistence/project_repository.dart';
import 'package:pv_calculator_app/persistence/project_store.dart';
import 'package:pv_calculator_app/persistence/scenario_repository.dart';
import 'package:pv_calculator_app/persistence/sp_migration.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _seedSp(Map<String, String> projects) async {
  final indexValue = jsonEncode(projects.keys.toList());
  SharedPreferences.setMockInitialValues({
    ProjectStore.indexKey: indexValue,
    for (final entry in projects.entries)
      '${ProjectStore.entryPrefix}${entry.key}': entry.value,
  });
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  test('migrates each SP project into a project + Default scenario', () async {
    final config = ConfigDraft.demo().build();
    await _seedSp({
      'House 1': jsonEncode(config.toJson()),
      'House 2': jsonEncode(config.toJson()),
    });

    final imported =
        await SharedPreferencesMigration(database: db).migrateIfNeeded();
    expect(imported, equals(2));

    final projects = ProjectRepository(db).listProjects();
    expect(projects.map((p) => p.name).toSet(), equals({'House 1', 'House 2'}));

    final scenarios = ScenarioRepository(db);
    for (final p in projects) {
      final list = scenarios.listForProject(p.id);
      expect(list, hasLength(1));
      expect(list.first.name, equals('Default'));
    }
  });

  test('a second run is a no-op (idempotent via per-entry markers)', () async {
    final config = ConfigDraft.demo().build();
    await _seedSp({'House 1': jsonEncode(config.toJson())});

    final first = await SharedPreferencesMigration(database: db).migrateIfNeeded();
    final second = await SharedPreferencesMigration(database: db).migrateIfNeeded();
    expect(first, equals(1));
    expect(second, equals(0));
    expect(ProjectRepository(db).listProjects(), hasLength(1));
  });

  test('a corrupt SP entry is skipped without aborting the rest', () async {
    final config = ConfigDraft.demo().build();
    await _seedSp({
      'Good': jsonEncode(config.toJson()),
      'Bad': 'not json',
    });

    final imported =
        await SharedPreferencesMigration(database: db).migrateIfNeeded();
    expect(imported, equals(1));
    final names = ProjectRepository(db).listProjects().map((p) => p.name);
    expect(names, equals(['Good']));
  });

  test('a skipped entry retries on the next launch once the SP value is fixed', () async {
    final config = ConfigDraft.demo().build();
    final validJson = jsonEncode(config.toJson());
    await _seedSp({
      'Good': validJson,
      'Bad': 'not json',
    });

    final first =
        await SharedPreferencesMigration(database: db).migrateIfNeeded();
    expect(first, equals(1),
        reason: 'Good imports, Bad is skipped without a marker');

    // Simulate the user repairing the corrupt entry (or a newer build
    // shipping an SP-shape fix). The Good entry already has its
    // per-entry marker so it must not double-import.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${ProjectStore.entryPrefix}Bad', validJson);

    final second =
        await SharedPreferencesMigration(database: db).migrateIfNeeded();
    expect(second, equals(1), reason: 'Bad now succeeds, Good is skipped');
    final names = ProjectRepository(db).listProjects().map((p) => p.name).toSet();
    expect(names, equals({'Good', 'Bad'}));
  });

  test('the legacy sp_migrated_v1 marker still short-circuits the migration', () async {
    // Simulate an install that ran the previous global-marker build.
    db.db.execute(
      "INSERT INTO app_meta(key, value) VALUES (?, 'true')",
      [SharedPreferencesMigration.legacyGlobalMarkerKey],
    );
    final config = ConfigDraft.demo().build();
    await _seedSp({'House 1': jsonEncode(config.toJson())});

    final imported =
        await SharedPreferencesMigration(database: db).migrateIfNeeded();
    expect(imported, equals(0));
    expect(ProjectRepository(db).listProjects(), isEmpty);
  });

  test('a name collision with an existing project gets the (imported) suffix', () async {
    final projects = ProjectRepository(db);
    projects.createProject(name: 'House 1');

    final config = ConfigDraft.demo().build();
    await _seedSp({'House 1': jsonEncode(config.toJson())});

    await SharedPreferencesMigration(database: db).migrateIfNeeded();

    final names = projects.listProjects().map((p) => p.name).toSet();
    expect(names, equals({'House 1', 'House 1 (imported)'}));
  });

  test('an empty SP store still marks the migration done', () async {
    SharedPreferences.setMockInitialValues({});
    final imported =
        await SharedPreferencesMigration(database: db).migrateIfNeeded();
    expect(imported, equals(0));

    // A second migration must remain a no-op.
    final second =
        await SharedPreferencesMigration(database: db).migrateIfNeeded();
    expect(second, equals(0));
  });
}
