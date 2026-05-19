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

  /// Web sqlite3 backed by `package:sqlite3`'s `IndexedDbFileSystem`. The
  /// sqlite file lives in an IndexedDB store on the current origin; data
  /// survives reloads but may be evicted under browser storage pressure.
  indexedDb,

  /// In-memory only. Used by the VM-side test suite via
  /// [AppDatabase.memory]; never selected by [AppDatabase.open] in
  /// production.
  memory,
}

/// Thin wrapper around [CommonDatabase]. Owns connection lifecycle and
/// exposes the raw db handle to repositories. Platform branching lives in
/// the conditional imports of `connection_io.dart` / `connection_web.dart`
/// — this file is platform-neutral and safe to import from both targets.
class AppDatabase {
  AppDatabase._(this._db, this.storageTier, this._flushImpl) {
    _db.execute('PRAGMA foreign_keys = ON');
    _ensureSchema();
  }

  final CommonDatabase _db;
  final DbStorageTier storageTier;
  final Future<void> Function() _flushImpl;

  CommonDatabase get db => _db;

  /// Opens (or creates) the production database on the current platform.
  ///
  /// - Native: a file under the platform's app-documents directory.
  /// - Web: loads `sqlite3.wasm` from the same origin (`web/sqlite3.wasm`)
  ///   and stores sqlite files inside a single IDB store, with [fileName]
  ///   as the path within the `IndexedDbFileSystem` VFS. OPFS (which
  ///   removes the async-flush window) is still deferred — see ROADMAP
  ///   §Phase 7 Verschoben.
  static Future<AppDatabase> open({String fileName = 'pv_calculator.sqlite'}) async {
    final result = await conn.openFile(fileName);
    if (result.created) {
      debugPrint('AppDatabase: created new sqlite store at ${result.path}.');
    }
    final tier = kIsWeb ? DbStorageTier.indexedDb : DbStorageTier.native;
    return AppDatabase._(result.db, tier, result.flush);
  }

  /// In-memory database used by the VM-side test suite. The web shim's
  /// synchronous entry point throws — call [open] instead from web code.
  factory AppDatabase.memory() {
    return AppDatabase._(conn.openInMemorySync(), DbStorageTier.memory, () async {});
  }

  /// Wraps an already-open [CommonDatabase] and runs `_ensureSchema`
  /// against it (including the [_upgrade] ladder). Lets tests hand in
  /// a database pre-seeded with an older schema version to exercise a
  /// real production-upgrade pass instead of running the migration
  /// SQL out of band. Caller owns the underlying handle's lifetime.
  @visibleForTesting
  factory AppDatabase.wrapForTesting(CommonDatabase db) {
    return AppDatabase._(db, DbStorageTier.memory, () async {});
  }

  /// Awaits any pending writes from the underlying VFS to durable storage.
  ///
  /// - Native / in-memory: completes immediately (no buffering layer).
  /// - Web: awaits the `IndexedDbFileSystem`'s pending IDB transactions so
  ///   the most recent save survives an immediate reload. A
  ///   `visibilitychange` listener registered by `connection_web.dart`
  ///   already calls this best-effort when the tab goes hidden; explicit
  ///   callers (tests, "Save & quit" buttons) can await it for hard
  ///   durability.
  Future<void> flush() => _flushImpl();

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
      if (v == 1) {
        _migrateV1ToV2();
        v = 2;
        continue;
      }
      if (v == 2) {
        _migrateV2ToV3();
        v = 3;
        continue;
      }
      if (v == 3) {
        _migrateV3ToV4();
        v = 4;
        continue;
      }
      if (v == 4) {
        _migrateV4ToV5();
        v = 5;
        continue;
      }
      throw StateError('No migration path from schema v$v to v${v + 1}.');
    }
  }

  void _migrateV1ToV2() {
    for (final stmt in migrationV1ToV2) {
      _db.execute(stmt);
    }
  }

  void _migrateV2ToV3() {
    for (final stmt in migrationV2ToV3) {
      _db.execute(stmt);
    }
  }

  /// Relax the `component_catalog.kind` CHECK to include
  /// `'chargeController'`. Done as a single transaction so the rebuild-
  /// and-rename either lands fully or not at all — a half-renamed table
  /// would leave the database in an unbootable state.
  void _migrateV3ToV4() {
    _db.execute('BEGIN');
    try {
      for (final stmt in migrationV3ToV4) {
        _db.execute(stmt);
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Engine 0.17.0 adds `SimulationSummary.perYearMonthly` nested inside
  /// `simulation_runs.summary_json` (opaque TEXT). No DDL is needed —
  /// the bump fences forward compatibility so an older v4 build refuses
  /// to open a v5 store instead of silently dropping the new field.
  void _migrateV4ToV5() {
    for (final stmt in migrationV4ToV5) {
      _db.execute(stmt);
    }
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
