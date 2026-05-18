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
  /// user cancels the picker. Throws [ArgumentError] on oversize input
  /// or invalid JSON shape.
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
    final conflicts = await repo.previewImportConflicts(entries);
    return CatalogImportPreview(
      entries: entries,
      newCount: entries.length - conflicts.length,
      overwriteCount: conflicts.length,
    );
  }

  /// Writes the user-only entries to a JSON file via `file_selector`.
  /// Returns the picked filename on success, null when cancelled.
  Future<String?> exportUserCatalog(
    CatalogRepository repo, {
    String suggestedName = 'components_user.json',
  }) async {
    final content = await repo.exportUserCatalogJson();
    final location = await getSaveLocation(suggestedName: suggestedName);
    if (location == null) return null;
    final bytes = Uint8List.fromList(utf8.encode(content));
    final xfile = XFile.fromData(
      bytes,
      mimeType: 'application/json',
      name: suggestedName,
    );
    await xfile.saveTo(location.path);
    return suggestedName;
  }
}
