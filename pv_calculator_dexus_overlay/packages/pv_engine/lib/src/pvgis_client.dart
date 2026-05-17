/// Pure-Dart helpers for building PVGIS `seriescalc` HTTP requests.
///
/// Stays in `pv_engine` so the URL/loss/azimuth conventions live next
/// to the parser they feed into, without adding an `http` runtime
/// dependency. The Flutter app (or any other caller) is responsible
/// for issuing the request — see `pv_calculator_app/services/pvgis_api.dart`.
library;

/// Default public PVGIS endpoint. The v5.3 series-calc service is the
/// one the HTML reference prototype uses; bumping the API version goes
/// here so adapters don't need to repeat the string. v5.3 serves
/// `PVGIS-SARAH3`, `PVGIS-ERA5` and `PVGIS-NSRDB` — see
/// [pvgisSeriesCalcEndpointFor] for SARAH2, which lives on v5.2.
const String pvgisSeriesCalcEndpoint =
    'https://re.jrc.ec.europa.eu/api/v5_3/seriescalc';

/// PVGIS v5.2 series-calc service — the only upstream that still serves
/// the legacy `PVGIS-SARAH2` database. v5.3 dropped SARAH2, so SARAH2
/// requests must go here or PVGIS returns a "database not available"
/// error.
const String pvgisSeriesCalcEndpointV52 =
    'https://re.jrc.ec.europa.eu/api/v5_2/seriescalc';

/// Picks the PVGIS series-calc endpoint that serves [radDatabase]:
/// v5.2 for SARAH2, v5.3 for everything else (including the `null`
/// "PVGIS picks the default" case). Centralised here so the URL
/// builders, the Flutter HTTP service, and the Cloudflare proxy
/// agree on one routing rule.
String pvgisSeriesCalcEndpointFor({String? radDatabase}) {
  if (radDatabase == 'PVGIS-SARAH2') return pvgisSeriesCalcEndpointV52;
  return pvgisSeriesCalcEndpoint;
}

/// Parameters for one PVGIS `seriescalc` request.
///
/// Mirrors the subset of fields the existing HTML prototype sends:
/// fixed-mount, `pvcalculation=1`, optional `raddatabase`. Azimuth is
/// stored in this engine's 0–360° convention (0/360 = north,
/// 180 = south) and converted to PVGIS's −180…+180 (south = 0) at
/// URL-build time so callers never have to remember which side they're
/// on.
class PvgisRequest {
  const PvgisRequest({
    required this.latitudeDeg,
    required this.longitudeDeg,
    required this.peakKw,
    required this.tiltDeg,
    required this.appAzimuthDeg,
    this.lossFactor = 0.14,
    this.mountingPlace = 'building',
    required this.startYear,
    required this.endYear,
    this.radDatabase,
    this.useHorizon = true,
  });

  /// Site latitude in degrees, WGS-84.
  final double latitudeDeg;

  /// Site longitude in degrees, WGS-84.
  final double longitudeDeg;

  /// Module nameplate power in kWp. Forwarded to PVGIS as `peakpower`.
  final double peakKw;

  /// Tilt above horizontal in degrees (0 = flat, 90 = vertical).
  /// Forwarded to PVGIS as `angle`.
  final double tiltDeg;

  /// Module azimuth in the engine's 0–360° convention (0/360 = north,
  /// 90 = east, 180 = south, 270 = west). Converted to PVGIS's
  /// −180…+180 (south = 0) inside [buildPvgisSeriesCalcUrl].
  final double appAzimuthDeg;

  /// System losses as a fraction in [0, 1) — the same units used by
  /// [`PvArray.lossFactor`]. Multiplied by 100 to obtain the PVGIS
  /// `loss` percentage at URL-build time.
  final double lossFactor;

  /// PVGIS `mountingplace` parameter. Accepted values: `building`
  /// (roof-mounted, default) or `free` (free-standing).
  final String mountingPlace;

  /// First calendar year of PVGIS data to request (inclusive).
  final int startYear;

  /// Last calendar year of PVGIS data to request (inclusive).
  final int endYear;

  /// Optional radiation database name, e.g. `PVGIS-SARAH3`. When
  /// `null`, PVGIS picks the default for the requested location.
  final String? radDatabase;

  /// PVGIS `usehorizon` flag. Defaults to `true` to include the
  /// terrain-horizon shading model.
  final bool useHorizon;

  /// Throws [ArgumentError] when the request would produce an
  /// obviously invalid URL (out-of-range coordinates, non-positive
  /// peak power, inverted year window, …). Cheap enough to call before
  /// every fetch so the network never sees junk requests.
  void validate() {
    _require(latitudeDeg >= -90 && latitudeDeg <= 90,
        'PVGIS latitude must be in [-90, 90].');
    _require(longitudeDeg >= -180 && longitudeDeg <= 180,
        'PVGIS longitude must be in [-180, 180].');
    _require(peakKw > 0, 'PVGIS peakKw must be positive.');
    _require(tiltDeg >= 0 && tiltDeg <= 90,
        'PVGIS tiltDeg must be in [0, 90].');
    _require(appAzimuthDeg >= 0 && appAzimuthDeg <= 360,
        'PVGIS appAzimuthDeg must be in [0, 360].');
    _require(lossFactor >= 0 && lossFactor < 1,
        'PVGIS lossFactor must be in [0, 1).');
    _require(mountingPlace == 'building' || mountingPlace == 'free',
        'PVGIS mountingPlace must be "building" or "free".');
    _require(startYear >= 2005,
        'PVGIS startYear must be 2005 or later.');
    _require(endYear >= startYear,
        'PVGIS endYear must be >= startYear.');
  }
}

/// Builds the `seriescalc` URL for [request] in PV-power mode
/// (`pvcalculation=1`). Kept for future per-array PV-power requests
/// (and to validate the cache-key plumbing in the Cloudflare proxy);
/// the redesigned app's main flow goes through
/// [pvgisHorizontalSeriesUrl] instead, which fetches once per site
/// and lets the engine transpose to POA.
///
/// Pass [endpoint] to override the default public PVGIS host (useful
/// for a self-hosted instance or a CORS-relaxing reverse proxy).
Uri buildPvgisSeriesCalcUrl(PvgisRequest request, {String? endpoint}) {
  request.validate();
  final base = Uri.parse(
    endpoint ?? pvgisSeriesCalcEndpointFor(radDatabase: request.radDatabase),
  );
  final params = <String, String>{
    'lat': request.latitudeDeg.toStringAsFixed(6),
    'lon': request.longitudeDeg.toStringAsFixed(6),
    'startyear': request.startYear.toString(),
    'endyear': request.endYear.toString(),
    'pvcalculation': '1',
    'peakpower': _formatNumber(request.peakKw),
    'loss': _formatNumber(request.lossFactor * 100),
    'angle': _formatNumber(request.tiltDeg),
    'aspect': _formatNumber(appAzimuthToPvgis(request.appAzimuthDeg)),
    'mountingplace': request.mountingPlace,
    'outputformat': 'json',
    'usehorizon': request.useHorizon ? '1' : '0',
  };
  final db = request.radDatabase;
  if (db != null && db.isNotEmpty) {
    params['raddatabase'] = db;
  }
  return base.replace(queryParameters: params);
}

/// Engine 0–360° azimuth → PVGIS −180…+180° (south = 0). Accepts the
/// closed interval `[0, 360]` (callers may legitimately pass either
/// endpoint for north); returns a value in `(-180, 180]` so `180.0`
/// (north via the `360` end) stays a single canonical north.
double appAzimuthToPvgis(double appAzimuthDeg) {
  // Bring into [-180, +180): subtract south offset, normalise modulo 360.
  final shifted = appAzimuthDeg - 180.0;
  final wrapped = ((shifted % 360.0) + 540.0) % 360.0 - 180.0;
  // Prefer +180 over -180 so `appAz == 360` and `appAz == 0` collapse
  // to the same canonical north and the URL stays stable across
  // equivalent inputs.
  return wrapped == -180.0 ? 180.0 : wrapped;
}

/// Drops a trailing `.0` for whole-number values so the URL stays
/// short ("1" vs "1.0"). PVGIS accepts both, but the HTML prototype
/// formats numbers the same way and tests assert on the URL shape.
String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  // Trim trailing zeros from the fractional part for readability.
  var s = value.toStringAsFixed(6);
  while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

void _require(bool condition, String message) {
  if (!condition) throw ArgumentError(message);
}
