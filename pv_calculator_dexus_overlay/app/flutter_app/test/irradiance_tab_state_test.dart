import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pv_calculator_app/services/pvgis_api.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_engine/pv_engine.dart';

void main() {
  group('ProjectController.loadSiteIrradiance', () {
    test('caches the parsed series and clears the cache flag from the proxy', () async {
      final stubBody = jsonEncode({
        'inputs': {
          'location': {'latitude': 52.41, 'longitude': 7.976},
          'meteo_data': {'radiation_db': 'PVGIS-SARAH3'},
        },
        'outputs': {
          'hourly': [
            for (var hour = 0; hour < 24; hour++)
              {
                'time': '20220115:${hour.toString().padLeft(2, '0')}10',
                'Gb(i)': hour >= 9 && hour <= 15 ? 200.0 : 0.0,
                'Gd(i)': hour >= 8 && hour <= 16 ? 80.0 : 0.0,
                'Gr(i)': 0.0,
                'T2m': 5.0,
                'WS10m': 3.0,
              }
          ],
        },
      });

      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['components'], '1');
        expect(request.url.queryParameters['pvcalculation'], '0');
        return http.Response(
          stubBody,
          200,
          headers: {
            'content-type': 'application/json',
            'x-cache': 'HIT',
          },
        );
      });

      final api = PvgisApiService(
        client: mockClient,
        endpoint: 'https://proxy.example.test',
        minimumInterval: Duration.zero,
      );
      addTearDown(api.dispose);
      final controller = ProjectController(pvgisApi: api);
      addTearDown(controller.dispose);

      expect(controller.draft.siteIrradiance.samples, isNull);
      expect(controller.loadingIrradiance, isFalse);

      await controller.loadSiteIrradiance();

      expect(controller.loadingIrradiance, isFalse);
      expect(controller.lastIrradianceError, isNull);
      final samples = controller.draft.siteIrradiance.samples;
      expect(samples, isNotNull);
      expect(samples!.samples.length, 365 * 24);
      expect(samples.year, controller.draft.siteIrradiance.year);
      expect(controller.draft.siteIrradiance.loadedFromCache, isTrue);
    });

    test('surfaces an upstream 4xx via lastIrradianceError without poisoning the cache', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'outside coverage'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = PvgisApiService(
        client: mockClient,
        endpoint: 'https://proxy.example.test',
        minimumInterval: Duration.zero,
      );
      addTearDown(api.dispose);
      final controller = ProjectController(pvgisApi: api);
      addTearDown(controller.dispose);

      await controller.loadSiteIrradiance();

      expect(controller.loadingIrradiance, isFalse);
      expect(controller.lastIrradianceError, contains('outside coverage'));
      expect(controller.draft.siteIrradiance.samples, isNull);
    });
  });

  group('ProjectController.selectArrayForCompass', () {
    test('writes azimuth to the selected array and ignores invalid indexes', () {
      final api = PvgisApiService(
        client: MockClient((_) async => http.Response('{}', 500)),
        minimumInterval: Duration.zero,
      );
      addTearDown(api.dispose);
      final controller = ProjectController(pvgisApi: api);
      addTearDown(controller.dispose);
      // Demo draft ships one array.
      final draftCopy = controller.draft;
      expect(draftCopy.arrays.length, greaterThan(0));

      controller.selectArrayForCompass(0);
      expect(controller.selectedArrayIndex, 0);

      controller.setSelectedArrayAzimuth(270.0);
      expect(draftCopy.arrays[0].azimuthDeg, 270.0);

      // Out-of-range selection is a no-op.
      controller.selectArrayForCompass(99);
      expect(controller.selectedArrayIndex, 0);

      controller.selectArrayForCompass(null);
      expect(controller.selectedArrayIndex, isNull);
      // After deselection writes are silently dropped.
      controller.setSelectedArrayAzimuth(45.0);
      expect(draftCopy.arrays[0].azimuthDeg, 270.0);
    });
  });

  // Engine-level smoke: a draft with cached samples must build a config
  // whose weatherSource is the HorizontalToPoaSource adapter we wired
  // through ConfigDraft.buildWeatherSource.
  test('ConfigDraft.build wires HorizontalToPoaSource when samples are loaded', () {
    final api = PvgisApiService(
      client: MockClient((_) async => http.Response('{}', 500)),
      minimumInterval: Duration.zero,
    );
    addTearDown(api.dispose);
    final controller = ProjectController(pvgisApi: api);
    addTearDown(controller.dispose);

    controller.draft.siteIrradiance.samples = HorizontalIrradianceSeries(
      samples: List<HorizontalIrradianceSample>.filled(
        365 * 24,
        HorizontalIrradianceSample.empty,
      ),
      year: 2022,
      latitudeDeg: controller.draft.latitudeDeg,
      longitudeDeg: controller.draft.longitudeDeg,
    );
    final config = controller.draft.build();
    expect(config.weatherSource, isA<HorizontalToPoaSource>());
  });
}
