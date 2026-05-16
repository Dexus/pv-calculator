import 'dart:math' as math;

import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

/// Reference-yield tests against hand-built PVGIS-shaped fixtures.
/// These do not validate the engine against PVGIS over the network
/// (none in CI). They lock the adapter + dispatch chain against
/// simple, hand-computable scenarios so accidental regressions in the
/// temperature / loss / clipping pipeline get caught.
void main() {
  group('clear-day yield', () {
    test('1 kWp south-facing in central Germany on June 21 lands in 4–7 kWh', () {
      final series = _clearSummerDaySeries(
        dayOfYear: 172, peakIrradianceWPerM2: 900, peakAmbientTempC: 25,
      );

      final deratedResult = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(
            id: 'roof', label: 'Roof', peakKw: 1.0, azimuthDeg: 180, tiltDeg: 35,
            inverterId: 'inv',
            lossFactor: 0.14,
            temperatureCoefficientPctPerC: -0.4,
            nominalOperatingCellTempC: 45,
          ),
        ],
        inverters: const [Inverter(id: 'inv', label: 'Inv', maxAcKw: 5.0)],
        loadProfile: const LoadProfile(dailyKwh: 0),
        startDayOfYear: 172,
        days: 1,
      ).withSeries({'roof': series}));

      // PVGIS-style "performance ratio ~0.78 with 14% loss factor on a
      // clear summer day at 50° N" gives roughly 5–6 kWh/kWp.
      // The envelope is wide because the synthetic cosine is not real
      // ephemeris and the irradiance peak is conservative.
      expect(deratedResult.summary.pvAcKwh, inInclusiveRange(4.0, 7.0));

      // Temperature derating must shrink yield vs a temperature-blind run.
      final blindResult = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(
            id: 'roof', label: 'Roof', peakKw: 1.0, azimuthDeg: 180, tiltDeg: 35,
            inverterId: 'inv',
            lossFactor: 0.14,
          ),
        ],
        inverters: const [Inverter(id: 'inv', label: 'Inv', maxAcKw: 5.0)],
        loadProfile: const LoadProfile(dailyKwh: 0),
        startDayOfYear: 172,
        days: 1,
      ).withSeries({'roof': series}));
      expect(deratedResult.summary.pvAcKwh, lessThan(blindResult.summary.pvAcKwh));
    });

    test('800 W micro inverter caps the array yield even on a clear day', () {
      final series = _clearSummerDaySeries(
        dayOfYear: 172, peakIrradianceWPerM2: 950, peakAmbientTempC: 22,
      );
      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(
            id: 'balcony', label: 'Balkon', peakKw: 2.0, azimuthDeg: 180, tiltDeg: 30,
            inverterId: 'micro',
          ),
        ],
        inverters: const [
          Inverter(id: 'micro', label: 'Micro', maxAcKw: 2.0, role: InverterRole.microInverter800W),
        ],
        loadProfile: const LoadProfile(dailyKwh: 0),
        startDayOfYear: 172,
        days: 1,
      ).withSeries({'balcony': series}));
      for (final s in result.steps) {
        expect(s.pvAcKwh, lessThanOrEqualTo(0.8 + 1e-9));
      }
      // Curtailment must be non-trivial when 2 kWp peaks behind 800 W AC.
      expect(result.summary.curtailedKwh, greaterThan(0));
    });
  });

  group('zero-irradiance overcast day', () {
    test('produces no AC yield', () {
      final overcast = List<WeatherSample>.filled(
        8760,
        const WeatherSample(poaWPerM2: 0, ambientTempC: 4, windMS: 3),
      );
      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(id: 'roof', label: 'Roof', peakKw: 5.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'inv'),
        ],
        inverters: const [Inverter(id: 'inv', label: 'Inv', maxAcKw: 5.0)],
        loadProfile: const LoadProfile(dailyKwh: 5.0),
        days: 1,
      ).withSeries({'roof': overcast}));
      expect(result.summary.pvAcKwh, 0);
      // Load has to come fully from the grid.
      expect(result.summary.gridImportKwh, closeTo(5.0, 1e-6));
    });
  });
}

/// Build an 8760-sample series with one realistic daylight curve on
/// `dayOfYear` and zeros elsewhere.
List<WeatherSample> _clearSummerDaySeries({
  required int dayOfYear,
  required double peakIrradianceWPerM2,
  required double peakAmbientTempC,
}) {
  final series = List<WeatherSample>.filled(8760, WeatherSample.empty);
  const sunrise = 5;
  const sunset = 19;
  for (var h = 0; h < 24; h++) {
    final inDay = h >= sunrise && h < sunset;
    if (!inDay) continue;
    final f = math.sin(math.pi * (h + 0.5 - sunrise) / (sunset - sunrise)).clamp(0.0, 1.0);
    final poa = peakIrradianceWPerM2 * f;
    final tempF = math.sin(math.pi * (h - 4) / 24).clamp(0.0, 1.0);
    final temp = peakAmbientTempC - 8 + 16 * tempF;
    final slot = (dayOfYear - 1) * 24 + h;
    series[slot] = WeatherSample(poaWPerM2: poa, ambientTempC: temp, windMS: 2);
  }
  return series;
}

extension on SimulationConfig {
  SimulationConfig withSeries(Map<String, List<WeatherSample>> samplesByArrayId) =>
      SimulationConfig(
        arrays: arrays,
        inverters: inverters,
        loadProfile: loadProfile,
        batteries: batteries,
        startDayOfYear: startDayOfYear,
        days: days,
        timeStep: timeStep,
        preRunDays: preRunDays,
        gridExportLimitKw: gridExportLimitKw,
        latitudeDeg: latitudeDeg,
        weatherSource: HourlyWeatherSeries(samplesByArrayId),
        temperatureModel: temperatureModel,
      );
}
