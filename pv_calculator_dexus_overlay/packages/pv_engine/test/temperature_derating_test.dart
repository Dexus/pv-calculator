import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

/// Drives the simulator with a controlled weather source so we can
/// assert temperature derating end-to-end without the synthetic
/// model's geometry getting in the way.
class _ConstantWeather extends IrradianceSource {
  const _ConstantWeather(this.sample);
  final WeatherSample sample;
  @override
  WeatherSample sampleFor(WeatherQuery query) {
    final h = query.hourOfDay;
    // Daylight band only — keep nights at zero so the simulator
    // doesn't run flat 24/7 yields.
    if (h < 6 || h > 18) return WeatherSample.empty;
    return sample;
  }
}

void main() {
  group('temperature derating', () {
    const array = PvArray(
      id: 'a', label: 'A', peakKw: 5.0, azimuthDeg: 180, tiltDeg: 35,
      inverterId: 'inv',
      temperatureCoefficientPctPerC: -0.4,
      nominalOperatingCellTempC: 45,
    );
    const inverter = Inverter(id: 'inv', label: 'Inv', maxAcKw: 10.0);

    SimulationConfig hot({IrradianceSource? source}) => SimulationConfig(
          arrays: const [array],
          inverters: const [inverter],
          loadProfile: const LoadProfile(dailyKwh: 0),
          days: 1,
          weatherSource: source ?? const _ConstantWeather(
            WeatherSample(poaWPerM2: 1000, ambientTempC: 40),
          ),
        );

    SimulationConfig cool({IrradianceSource? source}) => SimulationConfig(
          arrays: const [array],
          inverters: const [inverter],
          loadProfile: const LoadProfile(dailyKwh: 0),
          days: 1,
          weatherSource: source ?? const _ConstantWeather(
            WeatherSample(poaWPerM2: 1000, ambientTempC: 0),
          ),
        );

    test('hot day yields less than cool day at identical irradiance', () {
      final hotResult = const PvSimulator().run(hot());
      final coolResult = const PvSimulator().run(cool());
      expect(hotResult.summary.pvAcKwh, lessThan(coolResult.summary.pvAcKwh));
    });

    test('zero temperature coefficient disables derating', () {
      const flatArray = PvArray(
        id: 'a', label: 'A', peakKw: 5.0, azimuthDeg: 180, tiltDeg: 35,
        inverterId: 'inv',
        temperatureCoefficientPctPerC: 0.0,
      );
      final hotResult = const PvSimulator().run(SimulationConfig(
        arrays: const [flatArray],
        inverters: const [inverter],
        loadProfile: const LoadProfile(dailyKwh: 0),
        days: 1,
        weatherSource: _ConstantWeather(WeatherSample(poaWPerM2: 1000, ambientTempC: 40)),
      ));
      final coolResult = const PvSimulator().run(SimulationConfig(
        arrays: const [flatArray],
        inverters: const [inverter],
        loadProfile: const LoadProfile(dailyKwh: 0),
        days: 1,
        weatherSource: _ConstantWeather(WeatherSample(poaWPerM2: 1000, ambientTempC: 0)),
      ));
      expect(hotResult.summary.pvAcKwh, closeTo(coolResult.summary.pvAcKwh, 1e-9));
    });

    test('derating magnitude matches manual calculation at 1000 W/m², 25 °C ambient', () {
      // NOCT 45, ambient 25, G 1000 → Tcell = 25 + 25/800*1000 = 56.25 °C
      // Derate = 1 + (-0.4/100) * (56.25 - 25) = 1 - 0.125 = 0.875
      // One daylight hour (12:00 falls inside [6, 18]) at 5 kW peak,
      // with default 14% loss factor, AC efficiency 0.965:
      //   DC = 5 * (1000/1000) * 0.875 * 0.86 = 3.7625 kW
      //   AC = 3.7625 * 0.965 = 3.6308 kWh per daylight hour
      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [array],
        inverters: const [inverter],
        loadProfile: const LoadProfile(dailyKwh: 0),
        days: 1,
        weatherSource: _ConstantWeather(WeatherSample(poaWPerM2: 1000, ambientTempC: 25)),
      ));
      // 13 daylight hours (h ∈ [6.5, 18.5) inclusive of those whose midpoint is in [6, 18]).
      // Step midpoints are 0.5, 1.5, ..., 23.5 — those with 6 ≤ h ≤ 18 are 6.5..17.5 → 12 steps.
      // Wait: `h < 6 || h > 18` excludes anything <6 or >18, so 6.5..17.5 plus 18 boundary?
      // 18 is not > 18, so it's included. Midpoint 18.5 is > 18 → excluded.
      // Included midpoints: 6.5, 7.5, ..., 17.5 → 12 hours.
      final expectedAcPerHour = 5.0 * 0.875 * 0.86 * 0.965;
      expect(result.summary.pvAcKwh, closeTo(12 * expectedAcPerHour, 1e-6));
    });
  });
}
