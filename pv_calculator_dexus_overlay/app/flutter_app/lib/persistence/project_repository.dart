import 'database.dart';
import 'models.dart';
import 'uuid.dart';

/// CRUD for `projects` and the auto-created default site under each
/// project. Sites are not yet exposed in the UI — every new project gets
/// exactly one default site so a scenario always has a non-null `site_id`
/// to fall back on for lat/lon when needed.
class ProjectRepository {
  ProjectRepository(this._db);

  final AppDatabase _db;

  List<ProjectRow> listProjects() {
    final rows = _db.db.select(
      'SELECT id, name, description, created_at, updated_at, schema_version '
      'FROM projects ORDER BY name COLLATE NOCASE ASC',
    );
    return rows.map(_projectFromRow).toList(growable: false);
  }

  ProjectRow? findById(String id) {
    final rows = _db.db.select(
      'SELECT id, name, description, created_at, updated_at, schema_version '
      'FROM projects WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return _projectFromRow(rows.first);
  }

  /// Inserts a project plus a default site. Returns the new project row.
  /// `latitudeDeg`/`longitudeDeg` seed the auto-created site so the
  /// first scenario opens with sensible coordinates.
  ProjectRow createProject({
    required String name,
    String? description,
    double latitudeDeg = 50.0,
    double longitudeDeg = 10.0,
  }) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final projectId = newUuidV4();
    final siteId = newUuidV4();
    _db.db.execute(
      'INSERT INTO projects(id, name, description, created_at, updated_at, schema_version) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [projectId, name, description, now, now, 1],
    );
    _db.db.execute(
      'INSERT INTO sites(id, project_id, name, latitude_deg, longitude_deg, timezone, country_code) '
      'VALUES (?, ?, ?, ?, ?, NULL, NULL)',
      [siteId, projectId, 'Standort', latitudeDeg, longitudeDeg],
    );
    return findById(projectId)!;
  }

  void renameProject(String id, String newName) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    _db.db.execute(
      'UPDATE projects SET name = ?, updated_at = ? WHERE id = ?',
      [newName, now, id],
    );
  }

  /// FK cascade removes sites, scenarios and simulation_runs.
  void deleteProject(String id) {
    _db.db.execute('DELETE FROM projects WHERE id = ?', [id]);
  }

  /// First site for [projectId], or null if none. Used as the default
  /// site target when creating a scenario from the UI — the user never
  /// sees the site picker for MVP.
  SiteRow? defaultSiteFor(String projectId) {
    final rows = _db.db.select(
      'SELECT id, project_id, name, latitude_deg, longitude_deg, timezone, country_code '
      'FROM sites WHERE project_id = ? ORDER BY name ASC LIMIT 1',
      [projectId],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return SiteRow(
      id: r['id'] as String,
      projectId: r['project_id'] as String,
      name: r['name'] as String,
      latitudeDeg: (r['latitude_deg'] as num).toDouble(),
      longitudeDeg: (r['longitude_deg'] as num).toDouble(),
      timezone: r['timezone'] as String?,
      countryCode: r['country_code'] as String?,
    );
  }

  ProjectRow _projectFromRow(Map row) => ProjectRow(
        id: row['id'] as String,
        name: row['name'] as String,
        description: row['description'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int, isUtc: true),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int, isUtc: true),
        schemaVersion: row['schema_version'] as int,
      );
}
