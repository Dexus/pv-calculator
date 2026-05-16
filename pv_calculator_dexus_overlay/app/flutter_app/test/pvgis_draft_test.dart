import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_engine/pv_engine.dart';

void main() {
  group('ConfigDraft PVGIS attachment', () {
    test('build() returns null weatherSource when no series is attached', () {
      final draft = ConfigDraft.demo();
      expect(draft.buildWeatherSource(), isNull);
      expect(draft.build().weatherSource, isNull);
    });

    test('build() returns an HourlyWeatherSeries with synthetic fallback once a series is attached', () {
      final draft = ConfigDraft.demo();
      final samples = List<WeatherSample>.filled(365 * 24, WeatherSample.empty);
      draft.setArrayWeather('south-roof', samples, const PvgisImportInfo(
        sourceLabel: 'demo', entryCount: 8760, coveredYears: [2020],
        latitudeDeg: 50.1, longitudeDeg: 8.6,
      ));

      final source = draft.buildWeatherSource();
      expect(source, isA<HourlyWeatherSeries>());
      final hourly = source as HourlyWeatherSeries;
      expect(hourly.fallback, isA<SyntheticIrradianceSource>());

      // Unknown array still produces a non-zero synthetic sample at noon.
      final fallback = hourly.sampleFor(const WeatherQuery(
        arrayId: 'no-import', tiltDeg: 35, azimuthDeg: 180,
        dayOfYear: 172, hourOfDay: 12, latitudeDeg: 50,
      ));
      expect(fallback.poaWPerM2, greaterThan(0));
    });

    test('rejects series of wrong length', () {
      final draft = ConfigDraft.demo();
      expect(
        () => draft.setArrayWeather('south-roof',
            List<WeatherSample>.filled(10, WeatherSample.empty),
            const PvgisImportInfo(
              sourceLabel: 'x', entryCount: 10, coveredYears: [], latitudeDeg: 0, longitudeDeg: 0,
            )),
        throwsArgumentError,
      );
    });

    test('renameArrayWeather moves data to the new id', () {
      final draft = ConfigDraft.demo();
      final samples = List<WeatherSample>.filled(365 * 24, WeatherSample.empty);
      draft.setArrayWeather('south-roof', samples, const PvgisImportInfo(
        sourceLabel: 'demo', entryCount: 8760, coveredYears: [2020],
        latitudeDeg: 0, longitudeDeg: 0,
      ));

      expect(draft.hasWeatherFor('south-roof'), isTrue);
      expect(draft.renameArrayWeather('south-roof', 'main-roof'), isTrue);
      expect(draft.hasWeatherFor('south-roof'), isFalse);
      expect(draft.hasWeatherFor('main-roof'), isTrue);
      // No-op rename to same id.
      expect(draft.renameArrayWeather('main-roof', 'main-roof'), isFalse);
      // Refuse to clobber existing data under the target id.
      draft.setArrayWeather('other', samples, const PvgisImportInfo(
        sourceLabel: 'other', entryCount: 8760, coveredYears: [2021],
        latitudeDeg: 0, longitudeDeg: 0,
      ));
      expect(draft.renameArrayWeather('main-roof', 'other'), isFalse);
      expect(draft.weatherInfoFor('other')!.sourceLabel, 'other');
    });

    test('clearArrayWeather drops the series and metadata', () {
      final draft = ConfigDraft.demo();
      final samples = List<WeatherSample>.filled(365 * 24, WeatherSample.empty);
      draft.setArrayWeather('south-roof', samples, const PvgisImportInfo(
        sourceLabel: 'demo', entryCount: 8760, coveredYears: [2020],
        latitudeDeg: 0, longitudeDeg: 0,
      ));
      draft.clearArrayWeather('south-roof');
      expect(draft.hasWeatherFor('south-roof'), isFalse);
      expect(draft.weatherInfoFor('south-roof'), isNull);
      expect(draft.buildWeatherSource(), isNull);
    });

    test('orphanedWeatherArrayIds surfaces ids with no matching array', () {
      final draft = ConfigDraft.demo();
      final samples = List<WeatherSample>.filled(365 * 24, WeatherSample.empty);
      draft.setArrayWeather('ghost', samples, const PvgisImportInfo(
        sourceLabel: 'g', entryCount: 8760, coveredYears: [],
        latitudeDeg: 0, longitudeDeg: 0,
      ));
      expect(draft.orphanedWeatherArrayIds(), ['ghost']);
    });
  });

  group('PVGIS pipeline through ConfigDraft', () {
    test('parsed JSON drives a simulation when wired through the draft', () {
      final json = jsonEncode({
        'inputs': {
          'location': {'latitude': 50.0, 'longitude': 7.0}
        },
        'outputs': {
          'hourly': [
            // Mid-June, noon, full sun.
            {'time': '20200621:1210', 'G(i)': 1000.0, 'T2m': 20.0, 'WS10m': 2.0},
          ]
        }
      });
      final data = parsePvgisHourlyJson(json);
      final draft = ConfigDraft.demo();
      draft.setArrayWeather(
        'south-roof',
        data.toAveragedYear(),
        PvgisImportInfo(
          sourceLabel: 'fixture', entryCount: data.entries.length,
          coveredYears: const [2020],
          latitudeDeg: data.latitudeDeg, longitudeDeg: data.longitudeDeg,
        ),
      );

      final result = const PvSimulator().run(draft.build());
      // The single PVGIS slot adds a clearly non-zero step compared to
      // synthetic noise at that hour.
      expect(result.summary.pvAcKwh, greaterThan(0));
    });
  });
}
