import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pv_engine/pv_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database.dart';
import 'project_repository.dart';
import 'project_store.dart';
import 'scenario_repository.dart';

/// One-shot migration of legacy `shared_preferences`-backed projects into
/// the Drift-style schema. The SP entries are **not** removed — they stay
/// in place as a read-only fallback for one release window, per the user
/// decision recorded in the Phase-7 plan. The migration is idempotent: a
/// marker row in `app_meta` prevents a second pass from duplicating data.
class SharedPreferencesMigration {
  SharedPreferencesMigration({
    required this.database,
    SharedPreferences? prefs,
  }) : _prefsOverride = prefs;

  static const String markerKey = 'sp_migrated_v1';

  final AppDatabase database;
  final SharedPreferences? _prefsOverride;

  /// Runs the migration if it hasn't already. Returns the number of
  /// projects imported; `0` for a no-op (either no SP entries exist, or
  /// the migration has already run). Errors on individual entries are
  /// swallowed with a `debugPrint` — one corrupt SP entry must not stall
  /// the whole import, and the original SP key is left intact so the
  /// user can still recover it manually.
  Future<int> migrateIfNeeded() async {
    if (_alreadyMigrated()) return 0;

    final prefs = _prefsOverride ?? await SharedPreferences.getInstance();
    final store = ProjectStore(prefs: prefs);
    final names = await store.listProjects();
    if (names.isEmpty) {
      _markDone();
      return 0;
    }

    final projects = ProjectRepository(database);
    final scenarios = ScenarioRepository(database);

    final existingProjectNames =
        projects.listProjects().map((p) => p.name).toSet();
    var imported = 0;
    for (final name in names) {
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
        imported++;
      } catch (e, st) {
        debugPrint('sp_migration: skipped "$name": $e\n$st');
      }
    }

    _markDone();
    return imported;
  }

  bool _alreadyMigrated() {
    final rows = database.db.select(
      'SELECT value FROM app_meta WHERE key = ?',
      [markerKey],
    );
    return rows.isNotEmpty;
  }

  void _markDone() {
    database.db.execute(
      'INSERT OR REPLACE INTO app_meta(key, value) VALUES (?, ?)',
      [markerKey, 'true'],
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
