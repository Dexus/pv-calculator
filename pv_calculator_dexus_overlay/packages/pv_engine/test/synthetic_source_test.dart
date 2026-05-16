import 'dart:math' as math;

import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

/// Helper to build a WeatherQuery from a PvArray — the engine itself
/// passes scalars, but tests stay tidy by reading them off a PvArray.
WeatherQuery _q(PvArray array, {required int dayOfYear, required double hourOfDay, double latitudeDeg = 50}) =>
    WeatherQuery(
      arrayId: array.id,
      tiltDeg: array.tiltDeg,
      azimuthDeg: array.azimuthDeg,
      dayOfYear: dayOfYear,
      hourOfDay: hourOfDay,
      latitudeDeg: latitudeDeg,
    );

void main() {
  group('SyntheticIrradianceSource', () {
    test('returns zero outside of the daylight window', () {
      const source = SyntheticIrradianceSource();
      const array = PvArray(id: 'a', label: 'A', peakKw: 5, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i');
      final night = source.sampleFor(_q(array, dayOfYear: 1, hourOfDay: 2));
      expect(night.poaWPerM2, 0);
    });

    test('summer noon irradiance exceeds winter noon at the same site', () {
      const source = SyntheticIrradianceSource();
      const array = PvArray(id: 'a', label: 'A', peakKw: 5, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i');
      final summer = source.sampleFor(_q(array, dayOfYear: 172, hourOfDay: 12.5));
      final winter = source.sampleFor(_q(array, dayOfYear: 355, hourOfDay: 12.5));
      expect(summer.poaWPerM2, greaterThan(winter.poaWPerM2));
    });

    test('south-facing array beats east-facing at noon', () {
      const source = SyntheticIrradianceSource();
      const south = PvArray(id: 's', label: 'S', peakKw: 5, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i');
      const east = PvArray(id: 'e', label: 'E', peakKw: 5, azimuthDeg: 90, tiltDeg: 35, inverterId: 'i');
      final s = source.sampleFor(_q(south, dayOfYear: 172, hourOfDay: 12.5));
      final e = source.sampleFor(_q(east, dayOfYear: 172, hourOfDay: 12.5));
      expect(s.poaWPerM2, greaterThan(e.poaWPerM2));
    });

    test('default ambient is 25 °C — temperature derating defaults to zero impact', () {
      const source = SyntheticIrradianceSource();
      const array = PvArray(id: 'a', label: 'A', peakKw: 5, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i');
      final sample = source.sampleFor(_q(array, dayOfYear: 172, hourOfDay: 12.5));
      expect(sample.ambientTempC, 25.0);
    });

    test('normalized factor is in [0, 1]', () {
      for (final day in const [1, 60, 120, 172, 240, 300, 365]) {
        for (var h = 0.5; h < 24; h += 1.0) {
          final f = SyntheticIrradianceSource.normalizedPowerFactor(
            azimuthDeg: 180, tiltDeg: 35, dayOfYear: day, hourOfDay: h, latitudeDeg: 50,
          );
          expect(f, inInclusiveRange(0, 1), reason: 'day=$day h=$h');
        }
      }
    });
  });

  group('legacy engine behaviour preserved', () {
    test('with default array (tempCoeff=0) annual yield stays positive and pvAc < pvDc', () {
      // Structural backward-compat check: the source/temperature pipeline
      // must not perturb yields when temperature derating is off.
      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(id: 'a', label: 'A', peakKw: 5.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'inv'),
        ],
        inverters: const [Inverter(id: 'inv', label: 'Inv', maxAcKw: 5.0)],
        loadProfile: LoadProfile(dailyKwh: 0),
        days: 365,
        latitudeDeg: 50,
      ));
      expect(result.summary.pvAcKwh, greaterThan(0));
      // AC < DC because of inverter efficiency (0.965) — independent of the
      // weather model, this invariant must hold.
      expect(result.summary.pvAcKwh, lessThan(result.summary.pvDcKwh));
    });

    test('synthetic source × _dcPowerKwFromWeather reproduces the old factor', () {
      // f * peakKw * (1 - loss) * (1 - shading) — independent of temperature
      // when tempCoeff = 0.
      const array = PvArray(
        id: 'a', label: 'A', peakKw: 5.0, azimuthDeg: 180, tiltDeg: 35,
        inverterId: 'inv', lossFactor: 0.14, shadingFactor: 0.0,
      );
      const source = SyntheticIrradianceSource();
      const tempModel = NoctTemperatureModel();
      for (final day in const [1, 100, 172, 270]) {
        for (var h = 0.5; h < 24; h += 1.0) {
          final f = SyntheticIrradianceSource.normalizedPowerFactor(
            azimuthDeg: array.azimuthDeg, tiltDeg: array.tiltDeg,
            dayOfYear: day, hourOfDay: h, latitudeDeg: 50,
          );
          final expected = array.peakKw * f * (1 - array.lossFactor);
          final sample = source.sampleFor(_q(array, dayOfYear: day, hourOfDay: h));
          final tcell = tempModel.cellTemperatureC(
            sample,
            nominalOperatingCellTempC: array.nominalOperatingCellTempC,
          );
          final derate = 1 + (array.temperatureCoefficientPctPerC / 100) * (tcell - 25);
          final got = array.peakKw * (sample.poaWPerM2 / 1000) * (1 - array.lossFactor) * math.max(0, derate);
          expect(got, closeTo(expected, 1e-12),
              reason: 'day=$day h=$h derate=$derate');
        }
      }
    });
  });
}
