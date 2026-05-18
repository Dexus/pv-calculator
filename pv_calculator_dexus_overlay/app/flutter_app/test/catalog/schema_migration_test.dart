import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/persistence/database.dart';
import 'package:pv_calculator_app/persistence/schema.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('schema v1 → v2 migration', () {
    test('current build provisions a v2 store with component_catalog table',
        () {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      final ver = db.db
          .select("SELECT value FROM app_meta WHERE key = 'schema_version'")
          .single['value'];
      expect(ver, '2');

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

      // Schema version was bumped.
      final ver = raw
          .select("SELECT value FROM app_meta WHERE key = 'schema_version'")
          .single['value'];
      expect(ver, '2');
    });
  });
}
