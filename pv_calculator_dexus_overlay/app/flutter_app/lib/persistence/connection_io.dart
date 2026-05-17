import 'dart:io' show Directory, File;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart' as native;

/// Native (mobile/desktop) sqlite3 connection helpers. Selected at compile
/// time by `database.dart`'s conditional import. Imports `dart:ffi`
/// transitively via `package:sqlite3/sqlite3.dart`, so it must not be
/// referenced from web builds.

CommonDatabase openInMemorySync() => native.sqlite3.openInMemory();

Future<CommonDatabase> openInMemoryAsync() async => native.sqlite3.openInMemory();

Future<
  ({
    CommonDatabase db,
    String path,
    bool created,
    Future<void> Function() flush,
  })
>
openFile(String fileName) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(docs.path);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final path = p.join(docs.path, fileName);
  final created = !File(path).existsSync();
  return (
    db: native.sqlite3.open(path),
    path: path,
    created: created,
    // Native sqlite writes go straight through `dart:ffi` to the OS file
    // descriptor — no async commit window to wait on.
    flush: () async {},
  );
}
