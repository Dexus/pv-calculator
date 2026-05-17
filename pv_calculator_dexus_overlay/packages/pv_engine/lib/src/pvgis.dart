import 'dart:convert';

import 'pvgis_client.dart' show pvgisSeriesCalcEndpoint;
import 'weather.dart';

/// One hourly record from a PVGIS `seriescalc` response.
///
/// PVGIS field mapping:
///   * `G(i)` → [poaIrradianceWPerM2] (W/m² on the tilted plane)
///   * `T2m`  → [ambientTempC] (°C at 2 m)
///   * `WS10m` → [windMS] (m/s at 10 m)
///   * `P`    → [pvPowerW] (W, only present if PVGIS computed power)
class PvgisHourlyEntry {
  const PvgisHourlyEntry({
    required this.timestampUtc,
    required this.poaIrradianceWPerM2,
    required this.ambientTempC,
    required this.windMS,
    this.pvPowerW,
  });

  final DateTime timestampUtc;
  final double poaIrradianceWPerM2;
  final double ambientTempC;
  final double windMS;
  final double? pvPowerW;

  int get dayOfYear {
    final t = timestampUtc;
    final start = DateTime.utc(t.year, 1, 1);
    return t.difference(start).inDays + 1;
  }
}

/// Parsed PVGIS hourly time-series for one location/orientation.
///
/// Holds the raw entries plus convenience accessors. Use
/// [toAveragedYear] to fold multi-year data into a single 365×24 TMY
/// suitable for [HourlyWeatherSeries].
class PvgisHourlyData {
  const PvgisHourlyData({
    required this.entries,
    required this.latitudeDeg,
    required this.longitudeDeg,
    this.slopeDeg,
    this.azimuthDegPvgis,
  });

  final List<PvgisHourlyEntry> entries;
  final double latitudeDeg;
  final double longitudeDeg;

  /// Module tilt the PVGIS request was generated for, in degrees from
  /// horizontal. Read from `inputs.mounting_system.fixed.slope.value`.
  /// `null` when the document doesn't carry mounting metadata (e.g.
  /// hand-trimmed fixtures).
  final double? slopeDeg;

  /// Module azimuth the PVGIS request was generated for, **in the
  /// PVGIS convention**: 0° = south, negative = east, positive = west
  /// (range −180…+180). Read from
  /// `inputs.mounting_system.fixed.azimuth.value`. Use
  /// [appAzimuthDeg] to compare against this engine's
  /// `PvArray.azimuthDeg` field, which uses the 0° = north / 180° =
  /// south convention.
  final double? azimuthDegPvgis;

  /// PVGIS azimuth translated into the engine's 0–360° convention
  /// (0/360 = north, 90 = east, 180 = south, 270 = west). `null` when
  /// [azimuthDegPvgis] is missing.
  double? get appAzimuthDeg {
    final p = azimuthDegPvgis;
    if (p == null) return null;
    return (180.0 + p + 360.0) % 360.0;
  }

  /// Average each (dayOfYear, hour) across every covered year and
  /// return 8760 samples (Feb 29 ignored — engine uses a 365-day year).
  ///
  /// Bucketing is by `timestampUtc.hour` only — the minute component
  /// is dropped. PVGIS labels its hourly entries by the start of the
  /// hour with a small minute offset that varies by radiation
  /// database (SARAH uses `:10`, ERA5 uses `:30`); both represent the
  /// same hour window, so flooring to `t.hour` keeps SARAH and ERA5
  /// records in the same slot. Sub-hour resampling would need a
  /// proper resolution-aware bucketer.
  List<WeatherSample> toAveragedYear() {
    final poa = List<double>.filled(365 * 24, 0);
    final temp = List<double>.filled(365 * 24, 0);
    final wind = List<double>.filled(365 * 24, 0);
    final count = List<int>.filled(365 * 24, 0);

    for (final e in entries) {
      final t = e.timestampUtc;
      // Skip leap day so we always map to a 365-day calendar.
      if (t.month == 2 && t.day == 29) continue;
      final dayOfYearNonLeap = _dayOfYearNonLeap(t);
      final slot = (dayOfYearNonLeap - 1) * 24 + t.hour;
      if (slot < 0 || slot >= poa.length) continue;
      poa[slot] += e.poaIrradianceWPerM2;
      temp[slot] += e.ambientTempC;
      wind[slot] += e.windMS;
      count[slot] += 1;
    }

    return List<WeatherSample>.generate(365 * 24, (i) {
      final n = count[i];
      if (n == 0) return WeatherSample.empty;
      return WeatherSample(
        poaWPerM2: poa[i] / n,
        ambientTempC: temp[i] / n,
        windMS: wind[i] / n,
      );
    }, growable: false);
  }

  static int _dayOfYearNonLeap(DateTime t) {
    const cumDaysNonLeap = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
    return cumDaysNonLeap[t.month - 1] + t.day;
  }
}

/// Parses PVGIS `seriescalc` output. Accepts the JSON document
/// PVGIS returns when called with `outputformat=json`.
///
/// Throws [FormatException] if the document is missing the
/// `outputs.hourly` array or any individual entry can't be parsed.
PvgisHourlyData parsePvgisHourlyJson(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException catch (e) {
    throw FormatException('PVGIS JSON is not valid JSON: ${e.message}');
  }
  if (decoded is! Map) {
    throw const FormatException('PVGIS JSON must be a top-level object.');
  }
  final root = decoded.cast<String, dynamic>();
  final outputs = root['outputs'];
  if (outputs is! Map) {
    throw const FormatException('PVGIS JSON missing "outputs" object.');
  }
  final hourly = outputs['hourly'];
  if (hourly is! List) {
    throw const FormatException('PVGIS JSON missing "outputs.hourly" array.');
  }

  final entries = <PvgisHourlyEntry>[];
  for (var i = 0; i < hourly.length; i++) {
    final raw = hourly[i];
    if (raw is! Map) {
      throw FormatException('PVGIS hourly entry $i is not an object.');
    }
    final e = raw.cast<String, dynamic>();
    final timeStr = e['time'];
    if (timeStr is! String) {
      throw FormatException('PVGIS hourly entry $i has no "time" string.');
    }
    final ts = _parsePvgisTimestamp(timeStr, i);
    final p = e['P'];
    entries.add(PvgisHourlyEntry(
      timestampUtc: ts,
      poaIrradianceWPerM2: _readDouble(e, 'G(i)', i),
      ambientTempC: _readDouble(e, 'T2m', i),
      windMS: _readDouble(e, 'WS10m', i, fallback: 1.0),
      pvPowerW: p is num ? p.toDouble() : null,
    ));
  }

  double lat = 0;
  double lon = 0;
  double? slope;
  double? azimuth;
  final inputs = root['inputs'];
  if (inputs is Map) {
    final location = inputs['location'];
    if (location is Map) {
      final loc = location.cast<String, dynamic>();
      final latRaw = loc['latitude'];
      final lonRaw = loc['longitude'];
      if (latRaw is num) lat = latRaw.toDouble();
      if (lonRaw is num) lon = lonRaw.toDouble();
    }
    final mounting = inputs['mounting_system'];
    if (mounting is Map) {
      final fixed = mounting['fixed'];
      if (fixed is Map) {
        final fixedMap = fixed.cast<String, dynamic>();
        slope = _readOptionalAngle(fixedMap, 'slope');
        azimuth = _readOptionalAngle(fixedMap, 'azimuth');
      }
    }
  }

  return PvgisHourlyData(
    entries: entries,
    latitudeDeg: lat,
    longitudeDeg: lon,
    slopeDeg: slope,
    azimuthDegPvgis: azimuth,
  );
}

/// PVGIS wraps each angle in `{"value": …, "optimal": …}`. Returns
/// `null` when the block is absent or its `value` is not numeric.
double? _readOptionalAngle(Map<String, dynamic> fixed, String key) {
  final block = fixed[key];
  if (block is! Map) return null;
  final value = block['value'];
  if (value is num) return value.toDouble();
  return null;
}

double _readDouble(Map<String, dynamic> obj, String key, int index, {double? fallback}) {
  final v = obj[key];
  if (v is num) return v.toDouble();
  if (v == null && fallback != null) return fallback;
  throw FormatException('PVGIS hourly entry $index missing numeric "$key".');
}

/// Builds the PVGIS `seriescalc` URL for a **horizontal** irradiance request
/// — i.e. one call per site that returns global + diffuse on a flat surface,
/// from which any number of arrays' POA can be derived via [transposeToPoa].
///
/// The returned URL forces `angle=0&aspect=0&components=1&pvcalculation=0`
/// so the response carries the beam/diffuse/reflected split needed to
/// reconstruct GHI and DHI. Pass [endpoint] to point at a caching proxy.
Uri pvgisHorizontalSeriesUrl({
  required double latitudeDeg,
  required double longitudeDeg,
  required int year,
  String? radDatabase,
  bool useHorizon = true,
  String? endpoint,
}) {
  if (latitudeDeg < -90 || latitudeDeg > 90) {
    throw ArgumentError('latitudeDeg must be in [-90, 90].');
  }
  if (longitudeDeg < -180 || longitudeDeg > 180) {
    throw ArgumentError('longitudeDeg must be in [-180, 180].');
  }
  if (year < 2005) {
    throw ArgumentError('year must be 2005 or later.');
  }
  final base = Uri.parse(endpoint ?? pvgisSeriesCalcEndpoint);
  final params = <String, String>{
    'lat': latitudeDeg.toStringAsFixed(6),
    'lon': longitudeDeg.toStringAsFixed(6),
    'startyear': year.toString(),
    'endyear': year.toString(),
    'angle': '0',
    'aspect': '0',
    'components': '1',
    'pvcalculation': '0',
    'outputformat': 'json',
    'usehorizon': useHorizon ? '1' : '0',
  };
  if (radDatabase != null && radDatabase.isNotEmpty) {
    params['raddatabase'] = radDatabase;
  }
  return base.replace(queryParameters: params);
}

/// Parses a PVGIS `seriescalc&angle=0&aspect=0&components=1` JSON document
/// into a [HorizontalIrradianceSeries].
///
/// On a horizontal plane, PVGIS reports the beam/diffuse/reflected
/// components as `Gb(i)`, `Gd(i)`, `Gr(i)` (the `(i)` suffix refers to the
/// requested plane — flat in this case). Reflected on horizontal is 0, so
/// `GHI = Gb(i) + Gd(i)` and `DHI = Gd(i)`. Leap days are dropped to keep
/// the 365×24 indexing the rest of the engine assumes.
///
/// Throws [FormatException] when the document is missing required fields.
HorizontalIrradianceSeries parsePvgisHorizontalSeries(
  String json, {
  required int year,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException catch (e) {
    throw FormatException('PVGIS JSON is not valid JSON: ${e.message}');
  }
  if (decoded is! Map) {
    throw const FormatException('PVGIS JSON must be a top-level object.');
  }
  final root = decoded.cast<String, dynamic>();
  final outputs = root['outputs'];
  if (outputs is! Map) {
    throw const FormatException('PVGIS JSON missing "outputs" object.');
  }
  final hourly = outputs['hourly'];
  if (hourly is! List) {
    throw const FormatException('PVGIS JSON missing "outputs.hourly" array.');
  }

  double lat = 0;
  double lon = 0;
  String? rad;
  final inputs = root['inputs'];
  if (inputs is Map) {
    final location = inputs['location'];
    if (location is Map) {
      final loc = location.cast<String, dynamic>();
      final latRaw = loc['latitude'];
      final lonRaw = loc['longitude'];
      if (latRaw is num) lat = latRaw.toDouble();
      if (lonRaw is num) lon = lonRaw.toDouble();
    }
    final meteo = inputs['meteo_data'];
    if (meteo is Map) {
      final db = meteo['radiation_db'];
      if (db is String && db.isNotEmpty) rad = db;
    }
  }

  // Sum hourly samples into 365×24 slots keyed by (dayOfYear, hour). Multi-
  // year inputs are folded by averaging — single-year is the common case
  // for the UI year picker, but averaging keeps the code resilient to
  // accidental multi-year fixtures.
  final ghi = List<double>.filled(365 * 24, 0);
  final dhi = List<double>.filled(365 * 24, 0);
  final temp = List<double>.filled(365 * 24, 0);
  final wind = List<double>.filled(365 * 24, 0);
  final count = List<int>.filled(365 * 24, 0);

  for (var i = 0; i < hourly.length; i++) {
    final raw = hourly[i];
    if (raw is! Map) {
      throw FormatException('PVGIS hourly entry $i is not an object.');
    }
    final e = raw.cast<String, dynamic>();
    final timeStr = e['time'];
    if (timeStr is! String) {
      throw FormatException('PVGIS hourly entry $i has no "time" string.');
    }
    final t = _parsePvgisTimestamp(timeStr, i);
    if (t.month == 2 && t.day == 29) continue;
    final beam = _readDouble(e, 'Gb(i)', i, fallback: 0);
    final diffuse = _readDouble(e, 'Gd(i)', i, fallback: 0);
    final reflected = _readDouble(e, 'Gr(i)', i, fallback: 0);
    final tAmb = _readDouble(e, 'T2m', i, fallback: 25);
    final wMs = _readDouble(e, 'WS10m', i, fallback: 1);
    final doy = _dayOfYearNonLeap(t);
    final slot = (doy - 1) * 24 + t.hour;
    if (slot < 0 || slot >= ghi.length) continue;
    // Reflected is always 0 on a horizontal plane in a PVGIS response, but
    // sum it defensively in case PVGIS ever starts including ground bounce
    // here.
    ghi[slot] += beam + diffuse + reflected;
    dhi[slot] += diffuse;
    temp[slot] += tAmb;
    wind[slot] += wMs;
    count[slot] += 1;
  }

  final samples = List<HorizontalIrradianceSample>.generate(365 * 24, (i) {
    final n = count[i];
    if (n == 0) return HorizontalIrradianceSample.empty;
    return HorizontalIrradianceSample(
      globalHorizontalWPerM2: ghi[i] / n,
      diffuseHorizontalWPerM2: dhi[i] / n,
      ambientTempC: temp[i] / n,
      windMS: wind[i] / n,
    );
  }, growable: false);

  return HorizontalIrradianceSeries(
    samples: samples,
    year: year,
    latitudeDeg: lat,
    longitudeDeg: lon,
    radDatabase: rad,
  );
}

int _dayOfYearNonLeap(DateTime t) {
  const cumDaysNonLeap = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  return cumDaysNonLeap[t.month - 1] + t.day;
}

/// PVGIS timestamps are `YYYYMMDD:HHMM` strings in UTC.
DateTime _parsePvgisTimestamp(String value, int index) {
  // Two accepted shapes: "YYYYMMDD:HHMM" (current PVGIS) and the
  // looser "YYYY-MM-DDTHH:MM" — the latter only as a courtesy for
  // hand-trimmed test fixtures.
  if (value.length == 13 && value[8] == ':') {
    final year = int.tryParse(value.substring(0, 4));
    final month = int.tryParse(value.substring(4, 6));
    final day = int.tryParse(value.substring(6, 8));
    final hour = int.tryParse(value.substring(9, 11));
    final minute = int.tryParse(value.substring(11, 13));
    if (year != null && month != null && day != null && hour != null && minute != null) {
      return DateTime.utc(year, month, day, hour, minute);
    }
  }
  final iso = DateTime.tryParse(value);
  if (iso != null) return iso.toUtc();
  throw FormatException('PVGIS hourly entry $index has unrecognised time "$value".');
}
