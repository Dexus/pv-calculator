import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/persistence/database.dart';
import 'package:pv_calculator_app/persistence/schema.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('fresh schema provisioning + v1 → v2 migration', () {
    test('current build provisions the latest schema with component_catalog table',
        () {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      final ver = db.db
          .select("SELECT value FROM app_meta WHERE key = 'schema_version'")
          .single['value'];
      expect(ver, currentSchemaVersion.toString());

      final tables = db.db
          .select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='component_catalog'")
          .map((r) => r['name'])
          .toList();
      expect(tables, ['component_catalog']);
    });

    test(
        'migrationV1ToV2 statements bring a hand-crafted v1 store up to v2 shape',
        () {
      // Build a v1-shaped sqlite by hand: no component_catalog table,
      // app_meta.schema_version = '1'.
      final raw = sqlite3.openInMemory();
      addTearDown(raw.close);
      raw.execute('PRAGMA foreign_keys = ON');
      raw.execute('''
        CREATE TABLE app_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)
      ''');
      raw.execute("INSERT INTO app_meta(key, value) VALUES ('schema_version', '1')");

      // Apply the migration statements exposed by schema.dart.
      for (final stmt in migrationV1ToV2) {
        raw.execute(stmt);
      }
      raw.execute(
          "UPDATE app_meta SET value = '2' WHERE key = 'schema_version'");

      // The new table now exists and accepts a roundtrip.
      raw.execute(
        "INSERT INTO component_catalog (id, kind, payload_json, created_at, updated_at, origin) "
        "VALUES ('m1', 'module', '{}', 0, 0, 'user')",
      );
      final rows = raw.select('SELECT id, kind FROM component_catalog');
      expect(rows.single['id'], 'm1');
      expect(rows.single['kind'], 'module');

      // Schema version was bumped to v2 by this isolated step (the
      // ladder up to the current head is exercised below).
      final ver = raw
          .select("SELECT value FROM app_meta WHERE key = 'schema_version'")
          .single['value'];
      expect(ver, '2');
    });

    test('AppDatabase._upgrade runs against a real v1-pinned database', () {
      // Pre-seed a CommonDatabase with v1 schema_version, then wrap
      // it in AppDatabase so _ensureSchema → _upgrade runs the real
      // production code path (not the migration SQL out-of-band).
      final raw = sqlite3.openInMemory();
      addTearDown(raw.close);
      raw.execute(
          'CREATE TABLE app_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      raw.execute(
          "INSERT INTO app_meta(key, value) VALUES ('schema_version', '1')");

      // Wrap — constructor runs _ensureSchema which sees v1 and calls
      // the real _upgrade ladder. Component_catalog table also gets
      // created by createStatements (IF NOT EXISTS makes both paths
      // safe), and the version row is bumped to the latest version.
      final db = AppDatabase.wrapForTesting(raw);
      addTearDown(db.close);

      final ver = raw
          .select("SELECT value FROM app_meta WHERE key = 'schema_version'")
          .single['value'];
      expect(ver, currentSchemaVersion.toString());
      final tables = raw
          .select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='component_catalog'")
          .map((r) => r['name'])
          .toList();
      expect(tables, ['component_catalog']);
    });
  });

  group('schema v2 → v3 migration', () {
    test('migrationV2ToV3 creates the irradiance_cache table', () {
      final raw = sqlite3.openInMemory();
      addTearDown(raw.close);
      raw.execute('PRAGMA foreign_keys = ON');
      raw.execute(
          'CREATE TABLE app_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      raw.execute(
          "INSERT INTO app_meta(key, value) VALUES ('schema_version', '2')");

      for (final stmt in migrationV2ToV3) {
        raw.execute(stmt);
      }
      raw.execute(
          "UPDATE app_meta SET value = '3' WHERE key = 'schema_version'");

      raw.execute(
        "INSERT INTO irradiance_cache (lookup_key, latitude_deg, longitude_deg, "
        "year, rad_database, payload_json, fetched_at, source) "
        "VALUES ('50.0|10.0|2022|', 50.0, 10.0, 2022, NULL, '{}', 0, 'pvgis')",
      );
      final rows = raw.select('SELECT lookup_key FROM irradiance_cache');
      expect(rows.single['lookup_key'], '50.0|10.0|2022|');
    });
  });

  group('schema v3 → v4 migration', () {
    test('migrationV3ToV4 relaxes the CHECK to accept chargeController rows',
        () {
      // Build a v3-shaped database by hand (post-irradiance-cache,
      // pre-CHECK-relax): insert one of each pre-v4 kind, then apply
      // the migration and verify a chargeController row now passes
      // the CHECK.
      final raw = sqlite3.openInMemory();
      addTearDown(raw.close);
      raw.execute(
          'CREATE TABLE app_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      raw.execute(
          "INSERT INTO app_meta(key, value) VALUES ('schema_version', '3')");
      raw.execute('''
        CREATE TABLE component_catalog (
          id TEXT PRIMARY KEY,
          kind TEXT NOT NULL CHECK (kind IN ('module','inverter','battery')),
          payload_json TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          origin TEXT NOT NULL DEFAULT 'user'
        )
      ''');
      raw.execute(
        "INSERT INTO component_catalog(id, kind, payload_json, created_at, updated_at, origin) "
        "VALUES ('m1', 'module', '{}', 0, 0, 'user')",
      );

      raw.execute('BEGIN');
      for (final stmt in migrationV3ToV4) {
        raw.execute(stmt);
      }
      raw.execute('COMMIT');
      raw.execute("UPDATE app_meta SET value = '4' WHERE key = 'schema_version'");

      // Pre-existing row survived.
      expect(
        raw.select('SELECT id FROM component_catalog').single['id'],
        'm1',
      );

      // New kind is accepted now.
      raw.execute(
        "INSERT INTO component_catalog(id, kind, payload_json, created_at, updated_at, origin) "
        "VALUES ('cc1', 'chargeController', '{}', 0, 0, 'user')",
      );
      final kinds = raw
          .select('SELECT kind FROM component_catalog ORDER BY id')
          .map((r) => r['kind'])
          .toList();
      // ORDER BY id: 'cc1' < 'm1', so chargeController comes first.
      expect(kinds, ['chargeController', 'module']);
    });

    test('AppDatabase._upgrade walks v1 all the way to the current head', () {
      // v1 store: every intermediate migration has its own block. The
      // ladder run from v1 must end at currentSchemaVersion with both
      // the irradiance_cache table (v2→v3) and the relaxed CHECK
      // (v3→v4) in place.
      final raw = sqlite3.openInMemory();
      addTearDown(raw.close);
      raw.execute(
          'CREATE TABLE app_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      raw.execute(
          "INSERT INTO app_meta(key, value) VALUES ('schema_version', '1')");

      final db = AppDatabase.wrapForTesting(raw);
      addTearDown(db.close);

      expect(currentSchemaVersion, 4);
      final ver = raw
          .select("SELECT value FROM app_meta WHERE key = 'schema_version'")
          .single['value'];
      expect(ver, currentSchemaVersion.toString());

      // irradiance_cache table exists (v2→v3 step).
      final tables = raw
          .select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='irradiance_cache'")
          .map((r) => r['name'])
          .toList();
      expect(tables, ['irradiance_cache']);

      // chargeController insertion succeeds against the post-migration
      // CHECK (v3→v4 step).
      raw.execute(
        "INSERT INTO component_catalog(id, kind, payload_json, created_at, updated_at, origin) "
        "VALUES ('cc1', 'chargeController', '{}', 0, 0, 'user')",
      );
      expect(
        raw
            .select(
                "SELECT id FROM component_catalog WHERE kind = 'chargeController'")
            .single['id'],
        'cc1',
      );
    });
  });
}
