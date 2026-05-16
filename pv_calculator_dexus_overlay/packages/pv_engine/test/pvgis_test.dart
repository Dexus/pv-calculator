import 'dart:convert';

import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

void main() {
  group('parsePvgisHourlyJson', () {
    test('parses a minimal seriescalc document', () {
      final json = jsonEncode({
        'inputs': {
          'location': {'latitude': 50.1, 'longitude': 7.0}
        },
        'outputs': {
          'hourly': [
            {'time': '20200101:0010', 'G(i)': 0.0, 'T2m': 2.5, 'WS10m': 3.2, 'P': 0.0},
            {'time': '20200101:1210', 'G(i)': 750.0, 'T2m': 8.1, 'WS10m': 4.0, 'P': 2400.0},
          ]
        }
      });
      final data = parsePvgisHourlyJson(json);
      expect(data.entries, hasLength(2));
      expect(data.latitudeDeg, closeTo(50.1, 1e-9));
      expect(data.longitudeDeg, closeTo(7.0, 1e-9));
      expect(data.entries[0].timestampUtc, DateTime.utc(2020, 1, 1, 0, 10));
      expect(data.entries[0].poaIrradianceWPerM2, 0);
      expect(data.entries[1].poaIrradianceWPerM2, 750);
      expect(data.entries[1].ambientTempC, 8.1);
      expect(data.entries[1].windMS, 4.0);
      expect(data.entries[1].pvPowerW, 2400);
    });

    test('also accepts ISO-8601 timestamps', () {
      final json = jsonEncode({
        'outputs': {
          'hourly': [
            {'time': '2020-06-21T12:00:00Z', 'G(i)': 900.0, 'T2m': 28.0, 'WS10m': 2.0},
          ]
        }
      });
      final data = parsePvgisHourlyJson(json);
      expect(data.entries.single.timestampUtc, DateTime.utc(2020, 6, 21, 12));
    });

    test('rejects documents missing outputs.hourly', () {
      expect(() => parsePvgisHourlyJson('{"outputs": {}}'), throwsFormatException);
      expect(() => parsePvgisHourlyJson('{"inputs": {}}'), throwsFormatException);
    });

    test('rejects entries with missing irradiance', () {
      final json = jsonEncode({
        'outputs': {
          'hourly': [
            {'time': '20200101:0010', 'T2m': 2.5}
          ]
        }
      });
      expect(() => parsePvgisHourlyJson(json), throwsFormatException);
    });

    test('rejects unparseable timestamps', () {
      final json = jsonEncode({
        'outputs': {
          'hourly': [
            {'time': 'yesterday', 'G(i)': 0.0, 'T2m': 0.0}
          ]
        }
      });
      expect(() => parsePvgisHourlyJson(json), throwsFormatException);
    });

    test('rejects non-JSON input', () {
      expect(() => parsePvgisHourlyJson('not json'), throwsFormatException);
    });
  });

  group('PvgisHourlyData.toAveragedYear', () {
    test('produces 8760 samples and averages across years', () {
      final entries = <PvgisHourlyEntry>[
        // Same slot (Jan 1 12:00) across two years with different irradiance.
        PvgisHourlyEntry(
          timestampUtc: DateTime.utc(2020, 1, 1, 12),
          poaIrradianceWPerM2: 100, ambientTempC: 5, windMS: 2,
        ),
        PvgisHourlyEntry(
          timestampUtc: DateTime.utc(2021, 1, 1, 12),
          poaIrradianceWPerM2: 200, ambientTempC: 7, windMS: 4,
        ),
      ];
      final data = PvgisHourlyData(entries: entries, latitudeDeg: 0, longitudeDeg: 0);
      final tmy = data.toAveragedYear();
      expect(tmy, hasLength(8760));
      // Slot for Jan 1 hour 12 is index 12 (day 1 → offset 0).
      expect(tmy[12].poaWPerM2, closeTo(150, 1e-9));
      expect(tmy[12].ambientTempC, closeTo(6, 1e-9));
      expect(tmy[12].windMS, closeTo(3, 1e-9));
      // Unfilled slots fall back to empty.
      expect(tmy[0].poaWPerM2, 0);
    });

    test('discards Feb 29 to map cleanly onto a 365-day year', () {
      final entries = <PvgisHourlyEntry>[
        PvgisHourlyEntry(
          timestampUtc: DateTime.utc(2020, 2, 29, 12),
          poaIrradianceWPerM2: 999, ambientTempC: 0, windMS: 0,
        ),
        PvgisHourlyEntry(
          timestampUtc: DateTime.utc(2020, 3, 1, 12),
          poaIrradianceWPerM2: 500, ambientTempC: 0, windMS: 0,
        ),
      ];
      final tmy = PvgisHourlyData(entries: entries, latitudeDeg: 0, longitudeDeg: 0)
          .toAveragedYear();
      // March 1 in non-leap-year is dayOfYear 60 → slot (60-1)*24 + 12 = 1428.
      expect(tmy[1428].poaWPerM2, closeTo(500, 1e-9));
      // Feb 29 (would be dayOfYear 60 in leap year) must NOT have replaced it.
      // Search the whole array for the 999 sentinel — it should be absent.
      expect(tmy.any((s) => s.poaWPerM2 == 999), isFalse);
    });
  });

  group('PVGIS → simulator pipeline', () {
    test('parses JSON → averages to TMY → drives simulation deterministically', () {
      // One PVGIS entry covering Jan 1 12:00 over two years with different
      // irradiance. The TMY averaging should give the simulator exactly the
      // mean of the two — and the engine should produce a single
      // non-zero step at that slot.
      final json = jsonEncode({
        'inputs': {
          'location': {'latitude': 50.0, 'longitude': 7.0}
        },
        'outputs': {
          'hourly': [
            {'time': '20200101:1210', 'G(i)': 600.0, 'T2m': 5.0, 'WS10m': 2.0},
            {'time': '20210101:1210', 'G(i)': 400.0, 'T2m': 9.0, 'WS10m': 4.0},
          ]
        }
      });
      final data = parsePvgisHourlyJson(json);
      final tmy = data.toAveragedYear();
      // Slot 12 is Jan 1 hour 12.
      expect(tmy[12].poaWPerM2, closeTo(500, 1e-9));
      expect(tmy[12].ambientTempC, closeTo(7, 1e-9));

      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(
            id: 'roof', label: 'Roof', peakKw: 2.0, azimuthDeg: 180, tiltDeg: 35,
            inverterId: 'inv',
            lossFactor: 0.0, shadingFactor: 0.0,
          ),
        ],
        inverters: const [Inverter(id: 'inv', label: 'Inv', maxAcKw: 5.0, efficiency: 1.0)],
        loadProfile: const LoadProfile(dailyKwh: 0),
        startDayOfYear: 1,
        days: 1,
        weatherSource: HourlyWeatherSeries({}),
      ).copyWithSeries(HourlyWeatherSeries({'roof': tmy})));

      // Default tempCoeff = 0 → no derating; expected step AC = 2 * 0.5 = 1 kWh
      // at slot 12, zero elsewhere.
      final nonZero = result.steps.where((s) => s.pvAcKwh > 0).toList();
      expect(nonZero, hasLength(1));
      expect(nonZero.first.pvAcKwh, closeTo(1.0, 1e-6));
    });
  });

  group('HourlyWeatherSeries integration', () {
    test('drives the simulator when supplied as weatherSource', () {
      // Build a 8760-sample series where one hour has 1000 W/m² and the rest 0.
      final samples = List<WeatherSample>.filled(8760, WeatherSample.empty);
      // Day 172, hour 12 → slot (172-1)*24 + 12 = 4116
      samples[4116] = const WeatherSample(poaWPerM2: 1000, ambientTempC: 20);
      final series = HourlyWeatherSeries({'roof': samples});

      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(
            id: 'roof', label: 'Roof', peakKw: 4.0, azimuthDeg: 180, tiltDeg: 35,
            inverterId: 'inv', lossFactor: 0.0, shadingFactor: 0.0,
          ),
        ],
        inverters: const [Inverter(id: 'inv', label: 'Inv', maxAcKw: 5.0, efficiency: 1.0)],
        loadProfile: const LoadProfile(dailyKwh: 0),
        startDayOfYear: 172,
        days: 1,
        weatherSource: HourlyWeatherSeries({}),
      ).copyWithSeries(series));

      // Exactly one hour with non-zero output, at peakKw (no losses, eff=1).
      final nonZero = result.steps.where((s) => s.pvAcKwh > 0).toList();
      expect(nonZero, hasLength(1));
      expect(nonZero.first.pvAcKwh, closeTo(4.0, 1e-6));
      expect(nonZero.first.hourOfDay, closeTo(12.5, 0.5));
    });

    test('unknown arrayId throws by default (strict mode)', () {
      final series = HourlyWeatherSeries({
        'known': List<WeatherSample>.filled(8760, WeatherSample.empty),
      });
      expect(
        () => series.sampleFor(const WeatherQuery(
          arrayId: 'unknown',
          tiltDeg: 35, azimuthDeg: 180,
          dayOfYear: 100, hourOfDay: 12, latitudeDeg: 50,
        )),
        throwsStateError,
      );
    });

    test('allowMissing: true falls back to empty samples for unknown ids', () {
      final series = HourlyWeatherSeries(
        {'known': List<WeatherSample>.filled(8760, WeatherSample.empty)},
        allowMissing: true,
      );
      final sample = series.sampleFor(const WeatherQuery(
        arrayId: 'unknown',
        tiltDeg: 35, azimuthDeg: 180,
        dayOfYear: 100, hourOfDay: 12, latitudeDeg: 50,
      ));
      expect(sample.poaWPerM2, 0);
    });

    test('validateForArrays surfaces missing arrays before the simulator runs', () {
      final series = HourlyWeatherSeries({
        'roof': List<WeatherSample>.filled(8760, WeatherSample.empty),
      });
      // PvSimulator.run() calls validateForArrays under the hood, so
      // an array with no series fails up-front.
      expect(
        () => const PvSimulator().run(SimulationConfig(
          arrays: const [
            PvArray(id: 'roof', label: 'R', peakKw: 1, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i'),
            PvArray(id: 'balcony', label: 'B', peakKw: 1, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i'),
          ],
          inverters: const [Inverter(id: 'i', label: 'I', maxAcKw: 5)],
          loadProfile: LoadProfile(dailyKwh: 1),
          days: 1,
        ).copyWithSeries(series)),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', contains('balcony'))),
      );
    });

    test('validateForArrays passes when every array has data', () {
      final series = HourlyWeatherSeries({
        'roof': List<WeatherSample>.filled(8760, WeatherSample.empty),
        'balcony': List<WeatherSample>.filled(8760, WeatherSample.empty),
      });
      // Should not throw.
      const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(id: 'roof', label: 'R', peakKw: 1, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i'),
          PvArray(id: 'balcony', label: 'B', peakKw: 1, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i'),
        ],
        inverters: const [Inverter(id: 'i', label: 'I', maxAcKw: 5)],
        loadProfile: LoadProfile(dailyKwh: 1),
        days: 1,
      ).copyWithSeries(series));
    });

    test('rejects series of wrong length', () {
      expect(
        () => HourlyWeatherSeries({'bad': List<WeatherSample>.filled(10, WeatherSample.empty)}),
        throwsArgumentError,
      );
    });

    test('fallback source covers arrays without imported series', () {
      // One array has a real PVGIS slot, the other has no series and
      // must fall back to the synthetic model rather than throwing.
      final samples = List<WeatherSample>.filled(8760, WeatherSample.empty);
      samples[4116] = const WeatherSample(poaWPerM2: 1000, ambientTempC: 20);
      final series = HourlyWeatherSeries(
        {'roof': samples},
        fallback: const SyntheticIrradianceSource(),
      );

      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(
            id: 'roof', label: 'Roof', peakKw: 4.0, azimuthDeg: 180, tiltDeg: 35,
            inverterId: 'inv', lossFactor: 0.0, shadingFactor: 0.0,
          ),
          PvArray(
            id: 'balcony', label: 'Balcony', peakKw: 0.4, azimuthDeg: 180, tiltDeg: 30,
            inverterId: 'inv', lossFactor: 0.0, shadingFactor: 0.0,
          ),
        ],
        inverters: const [Inverter(id: 'inv', label: 'Inv', maxAcKw: 5.0, efficiency: 1.0)],
        loadProfile: LoadProfile(dailyKwh: 0),
        startDayOfYear: 172,
        days: 1,
        weatherSource: HourlyWeatherSeries({}),
      ).copyWithSeries(series));

      // PVGIS slot still produces full 4 kWh at peak; synthetic delivers
      // continuous yield for the balcony array across the day.
      final pvgisStep = result.steps.firstWhere((s) => s.hourOfDay > 12 && s.hourOfDay < 13);
      expect(pvgisStep.pvAcKwh, greaterThan(4.0));
      // Synthetic balcony alone produces > 0 over the whole day.
      final balconyOnly = result.summary.pvAcKwh;
      expect(balconyOnly, greaterThan(4.0));
    });

    test('chained HourlyWeatherSeries validate only the ids they each cover', () {
      // Primary covers 'roof'; fallback covers 'balcony'. Together they
      // cover both arrays — neither alone does. validateForArrays must
      // not ask the fallback about 'roof' (which it doesn't have).
      final primary = HourlyWeatherSeries(
        {'roof': List<WeatherSample>.filled(8760, WeatherSample.empty)},
        fallback: HourlyWeatherSeries({
          'balcony': List<WeatherSample>.filled(8760, WeatherSample.empty),
        }),
      );
      // Should not throw.
      primary.validateForArrays(const ['roof', 'balcony']);
      // But a truly missing id still surfaces from the keyed fallback.
      expect(
        () => primary.validateForArrays(const ['roof', 'balcony', 'shed']),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', contains('shed'))),
      );
    });

    test('fallback skips the missing-array check', () {
      final series = HourlyWeatherSeries(
        {'roof': List<WeatherSample>.filled(8760, WeatherSample.empty)},
        fallback: const SyntheticIrradianceSource(),
      );
      // Should not throw even though 'balcony' has no imported series.
      const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(id: 'roof', label: 'R', peakKw: 1, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i'),
          PvArray(id: 'balcony', label: 'B', peakKw: 1, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i'),
        ],
        inverters: const [Inverter(id: 'i', label: 'I', maxAcKw: 5)],
        loadProfile: LoadProfile(dailyKwh: 1),
        days: 1,
      ).copyWithSeries(series));
    });
  });
}

extension on SimulationConfig {
  // Test-only helper: rebuild a config with a different weatherSource.
  // Kept out of the engine API; the engine itself never mutates configs.
  SimulationConfig copyWithSeries(IrradianceSource source) => SimulationConfig(
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
        weatherSource: source,
        temperatureModel: temperatureModel,
      );
}
