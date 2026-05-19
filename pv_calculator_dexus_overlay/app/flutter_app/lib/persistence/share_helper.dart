// Default `share_helper` implementation. Selected by the conditional
// import in `file_io.dart` and `catalog_file_io.dart` on the web build,
// where `dart:io` (and therefore `share_plus`) is unavailable.
//
// The native counterpart lives in `share_helper_io.dart` and is picked
// up via `if (dart.library.io)` — see the conditional-import pattern
// established by `services/simulation_runner.dart` and
// `persistence/database.dart`.
//
// On web the call sites must never reach this stub: callers gate the
// share branch on [kIsMobilePlatform], which is `false` here. The
// throwing fallback below makes a programming mistake loud rather than
// silently swallowing the export.

import 'dart:typed_data';
import 'dart:ui' show Rect;

const bool kIsMobilePlatform = false;

Future<ShareOutcome> shareBytesViaSheet({
  required String suggestedName,
  required Uint8List bytes,
  required String mimeType,
  Rect? sharePositionOrigin,
}) {
  throw UnsupportedError(
    'shareBytesViaSheet is not available on this platform; '
    'callers must gate on kIsMobilePlatform before invoking it.',
  );
}

/// Three-way outcome of an attempted share-sheet hand-off. Mirrors the
/// `bool` returned by the desktop save flow but adds a `dismissed`
/// state so the SnackBar can distinguish "user backed out" from "the
/// platform reported success".
enum ShareOutcome {
  /// User picked a target app and the file was handed off.
  success,

  /// User dismissed the share sheet without picking a target.
  dismissed,

  /// Platform reported no available share targets.
  unavailable,
}
