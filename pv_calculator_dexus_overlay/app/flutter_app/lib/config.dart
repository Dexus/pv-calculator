/// Build-time configuration injected via `--dart-define`.
///
/// Set PVGIS_PROXY at build / serve time to route PVGIS requests through
/// the Cloudflare caching worker instead of calling the public API directly:
///
///   flutter build web --dart-define=PVGIS_PROXY=https://pvgis-proxy.example.workers.dev
///
/// Null when the define is absent or blank; callers receive a non-empty
/// string or null, never an empty string that would produce an invalid URI.
// String.fromEnvironment returns '' when the key is absent or set to blank,
// so a single isEmpty check covers both cases without bool.hasEnvironment.
const _rawPvgisProxy = String.fromEnvironment('PVGIS_PROXY');
final String? pvgisProxyEndpoint =
    _rawPvgisProxy.trim().isEmpty ? null : _rawPvgisProxy.trim();

/// Gates Pro-tier features (currently: cyclic SOC convergence).
///
/// Enabled in the GitHub Pages workflow via
/// `--dart-define=PRO_FEATURES=true` so the public web build ships the
/// full feature set; local `flutter run` and standard CI default to the
/// free build. The engine itself is feature-agnostic — Pro gating
/// lives in the UI layer only.
const bool kProFeatures =
    bool.fromEnvironment('PRO_FEATURES', defaultValue: false);
