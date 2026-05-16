import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

class _FullSunWeather extends IrradianceSource {
  const _FullSunWeather();
  @override
  WeatherSample sampleFor(WeatherQuery query) {
    if (query.hourOfDay < 6 || query.hourOfDay > 18) return WeatherSample.empty;
    return const WeatherSample(poaWPerM2: 1000, ambientTempC: 25);
  }
}

void main() {
  group('DC input clipping (MPPT)', () {
    SimulationConfig configWith({double? maxDcInputKw, double efficiency = 1.0, double maxAcKw = 5.0}) =>
        SimulationConfig(
          arrays: const [
            // 8 kWp on a 5 kW AC inverter — DC/AC ratio 1.6.
            PvArray(
              id: 'oversized', label: 'Oversized', peakKw: 8.0,
              azimuthDeg: 180, tiltDeg: 35, inverterId: 'inv',
              lossFactor: 0.0, shadingFactor: 0.0,
            ),
          ],
          inverters: [Inverter(
            id: 'inv', label: 'Inv', maxAcKw: maxAcKw,
            efficiency: efficiency, maxDcInputKw: maxDcInputKw,
          )],
          loadProfile: const LoadProfile(dailyKwh: 0),
          days: 1,
          weatherSource: const _FullSunWeather(),
        );

    test('AC stays at the AC limit; curtailment grows when DC limit is tight', () {
      final loose = const PvSimulator().run(configWith(maxDcInputKw: 10.0));
      final tight = const PvSimulator().run(configWith(maxDcInputKw: 4.5));
      // Tight DC limit must keep AC below the (loose) reference.
      expect(tight.summary.pvAcKwh, lessThan(loose.summary.pvAcKwh));
      expect(tight.summary.curtailedKwh, greaterThan(loose.summary.curtailedKwh));
      // pvDcKwh is module output (pre-clip) and should be identical
      // between the two runs — the modules generated the same energy,
      // the inverter just couldn't ingest it all.
      expect(tight.summary.pvDcKwh, closeTo(loose.summary.pvDcKwh, 1e-9));
    });

    test('without DC limit, peak module DC reaches array peakKw', () {
      final result = const PvSimulator().run(configWith(maxDcInputKw: null));
      final peakDc = result.steps.fold<double>(0, (m, s) => s.pvDcKwh > m ? s.pvDcKwh : m);
      expect(peakDc, closeTo(8.0, 1e-6));
    });

    test('clipping happens BEFORE AC efficiency loss', () {
      // 10 kWp, eff 0.5, AC cap 100 (no AC clip), DC cap 4.
      //  - module DC per hour = 10 kWh
      //  - clip → 4 kWh feeds the inverter
      //  - eff 0.5 → 2 kWh AC
      //  - curtailment = 6 kWh per daylight hour at DC stage
      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(
            id: 'a', label: 'A', peakKw: 10.0, azimuthDeg: 180, tiltDeg: 35,
            inverterId: 'inv', lossFactor: 0.0, shadingFactor: 0.0,
          ),
        ],
        inverters: const [
          Inverter(id: 'inv', label: 'Inv', maxAcKw: 100.0, efficiency: 0.5, maxDcInputKw: 4.0),
        ],
        loadProfile: const LoadProfile(dailyKwh: 0),
        days: 1,
        weatherSource: _FullSunWeather(),
      ));
      for (final s in result.steps) {
        if (s.pvAcKwh > 0) {
          // Modules still produce 10 kWh at peak.
          expect(s.pvDcKwh, closeTo(10.0, 1e-9));
          // AC reflects clipped 4 kWh * 0.5 = 2 kWh.
          expect(s.pvAcKwh, closeTo(2.0, 1e-9));
          // Curtailment = pre-AC 6 kWh per daylight hour.
          expect(s.curtailedKwh, closeTo(6.0, 1e-9));
        }
      }
    });

    test('AC efficiency loss is not double-counted as curtailment', () {
      // Without a DC cap, only the AC limit and export limit drive
      // curtailment; the eff loss must NOT show up there.
      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(
            id: 'a', label: 'A', peakKw: 3.0, azimuthDeg: 180, tiltDeg: 35,
            inverterId: 'inv', lossFactor: 0.0, shadingFactor: 0.0,
          ),
        ],
        inverters: const [
          Inverter(id: 'inv', label: 'Inv', maxAcKw: 100.0, efficiency: 0.5),
        ],
        loadProfile: const LoadProfile(dailyKwh: 0),
        days: 1,
        weatherSource: _FullSunWeather(),
      ));
      expect(result.summary.curtailedKwh, closeTo(0, 1e-9));
    });
  });

  group('Inverter.validate', () {
    test('rejects non-positive maxDcInputKw', () {
      expect(() => const Inverter(id: 'i', label: 'I', maxAcKw: 5.0, maxDcInputKw: 0).validate(),
          throwsArgumentError);
      expect(() => const Inverter(id: 'i', label: 'I', maxAcKw: 5.0, maxDcInputKw: -1).validate(),
          throwsArgumentError);
    });

    test('null maxDcInputKw is allowed and disables clipping', () {
      const Inverter(id: 'i', label: 'I', maxAcKw: 5.0).validate();
    });
  });
}
