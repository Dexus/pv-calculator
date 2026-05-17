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
/// Persistence runs on top of `IndexedDbFileSystem`: the sqlite file lives
/// in an IndexedDB store named after [openFile]'s `fileName` argument, and
/// project data survives reloads on the same origin. OPFS (which would
/// remove the async-flush window between sqlite writes and IDB commits)
/// still needs a worker bootstrap and stays deferred — see
/// `docs/ROADMAP.md` §Phase 7 Verschoben.

WasmSqlite3? _cachedWasm;
IndexedDbFileSystem? _cachedFs;
String? _cachedFsName;

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
  // Kept for parity with the native shim. The web app always goes through
  // [openFile] for persistence; this entry point is unused in production.
  final wasm = await _loadWasm();
  wasm.registerVirtualFileSystem(InMemoryFileSystem(), makeDefault: true);
  return wasm.openInMemory();
}

Future<({CommonDatabase db, String path, bool created})> openFile(String fileName) async {
  final wasm = await _loadWasm();
  // The wasm sqlite3 build has no built-in VFS — registering the IDB-backed
  // one as default routes every subsequent `wasm.open(...)` through it.
  // Reuse one VFS per session: re-registering the same name throws inside
  // sqlite3, and `IndexedDbFileSystem.open` would otherwise reopen the IDB
  // database every hot restart.
  if (_cachedFs == null || _cachedFsName != fileName) {
    _cachedFs = await IndexedDbFileSystem.open(dbName: fileName);
    wasm.registerVirtualFileSystem(_cachedFs!, makeDefault: true);
    _cachedFsName = fileName;
  }
  // `xAccess(path, SQLITE_ACCESS_EXISTS=0)` returns 1 when the IDB-backed
  // VFS already has the file cached in memory after `open()` — i.e. it
  // existed before this session.
  final created = _cachedFs!.xAccess(fileName, 0) == 0;
  return (db: wasm.open(fileName), path: 'idb:$fileName', created: created);
}
