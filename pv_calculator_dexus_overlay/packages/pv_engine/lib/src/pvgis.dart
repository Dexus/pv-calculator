import 'dart:convert';

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
  });

  final List<PvgisHourlyEntry> entries;
  final double latitudeDeg;
  final double longitudeDeg;

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
  }

  return PvgisHourlyData(entries: entries, latitudeDeg: lat, longitudeDeg: lon);
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
