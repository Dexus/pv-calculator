import 'dart:convert' show LineSplitter;

import '../pv_engine.dart' show LoadProfile;

/// Parses a CSV export from a Smartmeter, Home Assistant or Shelly device
/// into a [LoadProfile]. Auto-detects delimiter (`;`, `,` or tab) and the
/// header row; the value column may be power (W or kW) or energy (Wh or
/// kWh). Sub-hourly rows are aggregated into 24 hourly buckets and multi-
/// day inputs are averaged into one representative day.
///
/// Throws [FormatException] when the header can't be found, no usable
/// rows survive, or the resulting profile has zero daily energy.
LoadProfile parseLoadProfileCsv(String csv) {
  final lines = const LineSplitter().convert(csv);
  if (lines.isEmpty) {
    throw const FormatException('CSV ist leer.');
  }

  final delimiter = _detectDelimiter(lines);

  final header = _findHeader(lines, delimiter);
  final cols = _resolveColumns(header.cells);

  final samples = <_Sample>[];
  for (var i = header.lineIndex + 1; i < lines.length; i++) {
    final raw = lines[i];
    if (raw.trim().isEmpty) continue;
    final cells = _splitCsvRow(raw, delimiter);
    final ts = cols.timeIdx != null
        ? _parseTimestamp(_cell(cells, cols.timeIdx!))
        : _parseTimestamp(
            '${_cell(cells, cols.dateIdx!)} ${_cell(cells, cols.timeOfDayIdx!)}');
    if (ts == null) continue;
    final value = _parseNumber(_cell(cells, cols.valueIdx));
    if (value == null) continue;
    samples.add(_Sample(ts, value));
  }
  if (samples.isEmpty) {
    throw const FormatException('Keine verwertbaren Zeilen gefunden.');
  }

  // Energy columns may carry either per-interval increments (delta-style)
  // or a monotonically non-decreasing meter reading (cumulative kWh, as
  // a Home Assistant energy-sensor `state` export looks like). Sort by
  // timestamp, and if the series never decreases convert it to deltas —
  // otherwise summing inside the hour buckets would multiply the meter
  // reading instead of accumulating the actual consumption.
  if (cols.valueKind == _ValueKind.energy && samples.length >= 2) {
    samples.sort((a, b) => a.ts.compareTo(b.ts));
    var cumulative = true;
    for (var i = 1; i < samples.length; i++) {
      if (samples[i].value < samples[i - 1].value) {
        cumulative = false;
        break;
      }
    }
    if (cumulative) {
      final deltas = <_Sample>[];
      for (var i = 1; i < samples.length; i++) {
        deltas.add(_Sample(
          samples[i].ts,
          samples[i].value - samples[i - 1].value,
        ));
      }
      samples
        ..clear()
        ..addAll(deltas);
      if (samples.isEmpty) {
        throw const FormatException(
            'Keine verwertbaren Zeilen gefunden.');
      }
    }
  }

  // Decide unit scaling. Honor an explicit unit annotation from the
  // header (`[W]`, `[kW]`, `[Wh]`, `[kWh]`) first — without it a
  // `Wirkleistung [W]` file with 100 W in every hour would otherwise
  // get the magnitude inference treatment and import as 2.4 MWh/day
  // instead of 2.4 kWh/day. Falls back to the magnitude heuristic
  // (95th percentile vs. 200) only when the header carries no unit.
  final scaleToKw = cols.explicitKwScale ?? _inferKwScale(samples);

  // Bucket per absolute calendar hour so two years of data don't collapse
  // onto the same day-of-year slot.
  final buckets = <int, List<double>>{};
  for (final s in samples) {
    final key = _absoluteHourKey(s.ts);
    (buckets[key] ??= <double>[]).add(s.value);
  }

  // For power inputs we treat each bucket as average power × 1 hour; for
  // energy inputs we sum the bucket. Both produce kWh in the bucket.
  final kwhPerBucket = <int, double>{};
  buckets.forEach((key, values) {
    final aggregated = cols.valueKind == _ValueKind.power
        ? values.reduce((a, b) => a + b) / values.length
        : values.reduce((a, b) => a + b);
    kwhPerBucket[key] = aggregated * scaleToKw;
  });

  // Aggregate per hour-of-day. Counting distinct calendar dates would
  // halve a noon-to-noon 24-hour export (which crosses midnight but
  // still samples each hour exactly once); instead, each hour-of-day
  // bucket is divided by the number of (day, hour) buckets that
  // actually contributed to it.
  final shape = List<double>.filled(24, 0.0);
  final occupancy = List<int>.filled(24, 0);
  kwhPerBucket.forEach((key, kwh) {
    final hour = key % 24;
    shape[hour] += kwh;
    occupancy[hour] += 1;
  });
  if (!occupancy.any((c) => c > 0)) {
    throw const FormatException('Keine verwertbaren Zeilen gefunden.');
  }
  for (var h = 0; h < 24; h++) {
    if (occupancy[h] > 0) shape[h] /= occupancy[h];
  }

  final dailyKwh = shape.fold<double>(0.0, (s, v) => s + v);
  if (dailyKwh <= 0) {
    throw const FormatException('Tagesverbrauch ist 0 — keine Werte erkannt.');
  }
  return LoadProfile(dailyKwh: dailyKwh, hourlyShape: shape);
}

// ---------------------------------------------------------------------------
// Internals
// ---------------------------------------------------------------------------

enum _ValueKind { power, energy }

class _Sample {
  const _Sample(this.ts, this.value);
  final DateTime ts;
  final double value;
}

class _HeaderMatch {
  const _HeaderMatch(this.lineIndex, this.cells);
  final int lineIndex;
  final List<String> cells;
}

class _ColumnMap {
  const _ColumnMap({
    required this.valueIdx,
    required this.valueKind,
    this.explicitKwScale,
    this.timeIdx,
    this.dateIdx,
    this.timeOfDayIdx,
  });
  final int valueIdx;
  final _ValueKind valueKind;

  /// Multiplier from raw value to kWh when the header carries an
  /// unambiguous unit annotation (`1.0` for kW/kWh, `0.001` for W/Wh).
  /// `null` means the header was ambiguous and the magnitude heuristic
  /// in `_inferKwScale` decides.
  final double? explicitKwScale;
  final int? timeIdx;
  final int? dateIdx;
  final int? timeOfDayIdx;
}

const _powerHeaders = <String>{
  'power', 'p', 'leistung', 'wirkleistung', 'load', 'last',
};
const _energyHeaders = <String>{
  'energy', 'energie', 'verbrauch', 'state', 'e', 'kwh', 'wh',
};

String _detectDelimiter(List<String> lines) {
  var bestCount = -1;
  var best = ';';
  for (final c in const [';', ',', '\t']) {
    var count = 0;
    var seen = 0;
    for (final l in lines) {
      if (l.trim().isEmpty) continue;
      count += _occurrences(l, c);
      seen++;
      if (seen >= 8) break;
    }
    if (count > bestCount) {
      bestCount = count;
      best = c;
    }
  }
  return best;
}

_HeaderMatch _findHeader(List<String> lines, String delimiter) {
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trim().isEmpty) continue;
    final cells = _splitCsvRow(lines[i], delimiter);
    if (cells.isEmpty) continue;
    final lower = cells.map((c) => c.trim().toLowerCase()).toList();
    final hasDate = lower.any(_isDateOnlyHeader);
    final hasTimeOfDay = lower.any(_isTimeOfDayOnlyHeader);
    final hasTime = lower.any(_isTimeHeader) || (hasDate && hasTimeOfDay);
    final hasValue = lower.any((c) => _valueColumnKind(c) != null);
    if (hasTime && hasValue) {
      return _HeaderMatch(i, cells.map((c) => c.trim()).toList());
    }
  }
  throw const FormatException(
      'Kein Header mit Zeit- und Werte-Spalte gefunden.');
}

_ColumnMap _resolveColumns(List<String> headerCells) {
  final lower =
      headerCells.map((c) => c.trim().toLowerCase()).toList(growable: false);

  int? timeIdx;
  int? dateIdx;
  int? timeOfDayIdx;

  // Prefer a single combined timestamp column when present
  for (var i = 0; i < lower.length; i++) {
    if (_isCombinedTimeHeader(lower[i]) && timeIdx == null) {
      timeIdx = i;
    }
  }
  if (timeIdx == null) {
    for (var i = 0; i < lower.length; i++) {
      if (_isDateOnlyHeader(lower[i]) && dateIdx == null) dateIdx = i;
      if (_isTimeOfDayOnlyHeader(lower[i]) && timeOfDayIdx == null) {
        timeOfDayIdx = i;
      }
    }
    // Single time-of-day column without a date column is still a combined
    // timestamp (Shelly's split format always carries both).
    if (timeOfDayIdx != null && dateIdx == null) {
      timeIdx = timeOfDayIdx;
      timeOfDayIdx = null;
    }
  }
  if (timeIdx == null && (dateIdx == null || timeOfDayIdx == null)) {
    throw const FormatException('Keine Zeit-Spalte gefunden.');
  }

  int? valueIdx;
  _ValueKind? valueKind;
  double? explicitKwScale;
  for (var i = 0; i < lower.length; i++) {
    if (i == timeIdx || i == dateIdx || i == timeOfDayIdx) continue;
    final kind = _valueColumnKind(lower[i]);
    if (kind != null) {
      valueIdx = i;
      valueKind = kind;
      explicitKwScale = _explicitKwScale(lower[i]);
      break;
    }
  }
  if (valueIdx == null || valueKind == null) {
    throw const FormatException(
        'Keine Leistungs- oder Energie-Spalte gefunden.');
  }

  return _ColumnMap(
    valueIdx: valueIdx,
    valueKind: valueKind,
    explicitKwScale: explicitKwScale,
    timeIdx: timeIdx,
    dateIdx: dateIdx,
    timeOfDayIdx: timeOfDayIdx,
  );
}

bool _isTimeHeader(String h) {
  final s = h.trim().toLowerCase();
  return _isCombinedTimeHeader(s) ||
      _isDateOnlyHeader(s) ||
      _isTimeOfDayOnlyHeader(s);
}

bool _isCombinedTimeHeader(String h) {
  return h == 'timestamp' ||
      h == 'zeitstempel' ||
      h == 'zeit' ||
      h == 'datetime' ||
      h == 'date/time';
}

bool _isDateOnlyHeader(String h) => h == 'date' || h == 'datum';

bool _isTimeOfDayOnlyHeader(String h) => h == 'time' || h == 'uhrzeit';

/// Returns the explicit kWh-per-value multiplier when [header] carries an
/// unambiguous unit annotation (`[W]`, `[kW]`, `[Wh]`, `[kWh]`, or the same
/// bare suffixes at the end of the label). `null` means the header was
/// ambiguous and the caller's magnitude heuristic should take over.
double? _explicitKwScale(String header) {
  final h = header.trim().toLowerCase();
  // Match unit tokens as standalone words so `power`/`wirkleistung` don't
  // trigger on their `w` prefix. Order matters: kwh / wh before kw / w
  // so `kWh` doesn't match `kw` first.
  if (RegExp(r'(?<![a-z])kwh(?![a-z])').hasMatch(h)) return 1.0;
  if (RegExp(r'(?<![a-z])wh(?![a-z])').hasMatch(h)) return 1.0 / 1000.0;
  if (RegExp(r'(?<![a-z])kw(?![a-z])').hasMatch(h)) return 1.0;
  if (RegExp(r'(?<![a-z])w(?![a-z])').hasMatch(h)) return 1.0 / 1000.0;
  return null;
}

_ValueKind? _valueColumnKind(String header) {
  final h = header.trim().toLowerCase();
  if (h.isEmpty) return null;
  // Strip unit annotations like `[kW]`, `(W)` or `kw` so a header such as
  // `wirkleistung [w]` reduces to its base label.
  final bareMatch = RegExp(r'^([^\[\(]+)').firstMatch(h);
  final bare = (bareMatch?.group(1) ?? h).trim();
  if (_powerHeaders.contains(bare)) return _ValueKind.power;
  if (_energyHeaders.contains(bare)) return _ValueKind.energy;
  // Bracketed units alone are a strong enough signal. Check energy first
  // because `kwh` contains `kw`.
  if (h.contains('kwh') || h.contains('wh')) return _ValueKind.energy;
  if (h.contains('kw') || h.endsWith('w]') || h.endsWith('w)') ||
      h.endsWith(' w')) {
    return _ValueKind.power;
  }
  return null;
}

double _inferKwScale(List<_Sample> samples) {
  // 95th percentile of |value| keeps the heuristic robust to outliers.
  final sorted = samples.map((s) => s.value.abs()).toList()..sort();
  final p95 = sorted[(sorted.length * 0.95).floor().clamp(0, sorted.length - 1)];
  return p95 > 200 ? 1.0 / 1000.0 : 1.0;
}

DateTime? _parseTimestamp(String s) {
  final raw = s.trim();
  if (raw.isEmpty) return null;

  // PVGIS-style `YYYYMMDD:HHMM` or `YYYYMMDDHHMM`.
  final compact =
      RegExp(r'^(\d{4})(\d{2})(\d{2})[: ]?(\d{2})(\d{2})$').firstMatch(raw);
  if (compact != null) {
    return DateTime(
      int.parse(compact.group(1)!),
      int.parse(compact.group(2)!),
      int.parse(compact.group(3)!),
      int.parse(compact.group(4)!),
      int.parse(compact.group(5)!),
    );
  }

  // ISO 8601 with optional timezone offset. We parse the wall-clock
  // components and ignore the offset on purpose — for a load profile,
  // the *recorded* local hour is what matters; converting to UTC would
  // shift sunrise on the input by the offset.
  final iso = RegExp(
          r'^(\d{4})-(\d{1,2})-(\d{1,2})[T ](\d{1,2}):(\d{2})(?::(\d{2}))?(?:\.\d+)?(?:Z|[+\-]\d{2}:?\d{2})?$')
      .firstMatch(raw);
  if (iso != null) {
    return DateTime(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
      int.parse(iso.group(4)!),
      int.parse(iso.group(5)!),
      int.parse(iso.group(6) ?? '0'),
    );
  }

  // German `DD.MM.YYYY HH:MM[:SS]`.
  final german = RegExp(
          r'^(\d{1,2})\.(\d{1,2})\.(\d{4})[ T](\d{1,2}):(\d{2})(?::(\d{2}))?')
      .firstMatch(raw);
  if (german != null) {
    return DateTime(
      int.parse(german.group(3)!),
      int.parse(german.group(2)!),
      int.parse(german.group(1)!),
      int.parse(german.group(4)!),
      int.parse(german.group(5)!),
      int.parse(german.group(6) ?? '0'),
    );
  }
  return null;
}

int _absoluteHourKey(DateTime ts) {
  // Encode (year, dayOfYear, hour) into a single int so `key % 24` returns
  // the hour and `key ~/ 24` returns a stable day identifier.
  final doy = ts.difference(DateTime(ts.year, 1, 1)).inDays + 1;
  return ((ts.year * 400) + doy) * 24 + ts.hour;
}

double? _parseNumber(String s) {
  var raw = s.trim();
  if (raw.isEmpty) return null;
  raw = raw.replaceAll(' ', '');
  // Handle German decimal comma vs. US thousands separator.
  if (raw.contains(',') && !raw.contains('.')) {
    raw = raw.replaceAll(',', '.');
  } else if (raw.contains(',') && raw.contains('.')) {
    // Assume `,` is the thousands separator and `.` is the decimal point.
    raw = raw.replaceAll(',', '');
  }
  return double.tryParse(raw);
}

String _cell(List<String> cells, int idx) {
  if (idx < 0 || idx >= cells.length) return '';
  return cells[idx];
}

int _occurrences(String haystack, String needle) {
  var count = 0;
  var i = 0;
  while (true) {
    final next = haystack.indexOf(needle, i);
    if (next == -1) return count;
    count++;
    i = next + 1;
  }
}

List<String> _splitCsvRow(String line, String delimiter) {
  // Minimal RFC-4180-ish splitter: handles `"`-quoted fields with `""`
  // escapes. Enough for the three target formats — they only quote when
  // a separator appears inside a value.
  final out = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        buf.write(ch);
      }
    } else {
      if (ch == '"') {
        inQuotes = true;
      } else if (ch == delimiter) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
  }
  out.add(buf.toString());
  return out;
}
