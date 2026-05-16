/// Build-time configuration injected via `--dart-define`.
///
/// Set PVGIS_PROXY at build / serve time to route PVGIS requests through
/// the Cloudflare caching worker instead of calling the public API directly:
///
///   flutter build web --dart-define=PVGIS_PROXY=https://pvgis-proxy.example.workers.dev
///
/// When null (the default), PvgisApiService falls back to the public PVGIS host.
const String? pvgisProxyEndpoint =
    bool.hasEnvironment('PVGIS_PROXY') ? String.fromEnvironment('PVGIS_PROXY') : null;
