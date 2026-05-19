import 'dart:math' as math;

import 'transposition.dart';

/// Plane-of-array weather sample at one instant for one array.
///
/// `poaWPerM2` is irradiance on the tilted module plane in W/m². At
/// 1000 W/m² and cell temperature 25 °C the module produces its
/// nameplate `peakKw` (before system losses). `ambientTempC` and
/// `windMS` drive the temperature model.
class WeatherSample {
  const WeatherSample({
    required this.poaWPerM2,
    required this.ambientTempC,
    this.windMS = 1.0,
  });

  final double poaWPerM2;
  final double ambientTempC;
  final double windMS;

  static const empty = WeatherSample(poaWPerM2: 0, ambientTempC: 25, windMS: 1);
}

/// Query passed to an [IrradianceSource] for one (array, instant) pair.
///
/// Carries only the scalar fields a source needs — array id (so series
/// can index per array) plus the orientation needed by geometry-aware
/// sources. Keeping `PvArray` out of this file prevents an import
/// cycle with the rest of the engine.
class WeatherQuery {
  const WeatherQuery({
    required this.arrayId,
    required this.tiltDeg,
    required this.azimuthDeg,
    required this.dayOfYear,
    required this.hourOfDay,
    required this.latitudeDeg,
  });

  final String arrayId;
  final double tiltDeg;
  final double azimuthDeg;
  final int dayOfYear;
  final double hourOfDay;
  final double latitudeDeg;
}

/// Strategy that returns weather data for a given array and time.
///
/// Implementations are stateless from the engine's point of view —
/// the simulator may call [sampleFor] many times per array per year.
abstract class IrradianceSource {
  const IrradianceSource();
  WeatherSample sampleFor(WeatherQuery query);

  /// Called once by [PvSimulator.run] before any step is simulated.
  /// Sources that are keyed by array id (e.g. [HourlyWeatherSeries])
  /// can use this to fail loudly when an array has no associated
  /// data, instead of silently returning zero production. Default
  /// implementation is a no-op for sources that work for every array
  /// (e.g. [SyntheticIrradianceSource]).
  void validateForArrays(Iterable<String> arrayIds) {}
}

/// Synthetic fallback model. Reproduces the engine's original
/// sin/season/orientation factor and exposes it as a POA irradiance
/// in [0, 1000] W/m², with a flat 25 °C ambient so users that don't
/// opt into temperature derating see the same numbers as before.
///
/// Clearly labelled as a demo source — not validated against any
/// real measurement.
class SyntheticIrradianceSource extends IrradianceSource {
  const SyntheticIrradianceSource({
    this.ambientTempC = 25.0,
    this.windMS = 1.0,
  });

  final double ambientTempC;
  final double windMS;

  @override
  WeatherSample sampleFor(WeatherQuery query) {
    final f = normalizedPowerFactor(
      azimuthDeg: query.azimuthDeg,
      tiltDeg: query.tiltDeg,
      dayOfYear: query.dayOfYear,
      hourOfDay: query.hourOfDay,
      latitudeDeg: query.latitudeDeg,
    );
    return WeatherSample(
      poaWPerM2: f * 1000.0,
      ambientTempC: ambientTempC,
      windMS: windMS,
    );
  }

  /// Pure factor in [0, 1] folding day length, season, azimuth and
  /// tilt penalties. Exposed so tests and adapters can reuse the
  /// same shape without re-deriving it.
  static double normalizedPowerFactor({
    required double azimuthDeg,
    required double tiltDeg,
    required int dayOfYear,
    required double hourOfDay,
    required double latitudeDeg,
  }) {
    final latitudeImpact = (latitudeDeg.abs() / 90.0).clamp(0.0, 1.0).toDouble();
    final dayLength = (12.0 + 4.0 * latitudeImpact * math.cos(2 * math.pi * (dayOfYear - 172) / 365.0))
        .clamp(7.0, 17.0)
        .toDouble();
    final sunrise = 12.0 - dayLength / 2.0;
    final sunset = 12.0 + dayLength / 2.0;
    if (hourOfDay < sunrise || hourOfDay > sunset) return 0;
    final sun = math.sin(math.pi * (hourOfDay - sunrise) / dayLength).clamp(0.0, 1.0).toDouble();
    final season = (0.72 + 0.28 * math.cos(2 * math.pi * (dayOfYear - 172) / 365.0)).clamp(0.25, 1.0).toDouble();
    final azimuthPenalty = ((azimuthDeg - 180).abs() / 180.0).clamp(0.0, 1.0).toDouble();
    final tiltPenalty = ((tiltDeg - 35).abs() / 90.0).clamp(0.0, 1.0).toDouble();
    final orientation = (1.0 - 0.22 * azimuthPenalty - 0.12 * tiltPenalty).clamp(0.55, 1.0).toDouble();
    return sun * season * orientation;
  }
}

/// Per-array hourly weather index built from real data (e.g. PVGIS).
///
/// Stores 365×24 samples per array id. By default this source is
/// **strict**: looking up an array id that has no series raises a
/// [StateError] so a typo or a missing import doesn't silently turn
/// into zero production for a whole array. Pass `allowMissing: true`
/// only when you deliberately want unknown ids to fall back to
/// [WeatherSample.empty]. Alternatively pass [fallback] to delegate
/// unknown ids to another [IrradianceSource] (e.g. the synthetic demo
/// model) — this enables hybrid setups where only some arrays have
/// imported PVGIS data.
class HourlyWeatherSeries extends IrradianceSource {
  HourlyWeatherSeries(
    Map<String, List<WeatherSample>> samplesByArrayId, {
    this.allowMissing = false,
    this.fallback,
  }) : _samplesByArrayId = {
          for (final entry in samplesByArrayId.entries)
            entry.key: _validateLength(entry.key, entry.value),
        };

  final Map<String, List<WeatherSample>> _samplesByArrayId;

  /// When `true`, unknown array ids resolve to [WeatherSample.empty]
  /// instead of throwing. Off by default — silent zeros are the kind
  /// of bug that's hard to spot in summary metrics. Ignored when
  /// [fallback] is set.
  final bool allowMissing;

  /// Optional delegate for arrays without their own series. When set,
  /// unknown ids are routed to this source and [validateForArrays]
  /// stops complaining about missing arrays. Useful for hybrid setups
  /// where the UI has only imported PVGIS data for some arrays and
  /// the rest should keep using the synthetic demo model.
  final IrradianceSource? fallback;

  static List<WeatherSample> _validateLength(String arrayId, List<WeatherSample> samples) {
    if (samples.length != 365 * 24) {
      throw ArgumentError(
        'HourlyWeatherSeries for "$arrayId" must have ${365 * 24} samples, got ${samples.length}.',
      );
    }
    return List<WeatherSample>.unmodifiable(samples);
  }

  Iterable<String> get arrayIds => _samplesByArrayId.keys;

  /// Returns the set of array ids in [requiredArrayIds] that have no
  /// series here. Useful for callers that want to surface missing
  /// data to the user without triggering a thrown `StateError`.
  Set<String> missingArrayIds(Iterable<String> requiredArrayIds) {
    return {
      for (final id in requiredArrayIds)
        if (!_samplesByArrayId.containsKey(id)) id,
    };
  }

  @override
  void validateForArrays(Iterable<String> arrayIds) {
    if (fallback != null) {
      // Only the ids this series doesn't cover get delegated. Asking
      // the fallback to validate ids we already serve would force any
      // keyed fallback (e.g. another HourlyWeatherSeries) to also have
      // them — defeating the point of layering sources.
      final missing = missingArrayIds(arrayIds);
      if (missing.isNotEmpty) fallback!.validateForArrays(missing);
      return;
    }
    if (allowMissing) return;
    final missing = missingArrayIds(arrayIds);
    if (missing.isNotEmpty) {
      throw ArgumentError(
        'HourlyWeatherSeries is missing data for arrays: '
        '${(missing.toList()..sort()).join(", ")}. '
        'Provide a series for each array, or pass `allowMissing: true` '
        'if zero production is intentional.',
      );
    }
  }

  @override
  WeatherSample sampleFor(WeatherQuery query) {
    final series = _samplesByArrayId[query.arrayId];
    if (series == null) {
      final delegate = fallback;
      if (delegate != null) return delegate.sampleFor(query);
      if (allowMissing) return WeatherSample.empty;
      throw StateError(
        'HourlyWeatherSeries has no data for array "${query.arrayId}". '
        'Provide a series for it or construct the source with '
        '`allowMissing: true` if zero production is intentional.',
      );
    }
    // `num.clamp` is statically typed `num`, so cast back to `int`
    // before computing the list index.
    final day = (query.dayOfYear - 1).clamp(0, 364).toInt();
    // At `TimeStep.quarterHourly` the simulator queries the same hour
    // four times (0.125 h, 0.375 h, 0.625 h, 0.875 h all floor to the
    // same hour index). Returning the same sample for each quarter is
    // energy-conserving because the simulator multiplies the resulting
    // POA power by `stepHours` — four 15-min steps at constant power
    // P deliver the same kWh as one 60-min step at P.
    final hour = query.hourOfDay.floor().clamp(0, 23).toInt();
    return series[day * 24 + hour];
  }
}

/// One hour of horizontal-plane irradiance + ambient conditions at a site.
///
/// "Horizontal" means the global and diffuse components are measured on a
/// flat surface (`angle=0` in PVGIS terms). The per-array plane-of-array
/// irradiance is derived later by [transposeToPoa]; storing horizontal
/// values lets one PVGIS fetch per site cover any number of arrays.
class HorizontalIrradianceSample {
  const HorizontalIrradianceSample({
    required this.globalHorizontalWPerM2,
    required this.diffuseHorizontalWPerM2,
    required this.ambientTempC,
    this.windMS = 1.0,
  });

  /// Global horizontal irradiance (W/m²). Sum of beam, diffuse and any
  /// reflected components on a flat surface.
  final double globalHorizontalWPerM2;

  /// Diffuse horizontal irradiance (W/m²). Sky-diffuse component only.
  final double diffuseHorizontalWPerM2;

  final double ambientTempC;
  final double windMS;

  static const empty = HorizontalIrradianceSample(
    globalHorizontalWPerM2: 0,
    diffuseHorizontalWPerM2: 0,
    ambientTempC: 25,
    windMS: 1,
  );
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.parse(value);
  throw FormatException('Expected num, got ${value.runtimeType}');
}

/// 365×24 horizontal-irradiance samples for one site/year, plus the
/// site metadata needed to drive transposition.
///
/// Built once per project from a single PVGIS `seriescalc&components=1`
/// fetch (see `parsePvgisHorizontalSeries`). Reused across every array
/// on the site — no per-array network call.
class HorizontalIrradianceSeries {
  HorizontalIrradianceSeries({
    required List<HorizontalIrradianceSample> samples,
    required this.year,
    required this.latitudeDeg,
    required this.longitudeDeg,
    this.radDatabase,
  }) : samples = _validateLength(samples);

  /// 365×24 hourly samples, indexed `(dayOfYear-1) * 24 + hourOfDay`.
  /// Leap days are dropped during parsing so this always has exactly
  /// 8760 entries.
  final List<HorizontalIrradianceSample> samples;

  /// Calendar year the data was sampled from (single-year only; multi-year
  /// averaging is not part of this iteration).
  final int year;

  final double latitudeDeg;
  final double longitudeDeg;

  /// Optional radiation database label (e.g. `PVGIS-SARAH3`, `PVGIS-ERA5`).
  /// Useful for showing provenance in the UI; never required by the engine.
  final String? radDatabase;

  static List<HorizontalIrradianceSample> _validateLength(
    List<HorizontalIrradianceSample> samples,
  ) {
    if (samples.length != 365 * 24) {
      throw ArgumentError(
        'HorizontalIrradianceSeries must have ${365 * 24} samples, '
        'got ${samples.length}.',
      );
    }
    return List<HorizontalIrradianceSample>.unmodifiable(samples);
  }

  /// Returns the sample for the given day-of-year (1..365) and
  /// hour-of-day (0..23, integer-floored). At sub-hourly step widths
  /// the same sample is returned for every sub-step inside one hour;
  /// see [HourlyWeatherSeries.sampleFor] for the energy-conservation
  /// argument.
  HorizontalIrradianceSample sampleAt({required int dayOfYear, required double hourOfDay}) {
    final day = (dayOfYear - 1).clamp(0, 364).toInt();
    final hour = hourOfDay.floor().clamp(0, 23).toInt();
    return samples[day * 24 + hour];
  }

  /// Sum of GHI over the year in kWh/m². Hourly samples are W/m², so each
  /// equals 1 Wh/m²·h → divide by 1000 for kWh.
  double get annualGlobalKWhPerM2 {
    var total = 0.0;
    for (final s in samples) {
      total += s.globalHorizontalWPerM2;
    }
    return total / 1000.0;
  }

  /// Mean GHI over the year in W/m².
  double get meanGlobalWPerM2 {
    var total = 0.0;
    for (final s in samples) {
      total += s.globalHorizontalWPerM2;
    }
    return total / samples.length;
  }

  /// Serialises the full series — metadata plus all 8760 samples — into a
  /// JSON-encodable map. Samples are packed as a flat `List<double>` of
  /// length `8760 * 4` in `[ghi, dhi, t, wind]` order to keep the payload
  /// compact (the per-object form would add ~3× key overhead).
  Map<String, dynamic> toJson() {
    final packed = List<double>.filled(samples.length * 4, 0.0);
    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];
      final base = i * 4;
      packed[base] = s.globalHorizontalWPerM2;
      packed[base + 1] = s.diffuseHorizontalWPerM2;
      packed[base + 2] = s.ambientTempC;
      packed[base + 3] = s.windMS;
    }
    return {
      'version': 1,
      'year': year,
      'latitudeDeg': latitudeDeg,
      'longitudeDeg': longitudeDeg,
      if (radDatabase != null) 'radDatabase': radDatabase,
      'samples': packed,
    };
  }

  /// Inverse of [toJson]. Throws [FormatException] when the payload is
  /// shaped wrong, has the wrong number of samples, or carries a
  /// version this build does not know how to read.
  factory HorizontalIrradianceSeries.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version != null && version != 1) {
      throw FormatException(
        'HorizontalIrradianceSeries: unsupported version $version',
      );
    }
    final raw = json['samples'];
    if (raw is! List) {
      throw const FormatException('samples must be a list');
    }
    if (raw.length != 365 * 24 * 4) {
      throw FormatException(
        'samples list must have ${365 * 24 * 4} entries, got ${raw.length}',
      );
    }
    final out = List<HorizontalIrradianceSample>.generate(365 * 24, (i) {
      final base = i * 4;
      return HorizontalIrradianceSample(
        globalHorizontalWPerM2: _toDouble(raw[base]),
        diffuseHorizontalWPerM2: _toDouble(raw[base + 1]),
        ambientTempC: _toDouble(raw[base + 2]),
        windMS: _toDouble(raw[base + 3]),
      );
    });
    return HorizontalIrradianceSeries(
      samples: out,
      year: (json['year'] as num).toInt(),
      latitudeDeg: _toDouble(json['latitudeDeg']),
      longitudeDeg: _toDouble(json['longitudeDeg']),
      radDatabase: json['radDatabase'] as String?,
    );
  }
}

/// [IrradianceSource] that derives per-array POA on the fly from one
/// site-level [HorizontalIrradianceSeries] by applying [transposeToPoa]
/// for each array's tilt + azimuth.
///
/// Within a single simulation step the engine queries every array at the
/// **same** `(dayOfYear, hourOfDay)` instant; the solar zenith + azimuth
/// depend only on that instant (plus latitude/longitude), so this source
/// caches the derived [SolarPosition] keyed by the exact minute of the
/// year. Sub-hourly step widths therefore still get their own geometry
/// — the cache does not collapse 15-min queries onto the floored hour,
/// which would bias POA at sub-hourly resolution. The cache is
/// invalidated when the caller's `latitudeDeg` changes between calls.
/// Per-array trig (tilt, surface azimuth) is cheap and is still computed
/// inline.
class HorizontalToPoaSource extends IrradianceSource {
  HorizontalToPoaSource(this.series);

  final HorizontalIrradianceSeries series;

  // Keyed by `dayIdx * 1440 + minuteOfDay` so each unique simulation
  // instant gets its own geometry slot. A 15-min year touches at most
  // 365 * 96 = 35 040 keys; a 1-h year only 365 * 24 = 8 760. Map
  // lookup is fast enough at this size and avoids pre-allocating a
  // 525 600-entry list.
  final Map<int, SolarPosition> _solarCache = <int, SolarPosition>{};
  double? _cachedLatitudeDeg;

  @override
  WeatherSample sampleFor(WeatherQuery query) {
    final h = series.sampleAt(dayOfYear: query.dayOfYear, hourOfDay: query.hourOfDay);
    // Dark step: POA is zero regardless of geometry — skip both the
    // cache lookup and the trig call. transposeToPoa would short-circuit
    // anyway, but doing it here also avoids polluting the cache with
    // entries that will never be reused for any non-trivial work.
    if (h.globalHorizontalWPerM2 <= 0) {
      return WeatherSample(
        poaWPerM2: 0,
        ambientTempC: h.ambientTempC,
        windMS: h.windMS,
      );
    }
    if (_cachedLatitudeDeg != query.latitudeDeg) {
      _cachedLatitudeDeg = query.latitudeDeg;
      _solarCache.clear();
    }
    final dayIdx = (query.dayOfYear - 1).clamp(0, 364).toInt();
    final minuteOfDay = (query.hourOfDay * 60).round().clamp(0, 1439);
    final cacheKey = dayIdx * 1440 + minuteOfDay;
    final position = _solarCache[cacheKey] ??= solarPositionFor(
      latitudeDeg: query.latitudeDeg,
      // Use the series longitude to convert UTC hours to local solar time
      // before computing the hour angle; hourOfDay in WeatherQuery is UTC.
      longitudeDeg: series.longitudeDeg,
      dayOfYear: query.dayOfYear,
      hourOfDay: query.hourOfDay,
    );
    return transposeToPoa(
      h: h,
      tiltDeg: query.tiltDeg,
      azimuthDeg: query.azimuthDeg,
      latitudeDeg: query.latitudeDeg,
      longitudeDeg: series.longitudeDeg,
      dayOfYear: query.dayOfYear,
      hourOfDay: query.hourOfDay,
      solarPosition: position,
    );
  }
}
