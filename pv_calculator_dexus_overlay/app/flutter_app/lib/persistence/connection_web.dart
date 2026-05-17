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
/// Persistent storage (OPFS / IndexedDB) requires a Dart worker setup that
/// is tracked under `docs/ROADMAP.md` §Phase 7 Verschoben. Until that lands,
/// every web session starts with an empty in-memory database — fine for the
/// "try it out" Pages preview, not for real project work.

WasmSqlite3? _cachedWasm;

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
  return wasm.openInMemory();
}

Future<({CommonDatabase db, String path, bool created})> openFile(String fileName) async {
  final wasm = await _loadWasm();
  // Until OPFS/IndexedDB persistence is wired up, every web "file" db is
  // really an in-memory db. The path string is purely informational for
  // debugPrint output; nothing reads it back.
  return (db: wasm.openInMemory(), path: '<web in-memory>', created: true);
}
