import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

void main() {
  group('NoctTemperatureModel', () {
    const model = NoctTemperatureModel();

    test('matches NOCT calibration at G=800 W/m², Tamb=20 °C → Tcell == NOCT', () {
      final tcell = model.cellTemperatureC(
        const WeatherSample(poaWPerM2: 800, ambientTempC: 20),
        nominalOperatingCellTempC: 45,
      );
      expect(tcell, closeTo(45.0, 1e-9));
    });

    test('at G=0 cell temperature equals ambient', () {
      final tcell = model.cellTemperatureC(
        const WeatherSample(poaWPerM2: 0, ambientTempC: 5),
        nominalOperatingCellTempC: 45,
      );
      expect(tcell, closeTo(5.0, 1e-9));
    });

    test('rises with irradiance', () {
      final cold = model.cellTemperatureC(
        const WeatherSample(poaWPerM2: 200, ambientTempC: 25),
        nominalOperatingCellTempC: 45,
      );
      final hot = model.cellTemperatureC(
        const WeatherSample(poaWPerM2: 1000, ambientTempC: 25),
        nominalOperatingCellTempC: 45,
      );
      expect(hot, greaterThan(cold));
    });
  });

  group('FaimanTemperatureModel', () {
    test('wind lowers cell temperature', () {
      const model = FaimanTemperatureModel();
      final stillAir = model.cellTemperatureC(
        const WeatherSample(poaWPerM2: 900, ambientTempC: 25, windMS: 0),
        nominalOperatingCellTempC: 45,
      );
      final breezy = model.cellTemperatureC(
        const WeatherSample(poaWPerM2: 900, ambientTempC: 25, windMS: 8),
        nominalOperatingCellTempC: 45,
      );
      expect(breezy, lessThan(stillAir));
    });

    test('rejects negative wind by clamping to zero', () {
      const model = FaimanTemperatureModel();
      final neg = model.cellTemperatureC(
        const WeatherSample(poaWPerM2: 500, ambientTempC: 20, windMS: -5),
        nominalOperatingCellTempC: 45,
      );
      final zero = model.cellTemperatureC(
        const WeatherSample(poaWPerM2: 500, ambientTempC: 20, windMS: 0),
        nominalOperatingCellTempC: 45,
      );
      expect(neg, closeTo(zero, 1e-9));
    });
  });
}
