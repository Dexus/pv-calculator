/// Single source of truth for the version string shown in About / UI.
///
/// Bump in lockstep with `pubspec.yaml`'s `version:` field. The pubspec
/// is the authoritative artifact for build tooling; this constant
/// mirrors the user-visible portion (without the `+buildNumber` suffix)
/// for runtime display, since Dart code can't read pubspec metadata
/// without an extra runtime dependency.
const String appVersion = '0.4.0';
