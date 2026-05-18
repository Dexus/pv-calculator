import 'dart:convert';
import 'dart:typed_data';

import 'package:component_catalog/component_catalog.dart';
import 'package:file_selector/file_selector.dart';

import '../catalog/catalog_repository.dart';

/// Outcome of a user-catalog import: the parsed entries plus a
/// dry-run partition against the current user source so the UI can
/// show "N new, M will be overwritten" before committing.
class CatalogImportPreview {
  const CatalogImportPreview({
    required this.entries,
    required this.newCount,
    required this.overwriteCount,
  });

  final List<CatalogEntry> entries;
  final int newCount;
  final int overwriteCount;

  int get total => entries.length;
}

/// Cross-platform I/O for the user catalog. Mirrors `FileIo` in
/// `file_io.dart` but stays separate so neither file grows two
/// responsibilities.
class CatalogFileIo {
  const CatalogFileIo();

  /// Reuses the project import cap. A thousand catalog entries is well
  /// under 1 MiB; the limit guards against memory exhaustion on
  /// crafted uploads.
  static const int maxImportBytes = 1024 * 1024;

  /// Reads a JSON file via `file_selector`, parses it with the same
  /// `parseSeedCatalog` used for the bundled seed, and partitions the
  /// result against the current user source. Returns null when the
  /// user cancels the picker. Throws [ArgumentError] on oversize input,
  /// invalid JSON shape, or duplicate ids within the file.
  Future<CatalogImportPreview?> previewImport(CatalogRepository repo) async {
    const typeGroup = XTypeGroup(label: 'JSON', extensions: <String>['json']);
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null) return null;
    final size = await file.length();
    if (size > maxImportBytes) {
      throw ArgumentError(
          'Catalog file is too large ($size bytes, max $maxImportBytes).');
    }
    final raw = await file.readAsString();
    final entries = parseSeedCatalog(raw);
    // Reject in-file dupes up front: otherwise upsert would silently
    // drop one of the entries and the preview/commit counts would
    // disagree with the resulting catalog state.
    assertNoDuplicateImportIds(entries);
    final conflicts = await repo.previewImportConflicts(entries);
    return CatalogImportPreview(
      entries: entries,
      newCount: entries.length - conflicts.length,
      overwriteCount: conflicts.length,
    );
  }

  /// Writes the user-only entries to a JSON file via `file_selector`.
  /// Returns the actual filename written (derived from `location.path`,
  /// which reflects any rename the user did in the native save dialog),
  /// or null when the picker is cancelled.
  Future<String?> exportUserCatalog(
    CatalogRepository repo, {
    String suggestedName = 'components_user.json',
  }) async {
    final content = await repo.exportUserCatalogJson();
    final location = await getSaveLocation(suggestedName: suggestedName);
    if (location == null) return null;
    // On web `location.path` is the suggested name (browser-driven download);
    // on native it's a full filesystem path. Splitting on either separator
    // yields the user-visible filename in both cases without pulling in a
    // path-manipulation dep just for the basename.
    final savedName = location.path.split(RegExp(r'[\\/]')).last;
    final bytes = Uint8List.fromList(utf8.encode(content));
    final xfile = XFile.fromData(
      bytes,
      mimeType: 'application/json',
      name: savedName,
    );
    await xfile.saveTo(location.path);
    return savedName;
  }
}

/// Throws [ArgumentError] when [entries] contains any duplicate ids.
/// Hand-edited import files may contain typos that would otherwise
/// silently drop entries (the second occurrence overwrites the first
/// during upsert, and the preview/commit counts disagree with what
/// actually lands in the catalog).
void assertNoDuplicateImportIds(List<CatalogEntry> entries) {
  final seen = <String>{};
  final dupes = <String>{};
  for (final e in entries) {
    if (!seen.add(e.id)) dupes.add(e.id);
  }
  if (dupes.isNotEmpty) {
    throw ArgumentError(
        'Import file contains duplicate ids: ${dupes.join(', ')}');
  }
}
