import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:pv_engine/pv_engine.dart';

class ImportedProject {
  const ImportedProject({required this.suggestedName, required this.config});
  final String suggestedName;
  final SimulationConfig config;
}

/// Cross-platform file I/O backed by `file_selector`.
///
/// On web, [getSaveLocation] returns a [FileSaveLocation] whose `path` is the
/// suggested name and [XFile.saveTo] triggers a browser download. On native
/// platforms it shows a native save dialog.
class FileIo {
  const FileIo();

  Future<bool> exportConfig(String suggestedName, SimulationConfig config) =>
      _saveString(suggestedName: suggestedName, content: jsonEncode(config.toJson()), mimeType: 'application/json');

  Future<bool> exportCsv({required String filename, required String content}) =>
      _saveString(suggestedName: filename, content: content, mimeType: 'text/csv');

  Future<ImportedProject?> importConfig() async {
    const typeGroup = XTypeGroup(label: 'JSON', extensions: <String>['json']);
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null) return null;
    final raw = await file.readAsString();
    final config = SimulationConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    final name = file.name.replaceAll(RegExp(r'\.json$', caseSensitive: false), '');
    return ImportedProject(suggestedName: name.isEmpty ? 'Importiertes Projekt' : name, config: config);
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
