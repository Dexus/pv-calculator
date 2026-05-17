import 'dart:async';
import 'dart:js_interop';

import 'package:sqlite3/wasm.dart';
import 'package:web/web.dart' as web;

/// Web sqlite3 connection helpers. Selected at compile time by
/// `database.dart`'s conditional import. Uses `package:sqlite3/wasm.dart`,
/// which compiles cleanly without `dart:ffi`.
///
/// The matching `sqlite3.wasm` is bundled under `web/sqlite3.wasm` (see the
/// flutter_app README); `WasmSqlite3.loadFromUrl` fetches it from the same
/// origin at first use, then caches the instance for the rest of the
/// session.
///
/// Persistence runs on top of `IndexedDbFileSystem`: a single IDB store
/// named `pv_calculator` hosts every sqlite file used by the session, so
/// the per-call `fileName` argument is just a path inside the VFS. The VFS
/// registration is global to the wasm runtime — sqlite3 throws on
/// duplicates — so we register exactly once per kind (in-memory vs. IDB)
/// and reuse it for the rest of the session.
///
/// OPFS (which would remove the async-flush window between sqlite writes
/// and IDB commits) still needs a worker bootstrap and stays deferred —
/// see `docs/ROADMAP.md` §Phase 7 Verschoben.

WasmSqlite3? _cachedWasm;
InMemoryFileSystem? _cachedMemoryFs;
IndexedDbFileSystem? _cachedIdbFs;
bool _visibilityListenerRegistered = false;

/// Fixed IDB database name. Keeping this constant — rather than letting it
/// vary per [openFile] call — is what makes the VFS registration idempotent:
/// any subsequent `openFile('something-else.sqlite')` reuses the existing
/// VFS and just maps to a different file path inside it.
const _idbDatabaseName = 'pv_calculator';

Future<WasmSqlite3> _loadWasm() async {
  if (_cachedWasm != null) return _cachedWasm!;
  // Resolve against `<base href>` rather than `window.location.href`: under
  // GitHub Pages the page lives at `/pv-calculator/app-dev/`, but on a deep
  // route or a URL without a trailing slash `Uri.base` would point one
  // directory up and the fetch would 404 into the Pages HTML, which
  // `WebAssembly.instantiateStreaming` then rejects on MIME type.
  final wasmUrl = Uri.parse(web.document.baseURI).resolve('sqlite3.wasm');
  return _cachedWasm = await WasmSqlite3.loadFromUrl(wasmUrl);
}

/// Synchronous in-memory init is not possible on web — loading the wasm
/// module is fundamentally async. The native test suite uses
/// `AppDatabase.memory()` heavily; the web build should always go through
/// `AppDatabase.open()` instead.
CommonDatabase openInMemorySync() {
  throw UnsupportedError(
    'AppDatabase.memory() is not supported on web — use the async '
    'AppDatabase.open() so sqlite3.wasm can load.',
  );
}

Future<CommonDatabase> openInMemoryAsync() async {
  final wasm = await _loadWasm();
  // sqlite3 rejects re-registering a VFS with the same name, so the
  // in-memory VFS is created and registered exactly once per session and
  // reused for every subsequent call.
  if (_cachedMemoryFs == null) {
    _cachedMemoryFs = InMemoryFileSystem();
    wasm.registerVirtualFileSystem(_cachedMemoryFs!, makeDefault: true);
  }
  return wasm.openInMemory();
}

Future<
  ({
    CommonDatabase db,
    String path,
    bool created,
    Future<void> Function() flush,
  })
>
openFile(String fileName) async {
  final wasm = await _loadWasm();
  // One IDB-backed VFS per session. The registration is keyed off the fixed
  // `_idbDatabaseName` rather than the caller's `fileName`, because the
  // sqlite3 VFS registration is process-wide and duplicate names throw;
  // varying it per file would break a second `AppDatabase.open(fileName:)`
  // call. Different `fileName`s become different sqlite files inside the
  // same VFS — `makeDefault: true` routes every `wasm.open(...)` through it.
  if (_cachedIdbFs == null) {
    _cachedIdbFs = await IndexedDbFileSystem.open(dbName: _idbDatabaseName);
    wasm.registerVirtualFileSystem(_cachedIdbFs!, makeDefault: true);
    _registerVisibilityFlush();
  }
  // `xAccess(path, SQLITE_ACCESS_EXISTS=0)` returns 1 when the IDB-backed
  // VFS already has the file cached after `open()` — i.e. it existed before
  // this session.
  final created = _cachedIdbFs!.xAccess(fileName, 0) == 0;
  return (
    db: wasm.open(fileName),
    path: 'idb:$_idbDatabaseName/$fileName',
    created: created,
    flush: () async {
      await _cachedIdbFs?.flush();
    },
  );
}

void _registerVisibilityFlush() {
  if (_visibilityListenerRegistered) return;
  _visibilityListenerRegistered = true;
  // IndexedDbFileSystem buffers sqlite writes and commits them to IDB
  // asynchronously; sqlite's `xSync` is a no-op on this VFS. If the user
  // reloads or closes the tab right after a save, the last writes can
  // still be in flight. Best-effort flush when the document becomes
  // hidden — browsers fire `visibilitychange` on tab switch, navigation
  // away, and (on most platforms) tab close. Callers that care about
  // explicit durability — e.g. tests — can also call `AppDatabase.flush()`.
  web.document.addEventListener(
    'visibilitychange',
    ((web.Event _) {
      if (web.document.visibilityState == 'hidden') {
        unawaited(_cachedIdbFs?.flush() ?? Future<void>.value());
      }
    }).toJS,
  );
}
