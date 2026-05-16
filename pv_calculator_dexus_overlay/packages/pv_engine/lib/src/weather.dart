import 'dart:math' as math;

import '../pv_engine.dart';

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
class WeatherQuery {
  const WeatherQuery({
    required this.array,
    required this.dayOfYear,
    required this.hourOfDay,
    required this.latitudeDeg,
  });

  final PvArray array;
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
      array: query.array,
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
    required PvArray array,
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
    final azimuthPenalty = ((array.azimuthDeg - 180).abs() / 180.0).clamp(0.0, 1.0).toDouble();
    final tiltPenalty = ((array.tiltDeg - 35).abs() / 90.0).clamp(0.0, 1.0).toDouble();
    final orientation = (1.0 - 0.22 * azimuthPenalty - 0.12 * tiltPenalty).clamp(0.55, 1.0).toDouble();
    return sun * season * orientation;
  }
}

/// Per-array hourly weather index built from real data (e.g. PVGIS).
///
/// Stores 365×24 samples per array id. Lookups outside the indexed
/// set fall back to [WeatherSample.empty]. The engine never extrapolates.
class HourlyWeatherSeries extends IrradianceSource {
  HourlyWeatherSeries(Map<String, List<WeatherSample>> samplesByArrayId)
      : _samplesByArrayId = {
          for (final entry in samplesByArrayId.entries)
            entry.key: _validateLength(entry.key, entry.value),
        };

  final Map<String, List<WeatherSample>> _samplesByArrayId;

  static List<WeatherSample> _validateLength(String arrayId, List<WeatherSample> samples) {
    if (samples.length != 365 * 24) {
      throw ArgumentError(
        'HourlyWeatherSeries for "$arrayId" must have ${365 * 24} samples, got ${samples.length}.',
      );
    }
    return List<WeatherSample>.unmodifiable(samples);
  }

  Iterable<String> get arrayIds => _samplesByArrayId.keys;

  @override
  WeatherSample sampleFor(WeatherQuery query) {
    final series = _samplesByArrayId[query.array.id];
    if (series == null) return WeatherSample.empty;
    final day = (query.dayOfYear - 1).clamp(0, 364);
    final hour = query.hourOfDay.floor().clamp(0, 23);
    return series[day * 24 + hour];
  }
}
