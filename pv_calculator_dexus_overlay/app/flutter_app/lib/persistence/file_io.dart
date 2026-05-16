import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:pv_engine/pv_engine.dart';

class ImportedProject {
  const ImportedProject({required this.suggestedName, required this.config});
  final String suggestedName;
  final SimulationConfig config;
}

class ImportedPvgis {
  const ImportedPvgis({required this.sourceLabel, required this.data});

  /// Source filename without `.json`, surfaced by the UI as the
  /// import's origin label.
  final String sourceLabel;
  final PvgisHourlyData data;
}

/// Cross-platform file I/O backed by `file_selector`.
///
/// On web, [getSaveLocation] returns a [FileSaveLocation] whose `path` is the
/// suggested name and [XFile.saveTo] triggers a browser download. On native
/// platforms it shows a native save dialog.
class FileIo {
  const FileIo();

  /// Cap on imported project file size. Hand-edited projects are well under
  /// 5 KB; the limit guards against memory exhaustion via crafted uploads.
  static const int maxImportBytes = 1024 * 1024;

  /// Cap on imported PVGIS file size. A 10-year hourly `seriescalc`
  /// document is on the order of 5–10 MB; 25 MB leaves headroom while
  /// still blocking obvious junk uploads.
  static const int maxPvgisImportBytes = 25 * 1024 * 1024;

  Future<bool> exportConfig(String suggestedName, SimulationConfig config) =>
      _saveString(suggestedName: suggestedName, content: jsonEncode(config.toJson()), mimeType: 'application/json');

  Future<bool> exportCsv({required String filename, required String content}) =>
      _saveString(suggestedName: filename, content: content, mimeType: 'text/csv');

  /// Reads, validates and returns an [ImportedProject]. Throws [ArgumentError]
  /// on oversize input, non-object JSON, or any [SimulationConfig.validate]
  /// failure — callers should surface the error to the user.
  Future<ImportedProject?> importConfig() async {
    const typeGroup = XTypeGroup(label: 'JSON', extensions: <String>['json']);
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null) return null;
    final raw = await file.readAsString();
    if (raw.length > maxImportBytes) {
      throw ArgumentError('Project file is too large (${raw.length} bytes, max $maxImportBytes).');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw ArgumentError('Project JSON must be a top-level object.');
    }
    final config = SimulationConfig.fromJson(decoded.cast<String, dynamic>());
    // Validate before returning so invalid imports never reach persistence.
    config.validate();
    final name = file.name.replaceAll(RegExp(r'\.json$', caseSensitive: false), '');
    return ImportedProject(suggestedName: name.isEmpty ? 'Importiertes Projekt' : name, config: config);
  }

  /// Opens a file picker for a PVGIS `seriescalc` JSON file and
  /// parses it. Returns `null` if the user cancels. Throws
  /// [ArgumentError] on oversize input and rethrows the underlying
  /// [FormatException] when the JSON shape doesn't match PVGIS.
  Future<ImportedPvgis?> importPvgisJson() async {
    const typeGroup = XTypeGroup(label: 'PVGIS JSON', extensions: <String>['json']);
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null) return null;
    final raw = await file.readAsString();
    if (raw.length > maxPvgisImportBytes) {
      throw ArgumentError('PVGIS file is too large (${raw.length} bytes, max $maxPvgisImportBytes).');
    }
    final data = parsePvgisHourlyJson(raw);
    final label = file.name.replaceAll(RegExp(r'\.json$', caseSensitive: false), '');
    return ImportedPvgis(sourceLabel: label.isEmpty ? 'PVGIS-Import' : label, data: data);
  }

  Future<bool> _saveString({required String suggestedName, required String content, required String mimeType}) async {
    final location = await getSaveLocation(suggestedName: suggestedName);
    if (location == null) return false;
    final bytes = Uint8List.fromList(utf8.encode(content));
    final xfile = XFile.fromData(bytes, mimeType: mimeType, name: suggestedName);
    await xfile.saveTo(location.path);
    return true;
  }
}
