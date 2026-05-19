import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart' show BuildContext, RenderBox;
import 'package:pv_engine/pv_engine.dart';

import 'share_helper.dart'
    if (dart.library.io) 'share_helper_io.dart' as share;

class ImportedProject {
  const ImportedProject({required this.suggestedName, required this.config});
  final String suggestedName;
  final SimulationConfig config;
}

/// Cross-platform file I/O. On web `file_selector.getSaveLocation` returns
/// a [FileSaveLocation] whose `path` is the suggested name and
/// [XFile.saveTo] triggers a browser download. On Linux/macOS/Windows it
/// shows the native save dialog. On Android/iOS — where `getSaveLocation`
/// is unsupported — exports are routed through `share_plus` and the OS
/// share sheet instead.
class FileIo {
  const FileIo();

  /// True when running on Android or iOS. Call sites use this to swap
  /// the "Exported"/"Downloaded" SnackBar for the "Shared via system"
  /// variant, since the export was handed off to another app instead of
  /// landing in a file the user picked. On web / desktop this is false
  /// and the desktop/web SnackBar text is correct.
  static bool get isMobile => share.kIsMobilePlatform;

  /// Cap on imported project file size. Hand-edited projects are well under
  /// 5 KB; the limit guards against memory exhaustion via crafted uploads.
  static const int maxImportBytes = 1024 * 1024;

  /// Cap on imported load-profile CSV size. A full-year quarter-hourly
  /// export (35 040 rows × ~40 B per row) overruns the 1 MiB project
  /// cap; raw time-series files need their own headroom.
  static const int maxCsvBytes = 16 * 1024 * 1024;

  /// Wraps [config] in the Phase-7 reproducibility envelope and writes it.
  /// The envelope pins the engine version and the canonical input hash of
  /// the embedded config — pre-Phase-7 readers that look for `arrays` at
  /// the top level are handled by the import fallback below.
  ///
  /// Returns `true` when the file landed somewhere (saved or shared) and
  /// `false` when the user cancelled the save dialog or dismissed the
  /// share sheet. [sharePositionOrigin] anchors the iPad popover; ignored
  /// elsewhere.
  Future<bool> exportConfig(
    String suggestedName,
    SimulationConfig config, {
    Rect? sharePositionOrigin,
  }) =>
      _saveString(
        suggestedName: suggestedName,
        content: jsonEncode(buildExportEnvelope(config)),
        mimeType: 'application/json',
        sharePositionOrigin: sharePositionOrigin,
      );

  Future<bool> exportCsv({
    required String filename,
    required String content,
    Rect? sharePositionOrigin,
  }) =>
      _saveString(
        suggestedName: filename,
        content: content,
        mimeType: 'text/csv',
        sharePositionOrigin: sharePositionOrigin,
      );

  /// Reads, validates and returns an [ImportedProject]. Accepts both the
  /// Phase-7 envelope (`{engineVersion, inputHash, config}`) and the
  /// pre-Phase-7 bare-config form (the entire document is a
  /// `SimulationConfig`). Throws [ArgumentError] on oversize input,
  /// non-object JSON, or any [SimulationConfig.validate] failure.
  Future<ImportedProject?> importConfig() async {
    const typeGroup = XTypeGroup(label: 'JSON', extensions: <String>['json']);
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null) return null;
    await _enforceSizeLimit(file, maxImportBytes, kind: 'Project');
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw ArgumentError('Project JSON must be a top-level object.');
    }
    final map = decoded.cast<String, dynamic>();
    final config = parseImportedConfig(map);
    // Validate before returning so invalid imports never reach persistence.
    config.validate();
    final name = file.name.replaceAll(RegExp(r'\.json$', caseSensitive: false), '');
    return ImportedProject(suggestedName: name.isEmpty ? 'Importiertes Projekt' : name, config: config);
  }

  /// Throws [ArgumentError] if the picked file's byte length exceeds
  /// [maxBytes]. Checking before `readAsString()` keeps a crafted
  /// multi-gigabyte payload from being decoded into memory just so we
  /// can reject it after the fact.
  Future<void> _enforceSizeLimit(XFile file, int maxBytes, {required String kind}) async {
    final size = await file.length();
    if (size > maxBytes) {
      throw ArgumentError('$kind file is too large ($size bytes, max $maxBytes).');
    }
  }

  /// Picks a CSV file and parses it into a [LoadProfile] via the engine's
  /// `parseLoadProfileCsv`. Returns `null` when the user cancels the
  /// picker. Throws [ArgumentError] on oversize input and rethrows
  /// [FormatException] from the parser on malformed CSV.
  Future<LoadProfile?> importLoadProfileCsv() async {
    const typeGroup = XTypeGroup(
      label: 'CSV',
      extensions: <String>['csv', 'txt'],
    );
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null) return null;
    await _enforceSizeLimit(file, maxCsvBytes, kind: 'Load profile');
    final raw = await file.readAsString();
    return parseLoadProfileCsv(raw);
  }

  Future<bool> _saveString({
    required String suggestedName,
    required String content,
    required String mimeType,
    Rect? sharePositionOrigin,
  }) async {
    if (share.kIsMobilePlatform) {
      // Mobile path: encode up front because `share_plus` consumes
      // the bytes synchronously inside `XFile.fromData`.
      final bytes = Uint8List.fromList(utf8.encode(content));
      final outcome = await share.shareBytesViaSheet(
        suggestedName: suggestedName,
        bytes: bytes,
        mimeType: mimeType,
        sharePositionOrigin: sharePositionOrigin,
      );
      // `ShareResultStatus.unavailable` is documented as "platform
      // succeeded to share content but user action cannot be
      // determined" — i.e. the file WAS handed off, we just can't
      // observe the target app. Only `dismissed` is a real cancel
      // (Codex review on PR #43). Treating `unavailable` as
      // cancelled used to wrongly tell users "Export abgebrochen"
      // on platforms that don't report the user-picked target.
      return outcome != share.ShareOutcome.dismissed;
    }
    // Desktop / web path: show the save dialog first so a cancel is
    // cheap. Encoding a multi-MB quarter-hourly CSV before the picker
    // appears would noticeably delay the dialog (Copilot review on
    // PR #43) and do useless work for users who back out.
    final location = await getSaveLocation(suggestedName: suggestedName);
    if (location == null) return false;
    final bytes = Uint8List.fromList(utf8.encode(content));
    final xfile = XFile.fromData(bytes, mimeType: mimeType, name: suggestedName);
    await xfile.saveTo(location.path);
    return true;
  }
}

/// Computes the iPad share-sheet anchor rect from [context]'s closest
/// `RenderBox`. Returns `null` when the context has no attached render
/// object — `share_helper_io.dart` substitutes a top-left 1×1 fallback
/// on iOS so iPad never crashes (`share_plus` requires a non-null
/// origin there, see its README "iPad" section). Android / iPhone /
/// desktop / web ignore the field entirely.
Rect? shareOriginFromContext(BuildContext context) {
  final ro = context.findRenderObject();
  if (ro is! RenderBox || !ro.attached) return null;
  return ro.localToGlobal(Offset.zero) & ro.size;
}

/// Phase-7 export envelope. Top-level keys are the reproducibility
/// metadata (PRD NFR-05); the original engine `SimulationConfig.toJson`
/// goes under `config` so its own `schemaVersion` is preserved.
Map<String, dynamic> buildExportEnvelope(SimulationConfig config) => {
      'engineVersion': kEngineVersion,
      'inputHash': config.inputHash,
      'config': config.toJson(),
    };

/// Parses an imported JSON document into a [SimulationConfig], accepting
/// either the Phase-7 envelope or a bare pre-Phase-7 config map. Returns
/// the embedded config — callers must still call `validate()` themselves.
SimulationConfig parseImportedConfig(Map<String, dynamic> map) {
  // Phase-7 envelope: nested `config` object plus reproducibility metadata.
  final nested = map['config'];
  if (nested is Map) {
    return SimulationConfig.fromJson(nested.cast<String, dynamic>());
  }
  // Pre-Phase-7 bare config: the entire document is a SimulationConfig.
  // Detected by presence of `arrays`, which every config has.
  if (map.containsKey('arrays')) {
    return SimulationConfig.fromJson(map);
  }
  throw ArgumentError(
    'Project JSON is neither a Phase-7 envelope (with "config") '
    'nor a bare SimulationConfig (with "arrays").',
  );
}
