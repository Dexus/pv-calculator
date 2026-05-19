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
const int currentSchemaVersion = 4;

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
      kind TEXT NOT NULL CHECK (kind IN ('module','inverter','battery','chargeController')),
      payload_json TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      origin TEXT NOT NULL DEFAULT 'user'
    )
  ''',
  '''
    CREATE TABLE IF NOT EXISTS irradiance_cache (
      lookup_key TEXT PRIMARY KEY,
      latitude_deg REAL NOT NULL,
      longitude_deg REAL NOT NULL,
      year INTEGER NOT NULL,
      rad_database TEXT,
      payload_json TEXT NOT NULL,
      fetched_at INTEGER NOT NULL,
      source TEXT NOT NULL DEFAULT 'pvgis'
    )
  ''',
  'CREATE INDEX IF NOT EXISTS scenarios_project_idx ON scenarios(project_id)',
  'CREATE INDEX IF NOT EXISTS sites_project_idx ON sites(project_id)',
  'CREATE INDEX IF NOT EXISTS runs_scenario_idx ON simulation_runs(scenario_id)',
  'CREATE INDEX IF NOT EXISTS component_catalog_kind_idx ON component_catalog(kind)',
  'CREATE INDEX IF NOT EXISTS irradiance_cache_year_idx ON irradiance_cache(year)',
];

/// SQL statements executed when migrating a v1 store up to v2 (introduces
/// the `component_catalog` table). [createStatements] also contains
/// these (with `IF NOT EXISTS`) so fresh installs work; running the
/// migration on an already-bootstrapped v1 store is a no-op DDL-wise
/// and exists so the upgrade ladder is auditable and a future
/// migration that needs data-shaping has a place to live.
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

/// v3 adds the global `irradiance_cache` table. Stores one PVGIS
/// horizontal-series payload per (rounded lat/lon, year, raddatabase)
/// so multiple projects at the same location reuse the same fetch and
/// reopening a project restores its irradiance without a network call.
const List<String> migrationV2ToV3 = [
  '''
    CREATE TABLE IF NOT EXISTS irradiance_cache (
      lookup_key TEXT PRIMARY KEY,
      latitude_deg REAL NOT NULL,
      longitude_deg REAL NOT NULL,
      year INTEGER NOT NULL,
      rad_database TEXT,
      payload_json TEXT NOT NULL,
      fetched_at INTEGER NOT NULL,
      source TEXT NOT NULL DEFAULT 'pvgis'
    )
  ''',
  'CREATE INDEX IF NOT EXISTS irradiance_cache_year_idx ON irradiance_cache(year)',
];

/// SQL statements executed when migrating v3 → v4. SQLite does not
/// support `ALTER TABLE … MODIFY CHECK` — relax the `kind` CHECK
/// constraint via the documented rebuild-and-rename recipe. The
/// migration runs inside a transaction in [AppDatabase._migrateV3ToV4],
/// so a half-renamed table cannot leak out of a failed run. Existing
/// rows transfer verbatim (the new CHECK is a strict superset of the
/// old one).
const List<String> migrationV3ToV4 = [
  '''
    CREATE TABLE component_catalog__new (
      id TEXT PRIMARY KEY,
      kind TEXT NOT NULL CHECK (kind IN ('module','inverter','battery','chargeController')),
      payload_json TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      origin TEXT NOT NULL DEFAULT 'user'
    )
  ''',
  'INSERT INTO component_catalog__new SELECT * FROM component_catalog',
  'DROP TABLE component_catalog',
  'ALTER TABLE component_catalog__new RENAME TO component_catalog',
  'CREATE INDEX IF NOT EXISTS component_catalog_kind_idx ON component_catalog(kind)',
];
