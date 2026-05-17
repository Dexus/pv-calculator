import 'dart:convert';

import 'pvgis_client.dart' show pvgisSeriesCalcEndpointFor;
import 'weather.dart';

/// Builds the PVGIS `seriescalc` URL for a **horizontal** irradiance request
/// — i.e. one call per site that returns global + diffuse on a flat surface,
/// from which any number of arrays' POA can be derived via [transposeToPoa].
///
/// The returned URL forces `angle=0&aspect=0&components=1&pvcalculation=0`
/// so the response carries the beam/diffuse/reflected split needed to
/// reconstruct GHI and DHI. Pass [endpoint] to point at a caching proxy;
/// when [endpoint] is null, the upstream PVGIS API version is picked from
/// [radDatabase] (v5.2 for SARAH2, v5.3 for everything else).
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
  final base = Uri.parse(
    endpoint ?? pvgisSeriesCalcEndpointFor(radDatabase: radDatabase),
  );
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
    // Gb(i) and Gd(i) are required — silently falling back to 0 would
    // accept a non-components response (e.g. G(i)-only) and produce an
    // all-zero irradiance year, which would silently corrupt simulation
    // results. Gr(i) is always 0 on a horizontal plane but may be absent
    // in some PVGIS response variants, so it keeps its fallback.
    final beam = _readDouble(e, 'Gb(i)', i);
    final diffuse = _readDouble(e, 'Gd(i)', i);
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

double _readDouble(Map<String, dynamic> obj, String key, int index, {double? fallback}) {
  final v = obj[key];
  if (v is num) return v.toDouble();
  if (v == null && fallback != null) return fallback;
  throw FormatException('PVGIS hourly entry $index missing numeric "$key".');
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
