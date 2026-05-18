import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

/// Phase 9 — C1: running the same config at 60-min and 15-min step widths
/// must agree on annual totals when the inputs are piecewise-constant
/// within an hour.
///
/// The synthetic POA model is continuous in `hourOfDay`, so quarter-hourly
/// sampling integrates the curve better than the single mid-hour sample
/// hourly stepping uses — those two are not expected to agree exactly.
/// `HourlyWeatherSeries` and `LoadProfile`, on the other hand, are
/// hourly-quantised: four 15-min steps at constant power inside one hour
/// must sum to exactly the same energy as one 60-min step.
void main() {
  group('quarter-hourly vs hourly parity (piecewise-constant inputs)', () {
    HourlyWeatherSeries buildSeries() {
      // Deterministic flat-top series: noon-centred POA up to 800 W/m².
      final samples = <WeatherSample>[];
      for (var day = 0; day < 365; day++) {
        for (var hour = 0; hour < 24; hour++) {
          final poa = (hour >= 6 && hour < 18)
              ? 800.0 * (1 - ((hour - 12).abs() / 6.0))
              : 0.0;
          samples.add(WeatherSample(poaWPerM2: poa, ambientTempC: 20));
        }
      }
      return HourlyWeatherSeries({'a': samples, 'b': samples});
    }

    SimulationConfig configWith(TimeStep timeStep) => SimulationConfig(
          arrays: const [
            PvArray(id: 'a', label: 'A', peakKw: 5.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'inv'),
            PvArray(id: 'b', label: 'B', peakKw: 3.0, azimuthDeg: 270, tiltDeg: 35, inverterId: 'inv'),
          ],
          inverters: const [Inverter(id: 'inv', label: 'Inv', maxAcKw: 6.0)],
          batteries: const [
            BatteryConfig(id: 'bat', capacityKwh: 8, maxChargeKw: 3, maxDischargeKw: 3),
          ],
          loadProfile: const LoadProfile(dailyKwh: 12),
          gridExportLimitKw: 4.0,
          startDayOfYear: 1,
          days: 7,
          timeStep: timeStep,
          weatherSource: buildSeries(),
        );

    test('summary totals over the simulated period agree within 1e-9 kWh', () {
      final hourly = const PvSimulator().run(configWith(TimeStep.hourly)).summary;
      final quarter = const PvSimulator().run(configWith(TimeStep.quarterHourly)).summary;

      expect(quarter.pvDcKwh, closeTo(hourly.pvDcKwh, 1e-9));
      expect(quarter.pvAcKwh, closeTo(hourly.pvAcKwh, 1e-9));
      expect(quarter.loadKwh, closeTo(hourly.loadKwh, 1e-9));
      expect(quarter.selfConsumptionKwh, closeTo(hourly.selfConsumptionKwh, 1e-9));
      expect(quarter.gridExportKwh, closeTo(hourly.gridExportKwh, 1e-9));
      expect(quarter.gridImportKwh, closeTo(hourly.gridImportKwh, 1e-9));
      expect(quarter.curtailedExportKwh, closeTo(hourly.curtailedExportKwh, 1e-9));
    });

    test('quarter-hourly produces 4× the steps', () {
      final hourly = const PvSimulator().run(configWith(TimeStep.hourly));
      final quarter = const PvSimulator().run(configWith(TimeStep.quarterHourly));

      expect(hourly.steps.length, 7 * 24);
      expect(quarter.steps.length, 7 * 96);
    });

    test('hourly aggregation of quarter-hourly matches hourly run', () {
      final hourly = const PvSimulator().run(configWith(TimeStep.hourly));
      final quarter = const PvSimulator().run(configWith(TimeStep.quarterHourly));

      for (var hourIdx = 0; hourIdx < hourly.steps.length; hourIdx++) {
        final h = hourly.steps[hourIdx];
        var pvAc = 0.0;
        var load = 0.0;
        for (var q = 0; q < 4; q++) {
          final qs = quarter.steps[hourIdx * 4 + q];
          pvAc += qs.pvAcKwh;
          load += qs.loadKwh;
        }
        expect(pvAc, closeTo(h.pvAcKwh, 1e-9),
            reason: 'pvAc mismatch at hour $hourIdx');
        expect(load, closeTo(h.loadKwh, 1e-9),
            reason: 'load mismatch at hour $hourIdx');
      }
    });
  });

  group('synthetic source at quarter-hourly resolution', () {
    test('summary totals stay within 5% of hourly (continuous curve integrates better)', () {
      SimulationConfig configWith(TimeStep timeStep) => SimulationConfig(
            arrays: const [
              PvArray(id: 'a', label: 'A', peakKw: 5.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'inv'),
            ],
            inverters: const [Inverter(id: 'inv', label: 'Inv', maxAcKw: 6.0)],
            loadProfile: const LoadProfile(dailyKwh: 12),
            startDayOfYear: 1,
            days: 30,
            timeStep: timeStep,
          );

      final hourly = const PvSimulator().run(configWith(TimeStep.hourly)).summary;
      final quarter = const PvSimulator().run(configWith(TimeStep.quarterHourly)).summary;

      // Quarter-hourly is the better numerical approximation; the
      // difference is bounded — verify we're in the same ballpark
      // rather than off by orders of magnitude.
      expect((quarter.pvDcKwh - hourly.pvDcKwh).abs() / hourly.pvDcKwh, lessThan(0.05));
    });
  });
}
