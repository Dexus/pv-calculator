import 'dart:convert';

import 'package:component_catalog/component_catalog.dart';

import '../persistence/database.dart';

/// Writable [CatalogSource] backed by the `component_catalog` table in
/// the Phase-7 sqlite store. Rows persist the entry as JSON in
/// `payload_json`; serialisation goes through
/// `CatalogEntry.toJson`/`fromJson` so **new fields** on existing
/// kinds need no schema work. Adding a new [ComponentKind] still
/// requires a migration to widen the `kind` CHECK constraint in
/// `persistence/schema.dart`.
class SqliteUserCatalogSource extends CatalogSource {
  SqliteUserCatalogSource(this._db);

  final AppDatabase _db;

  @override
  bool get isWritable => true;

  @override
  Future<List<CatalogEntry>> fetch() async {
    final rows = _db.db.select(
      'SELECT id, payload_json FROM component_catalog ORDER BY updated_at DESC',
    );
    return [
      for (final row in rows)
        CatalogEntry.fromJson(
            jsonDecode(row['payload_json'] as String) as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> upsert(CatalogEntry entry) async {
    entry.validate();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final payload = jsonEncode(entry.toJson());
    final kind = _kindString(entry.kind);
    _db.db.execute(
      '''
        INSERT INTO component_catalog (id, kind, payload_json, created_at, updated_at, origin)
        VALUES (?, ?, ?, ?, ?, 'user')
        ON CONFLICT(id) DO UPDATE SET
          kind = excluded.kind,
          payload_json = excluded.payload_json,
          updated_at = excluded.updated_at
      ''',
      [entry.id, kind, payload, now, now],
    );
  }

  @override
  Future<void> delete(String id) async {
    _db.db.execute('DELETE FROM component_catalog WHERE id = ?', [id]);
  }

  static String _kindString(ComponentKind k) => switch (k) {
        ComponentKind.module => 'module',
        ComponentKind.inverter => 'inverter',
        ComponentKind.battery => 'battery',
        ComponentKind.chargeController => 'chargeController',
      };
}
