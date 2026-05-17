import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/common.dart';

import 'connection_io.dart' if (dart.library.js_interop) 'connection_web.dart' as conn;
import 'schema.dart';

/// Storage tier actually backing [AppDatabase]. Surfaced through
/// [AppDatabase.storageTier] for log inspection — useful when triaging
/// "my project disappeared" reports from web users.
enum DbStorageTier {
  /// Native sqlite3 backed by a file in the platform's app-documents dir.
  native,

  /// In-memory only. Used by tests and as the current web fallback (until
  /// the OPFS/IndexedDB worker setup tracked in
  /// `docs/ROADMAP.md` §Phase 7 Verschoben lands).
  memory,
}

/// Thin wrapper around [CommonDatabase]. Owns connection lifecycle and
/// exposes the raw db handle to repositories. Platform branching lives in
/// the conditional imports of `connection_io.dart` / `connection_web.dart`
/// — this file is platform-neutral and safe to import from both targets.
class AppDatabase {
  AppDatabase._(this._db, this.storageTier) {
    _db.execute('PRAGMA foreign_keys = ON');
    _ensureSchema();
  }

  final CommonDatabase _db;
  final DbStorageTier storageTier;

  CommonDatabase get db => _db;

  /// Opens (or creates) the production database on the current platform.
  ///
  /// - Native: a file under the platform's app-documents directory.
  /// - Web: loads `sqlite3.wasm` from the same origin (`web/sqlite3.wasm`)
  ///   and runs an in-memory db on top. Persistent OPFS/IndexedDB storage
  ///   on web is deferred (see ROADMAP §Phase 7 Verschoben).
  static Future<AppDatabase> open({String fileName = 'pv_calculator.sqlite'}) async {
    if (kIsWeb) {
      final db = await conn.openInMemoryAsync();
      debugPrint('AppDatabase: web build using sqlite3.wasm in-memory. '
          'Persistent storage (OPFS/IndexedDB) is tracked under '
          'ROADMAP §Phase 7 Verschoben.');
      return AppDatabase._(db, DbStorageTier.memory);
    }
    final result = await conn.openFile(fileName);
    if (result.created) {
      debugPrint('AppDatabase: created new sqlite file at ${result.path}.');
    }
    return AppDatabase._(result.db, DbStorageTier.native);
  }

  /// In-memory database used by the VM-side test suite. The web shim's
  /// synchronous entry point throws — call [open] instead from web code.
  factory AppDatabase.memory() {
    return AppDatabase._(conn.openInMemorySync(), DbStorageTier.memory);
  }

  void close() => _db.close();

  void _ensureSchema() {
    for (final stmt in createStatements) {
      _db.execute(stmt);
    }
    final existing = _db
        .select("SELECT value FROM app_meta WHERE key = 'schema_version'")
        .map((row) => int.tryParse(row['value'] as String? ?? '') ?? 0)
        .firstOrNull;
    if (existing == null) {
      _db.execute(
        "INSERT INTO app_meta(key, value) VALUES ('schema_version', ?)",
        [currentSchemaVersion.toString()],
      );
      return;
    }
    if (existing > currentSchemaVersion) {
      throw StateError(
        'On-disk schema version $existing is newer than this build '
        '($currentSchemaVersion). Refusing to downgrade.',
      );
    }
    if (existing < currentSchemaVersion) {
      _upgrade(from: existing, to: currentSchemaVersion);
      _db.execute(
        "UPDATE app_meta SET value = ? WHERE key = 'schema_version'",
        [currentSchemaVersion.toString()],
      );
    }
  }

  /// Schema migration ladder. v1 is the initial schema. Future versions
  /// add their own `_migrateVNToVN1()` calls here; bumping
  /// [currentSchemaVersion] without filling in a step throws.
  void _upgrade({required int from, required int to}) {
    var v = from;
    while (v < to) {
      // No migrations defined yet — the only valid case is from == to,
      // which the caller already short-circuited.
      throw StateError('No migration path from schema v$v to v${v + 1}.');
    }
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
