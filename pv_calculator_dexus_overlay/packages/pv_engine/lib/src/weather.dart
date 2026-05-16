import 'dart:math' as math;

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
    final hour = query.hourOfDay.floor().clamp(0, 23).toInt();
    return series[day * 24 + hour];
  }
}
