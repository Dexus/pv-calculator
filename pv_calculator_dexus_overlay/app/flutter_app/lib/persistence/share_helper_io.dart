// Native `share_helper` implementation. Selected by the conditional
// import in `file_io.dart` and `catalog_file_io.dart` whenever
// `dart.library.io` is available (Android, iOS, macOS, Linux, Windows).
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

/// Fallback anchor used on iOS when the caller couldn't compute a
/// real `RenderBox`-derived rect. `share_plus`'s README is explicit
/// that iPad will crash if `sharePositionOrigin == null` (see the
/// "iPad" section of its README, v11). A 1×1 rect at the screen
/// origin gives `UIActivityViewController` a valid `sourceRect` to
/// anchor to — the popover renders in the top-left corner instead
/// of beside the trigger, which is degraded UX but never crashes.
/// Android / iPhone ignore the field entirely so this fallback is
/// only relevant on iPad.
const Rect _iPadOriginFallback = Rect.fromLTWH(0, 0, 1, 1);

/// Hands [bytes] off via the OS share sheet on Android / iOS.
///
/// `share_plus` 11 stages the bytes as an in-memory `XFile` and delegates
/// to `UIActivityViewController` (iOS) or `Intent.ACTION_SEND` (Android),
/// so no on-disk temp file is required. The user picks the target app
/// (Files, Drive, Mail, etc.) and the bytes flow there.
///
/// [sharePositionOrigin] anchors the popover on iPad and is mandatory
/// there — `share_plus` will crash without it (per its README). Android
/// and iPhone ignore the field. When the caller passes `null` on iOS
/// we substitute [_iPadOriginFallback] so an unattached `RenderBox`
/// can never sink the export.
Future<ShareOutcome> shareBytesViaSheet({
  required String suggestedName,
  required Uint8List bytes,
  required String mimeType,
  Rect? sharePositionOrigin,
}) async {
  final origin = sharePositionOrigin ??
      (Platform.isIOS ? _iPadOriginFallback : null);
  final xfile = XFile.fromData(bytes, mimeType: mimeType, name: suggestedName);
  final params = ShareParams(
    files: [xfile],
    fileNameOverrides: [suggestedName],
    sharePositionOrigin: origin,
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
