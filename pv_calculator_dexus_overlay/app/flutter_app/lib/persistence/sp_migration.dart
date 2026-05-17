import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pv_engine/pv_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database.dart';
import 'project_repository.dart';
import 'project_store.dart';
import 'scenario_repository.dart';

/// One-shot migration of legacy `shared_preferences`-backed projects into
/// the Phase-7 SQLite schema. The SP entries themselves are left in place
/// as a read-only fallback per the Phase-7 user decision.
///
/// Idempotency is **per entry**: every successful import writes a marker
/// row `sp_imported:<name>` to `app_meta`, so a subsequent launch skips
/// the names that already landed and retries only the ones that failed
/// last time (corrupt JSON, an older unsupported schema, transient insert
/// problems). Earlier installs that already saw the global
/// `sp_migrated_v1` marker still short-circuit at startup — once seen,
/// that marker keeps blocking SP processing for that database.
class SharedPreferencesMigration {
  SharedPreferencesMigration({
    required this.database,
    SharedPreferences? prefs,
  }) : _prefsOverride = prefs;

  /// Legacy global marker. Older installs may have this row set from a
  /// previous build that wrote it after every run; honour it as a hard
  /// short-circuit so we never re-walk a database that's already past
  /// this point.
  static const String legacyGlobalMarkerKey = 'sp_migrated_v1';

  /// Prefix for the per-entry marker. The key is `sp_imported:<SP name>`
  /// and the value is the migrated project's name in the SQLite store
  /// (which can differ from the SP name when a collision forced an
  /// `(imported)` suffix). Storing the new name keeps the audit trail
  /// useful and lets future debugging map old → new.
  static const String perEntryMarkerPrefix = 'sp_imported:';

  final AppDatabase database;
  final SharedPreferences? _prefsOverride;

  /// Walks the SP store and imports any entries that don't yet have a
  /// per-entry marker. Returns the count of newly imported projects.
  /// Failures on individual entries are logged and skipped without
  /// setting a marker — those entries will retry on the next launch.
  Future<int> migrateIfNeeded() async {
    if (_legacyGlobalDone()) return 0;

    final prefs = _prefsOverride ?? await SharedPreferences.getInstance();
    final store = ProjectStore(prefs: prefs);
    final names = await store.listProjects();
    if (names.isEmpty) return 0;

    final projects = ProjectRepository(database);
    final scenarios = ScenarioRepository(database);

    final existingProjectNames =
        projects.listProjects().map((p) => p.name).toSet();
    final alreadyImported = _alreadyImportedNames();
    var imported = 0;
    for (final name in names) {
      if (alreadyImported.contains(name)) continue;
      try {
        final raw = prefs.getString('${ProjectStore.entryPrefix}$name');
        if (raw == null) continue;
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final config = SimulationConfig.fromJson(json);

        var projectName = name;
        if (existingProjectNames.contains(projectName)) {
          projectName = _uniqueName(name, existingProjectNames);
        }
        existingProjectNames.add(projectName);

        final project = projects.createProject(
          name: projectName,
          latitudeDeg: config.latitudeDeg,
          longitudeDeg: config.longitudeDeg,
        );
        final site = projects.defaultSiteFor(project.id);
        scenarios.create(
          projectId: project.id,
          siteId: site?.id,
          name: 'Default',
          config: config,
        );
        _markImported(name, projectName);
        imported++;
      } catch (e, st) {
        debugPrint('sp_migration: skipped "$name" (will retry next launch): $e\n$st');
      }
    }
    return imported;
  }

  bool _legacyGlobalDone() {
    final rows = database.db.select(
      'SELECT value FROM app_meta WHERE key = ?',
      [legacyGlobalMarkerKey],
    );
    return rows.isNotEmpty;
  }

  Set<String> _alreadyImportedNames() {
    final rows = database.db.select(
      "SELECT key FROM app_meta WHERE key LIKE 'sp_imported:%'",
    );
    return {
      for (final r in rows)
        (r['key'] as String).substring(perEntryMarkerPrefix.length),
    };
  }

  void _markImported(String spName, String projectName) {
    database.db.execute(
      'INSERT OR REPLACE INTO app_meta(key, value) VALUES (?, ?)',
      ['$perEntryMarkerPrefix$spName', projectName],
    );
  }

  String _uniqueName(String base, Set<String> taken) {
    final candidate = '$base (imported)';
    if (!taken.contains(candidate)) return candidate;
    for (var i = 2; i < 1000; i++) {
      final next = '$base (imported $i)';
      if (!taken.contains(next)) return next;
    }
    return '$base ${DateTime.now().millisecondsSinceEpoch}';
  }
}
