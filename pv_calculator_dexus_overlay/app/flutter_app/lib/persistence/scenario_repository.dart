import 'dart:convert';

import 'package:pv_engine/pv_engine.dart';

import 'database.dart';
import 'models.dart';
import 'uuid.dart';

/// CRUD for `scenarios`. Every mutation stamps `engine_version`
/// (`kEngineVersion`) and `input_hash` (`SimulationConfig.inputHash`) so
/// every scenario is traceable to the exact engine build that last wrote
/// it (PRD NFR-05).
class ScenarioRepository {
  ScenarioRepository(this._db);

  final AppDatabase _db;

  List<ScenarioRow> listForProject(String projectId) {
    final rows = _db.db.select(
      'SELECT id, project_id, site_id, name, description, config_json, '
      'engine_version, input_hash, created_at, updated_at '
      'FROM scenarios WHERE project_id = ? '
      'ORDER BY name COLLATE NOCASE ASC',
      [projectId],
    );
    return rows.map(_scenarioFromRow).toList(growable: false);
  }

  ScenarioRow? findById(String id) {
    final rows = _db.db.select(
      'SELECT id, project_id, site_id, name, description, config_json, '
      'engine_version, input_hash, created_at, updated_at '
      'FROM scenarios WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return _scenarioFromRow(rows.first);
  }

  ScenarioRow create({
    required String projectId,
    String? siteId,
    required String name,
    String? description,
    required SimulationConfig config,
  }) {
    final id = newUuidV4();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    _db.db.execute(
      'INSERT INTO scenarios('
      'id, project_id, site_id, name, description, config_json, '
      'engine_version, input_hash, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        projectId,
        siteId,
        name,
        description,
        jsonEncode(config.toJson()),
        kEngineVersion,
        config.inputHash,
        now,
        now,
      ],
    );
    return findById(id)!;
  }

  /// Replaces a scenario's config + description. Refreshes `engine_version`
  /// and `input_hash` to match the new config so callers don't have to
  /// remember which fields are derived.
  ScenarioRow update(
    String id, {
    required SimulationConfig config,
    String? description,
  }) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    _db.db.execute(
      'UPDATE scenarios SET config_json = ?, description = COALESCE(?, description), '
      'engine_version = ?, input_hash = ?, updated_at = ? '
      'WHERE id = ?',
      [
        jsonEncode(config.toJson()),
        description,
        kEngineVersion,
        config.inputHash,
        now,
        id,
      ],
    );
    return findById(id)!;
  }

  /// Renames without touching `input_hash` — a rename is metadata, not a
  /// new simulation input.
  ScenarioRow rename(String id, String newName) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    _db.db.execute(
      'UPDATE scenarios SET name = ?, updated_at = ? WHERE id = ?',
      [newName, now, id],
    );
    return findById(id)!;
  }

  /// Clones a scenario under the same project, new id, new timestamps.
  /// `engine_version` and `input_hash` are recomputed from the cloned
  /// config — identical to the source when no edits have been made, but
  /// independent rows afterwards.
  ScenarioRow duplicate(String id, {String? newName}) {
    final src = findById(id);
    if (src == null) throw ArgumentError('No scenario with id $id');
    return create(
      projectId: src.projectId,
      siteId: src.siteId,
      name: newName ?? _suggestDuplicateName(src),
      description: src.description,
      config: src.config,
    );
  }

  void delete(String id) {
    _db.db.execute('DELETE FROM scenarios WHERE id = ?', [id]);
  }

  String _suggestDuplicateName(ScenarioRow src) {
    final base = src.name;
    final siblings = listForProject(src.projectId).map((s) => s.name).toSet();
    for (var i = 2; i < 1000; i++) {
      final candidate = '$base ($i)';
      if (!siblings.contains(candidate)) return candidate;
    }
    return '$base ${DateTime.now().millisecondsSinceEpoch}';
  }

  ScenarioRow _scenarioFromRow(Map row) {
    final raw = jsonDecode(row['config_json'] as String) as Map<String, dynamic>;
    return ScenarioRow(
      id: row['id'] as String,
      projectId: row['project_id'] as String,
      siteId: row['site_id'] as String?,
      name: row['name'] as String,
      description: row['description'] as String?,
      config: SimulationConfig.fromJson(raw),
      engineVersion: row['engine_version'] as String,
      inputHash: row['input_hash'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int, isUtc: true),
    );
  }
}
