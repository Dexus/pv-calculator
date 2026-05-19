// Native `share_helper` implementation. Selected by the conditional
// import in `file_io.dart` and `catalog_file_io.dart` whenever
// `dart:library.io` is available (Android, iOS, macOS, Linux, Windows).
//
// The web build picks up `share_helper.dart` instead, which exposes the
// same surface with [kIsMobilePlatform] == false and a throwing fallback.
//
// Desktop platforms (Linux/macOS/Windows) keep [kIsMobilePlatform] false
// so they continue to take the existing `file_selector` save-dialog
// path. Only Android/iOS flip to the share-sheet branch.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

import 'share_helper.dart' show ShareOutcome;

export 'share_helper.dart' show ShareOutcome;

final bool kIsMobilePlatform = Platform.isAndroid || Platform.isIOS;

/// Hands [bytes] off via the OS share sheet on Android / iOS.
///
/// `share_plus` 11 stages the bytes as an in-memory `XFile` and delegates
/// to `UIActivityViewController` (iOS) or `Intent.ACTION_SEND` (Android),
/// so no on-disk temp file is required. The user picks the target app
/// (Files, Drive, Mail, etc.) and the bytes flow there.
///
/// [sharePositionOrigin] anchors the popover on iPad. Without it, iPad
/// throws at runtime — Android and iPhone ignore the field. Callers
/// compute the rect from the trigger button's `RenderBox`; when no box
/// is attached they pass `null` and accept the centre fallback.
Future<ShareOutcome> shareBytesViaSheet({
  required String suggestedName,
  required Uint8List bytes,
  required String mimeType,
  Rect? sharePositionOrigin,
}) async {
  final xfile = XFile.fromData(bytes, mimeType: mimeType, name: suggestedName);
  final params = ShareParams(
    files: [xfile],
    fileNameOverrides: [suggestedName],
    sharePositionOrigin: sharePositionOrigin,
  );
  final result = await SharePlus.instance.share(params);
  switch (result.status) {
    case ShareResultStatus.success:
      return ShareOutcome.success;
    case ShareResultStatus.dismissed:
      return ShareOutcome.dismissed;
    case ShareResultStatus.unavailable:
      return ShareOutcome.unavailable;
  }
}
