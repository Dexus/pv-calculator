import 'dart:async';
import 'dart:io' show Directory, File, Platform;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart' as native;

import 'schema.dart';

/// Storage tier actually backing [AppDatabase]. Surfaced through
/// [AppDatabase.storageTier] for log inspection — useful when triaging
/// "my project disappeared" reports from web users.
enum DbStorageTier {
  /// Native sqlite3 backed by a file in the platform's app-documents dir.
  native,

  /// In-memory only. Used by tests and as the last-resort fallback on web
  /// when neither the wasm bundle nor a persistent backend is available.
  memory,

  /// Web: sqlite3 wasm with OPFS or IndexedDB persistence (the choice is
  /// made by the sqlite3 web runtime). The Phase-7 web bundle is opt-in
  /// — `web/` does not yet ship sqlite3.wasm, so until that asset lands
  /// the web build falls back to [memory] and logs a warning.
  web,
}

/// Thin synchronous wrapper around [CommonDatabase]. Owns connection
/// lifecycle and exposes the raw db handle to repositories. Repositories
/// stay free of platform branching — only this file knows about file
/// paths and web vs. native.
///
/// Construction is async because the native backend needs a platform
/// documents path. Tests can side-step that with [AppDatabase.memory].
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
  /// Native: a file under [getApplicationDocumentsDirectory] named
  /// `pv_calculator.sqlite`.
  ///
  /// Web: until the wasm bundle is shipped under `web/`, this falls back
  /// to an in-memory db with a `severe`-level log. The fallback keeps the
  /// app launchable; project data won't survive a reload until the asset
  /// is bundled and `WasmSqlite3.loadFromUrl` replaces this branch.
  static Future<AppDatabase> open({String fileName = 'pv_calculator.sqlite'}) async {
    if (kIsWeb) {
      debugPrint('AppDatabase: web build — sqlite3.wasm bundle not yet '
          'shipped; falling back to in-memory db. Project data will not '
          'persist across reloads until the wasm asset is added.');
      return AppDatabase._(native.sqlite3.openInMemory(), DbStorageTier.memory);
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(docs.path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final path = p.join(docs.path, fileName);
    final exists = File(path).existsSync();
    final database = native.sqlite3.open(path);
    if (!exists) {
      debugPrint('AppDatabase: created new sqlite file at $path '
          '(platform=${Platform.operatingSystem})');
    }
    return AppDatabase._(database, DbStorageTier.native);
  }

  /// In-memory database used by widget/unit tests and by the web fallback.
  factory AppDatabase.memory() {
    return AppDatabase._(native.sqlite3.openInMemory(), DbStorageTier.memory);
  }

  void close() => _db.dispose();

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
