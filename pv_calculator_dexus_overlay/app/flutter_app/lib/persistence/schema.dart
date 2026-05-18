/// Relational schema for the Phase-7 persistence layer
/// (Architektur §7, ROADMAP.md §Phase 7).
///
/// One project owns one or more sites; one site owns one or more scenarios;
/// each scenario can have many simulation runs. Domain-specific structures
/// (PV arrays, inverters, batteries, banks, load profile, topology, dispatch
/// policy) stay denormalized inside `scenarios.config_json` — the engine's
/// own schema-versioned JSON already handles them, so the relational layer
/// remains thin and easy to migrate.
///
/// `currentSchemaVersion` is the on-disk version this build understands.
/// Bump it when adding columns or tables and add a corresponding `from N to
/// N+1` block in [AppDatabase._upgrade].
const int currentSchemaVersion = 2;

/// Statements executed on a fresh database. Listed once here so tests and
/// production share the same source of truth. `IF NOT EXISTS` keeps re-runs
/// idempotent for in-memory test fixtures.
const List<String> createStatements = [
  // FK pragma must be set per connection; statement is included so the
  // migration helper can re-issue it after schema upgrades.
  'PRAGMA foreign_keys = ON',
  '''
    CREATE TABLE IF NOT EXISTS projects (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      schema_version INTEGER NOT NULL
    )
  ''',
  '''
    CREATE TABLE IF NOT EXISTS sites (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      name TEXT NOT NULL,
      latitude_deg REAL NOT NULL,
      longitude_deg REAL NOT NULL,
      timezone TEXT,
      country_code TEXT,
      FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
    )
  ''',
  '''
    CREATE TABLE IF NOT EXISTS scenarios (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      site_id TEXT,
      name TEXT NOT NULL,
      description TEXT,
      config_json TEXT NOT NULL,
      engine_version TEXT NOT NULL,
      input_hash TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
      FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE SET NULL
    )
  ''',
  '''
    CREATE TABLE IF NOT EXISTS simulation_runs (
      id TEXT PRIMARY KEY,
      scenario_id TEXT NOT NULL,
      started_at INTEGER NOT NULL,
      finished_at INTEGER NOT NULL,
      input_hash TEXT NOT NULL,
      engine_version TEXT NOT NULL,
      summary_json TEXT NOT NULL,
      duration_ms INTEGER NOT NULL,
      FOREIGN KEY (scenario_id) REFERENCES scenarios(id) ON DELETE CASCADE
    )
  ''',
  '''
    CREATE TABLE IF NOT EXISTS app_meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''',
  '''
    CREATE TABLE IF NOT EXISTS component_catalog (
      id TEXT PRIMARY KEY,
      kind TEXT NOT NULL CHECK (kind IN ('module','inverter','battery')),
      payload_json TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      origin TEXT NOT NULL DEFAULT 'user'
    )
  ''',
  'CREATE INDEX IF NOT EXISTS scenarios_project_idx ON scenarios(project_id)',
  'CREATE INDEX IF NOT EXISTS sites_project_idx ON sites(project_id)',
  'CREATE INDEX IF NOT EXISTS runs_scenario_idx ON simulation_runs(scenario_id)',
  'CREATE INDEX IF NOT EXISTS component_catalog_kind_idx ON component_catalog(kind)',
];

/// SQL statements executed when migrating a v1 store up to v2 (introduces
/// the `component_catalog` table). Kept separate from [createStatements]
/// so the migration ladder is the single execution point on existing
/// databases — `_ensureSchema` would re-issue every `IF NOT EXISTS`
/// statement otherwise.
const List<String> migrationV1ToV2 = [
  '''
    CREATE TABLE IF NOT EXISTS component_catalog (
      id TEXT PRIMARY KEY,
      kind TEXT NOT NULL CHECK (kind IN ('module','inverter','battery')),
      payload_json TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      origin TEXT NOT NULL DEFAULT 'user'
    )
  ''',
  'CREATE INDEX IF NOT EXISTS component_catalog_kind_idx ON component_catalog(kind)',
];
