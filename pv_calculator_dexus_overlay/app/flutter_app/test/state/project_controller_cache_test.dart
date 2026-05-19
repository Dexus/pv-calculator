import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pv_calculator_app/persistence/database.dart';
import 'package:pv_calculator_app/persistence/irradiance_cache_repository.dart';
import 'package:pv_calculator_app/services/pvgis_api.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_engine/pv_engine.dart';

String _pvgisStub() => jsonEncode({
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

HorizontalIrradianceSeries _series({
  double lat = 52.5,
  double lon = 13.4,
  int year = 2022,
  String? radDatabase = 'PVGIS-SARAH2',
}) {
  return HorizontalIrradianceSeries(
    samples: List<HorizontalIrradianceSample>.filled(
      365 * 24,
      const HorizontalIrradianceSample(
        globalHorizontalWPerM2: 50.0,
        diffuseHorizontalWPerM2: 20.0,
        ambientTempC: 12.0,
        windMS: 2.5,
      ),
    ),
    year: year,
    latitudeDeg: lat,
    longitudeDeg: lon,
    radDatabase: radDatabase,
  );
}

void main() {
  group('ProjectController + IrradianceCacheRepository', () {
    late AppDatabase db;
    late IrradianceCacheRepository cache;

    setUp(() {
      db = AppDatabase.memory();
      cache = IrradianceCacheRepository(db);
    });

    tearDown(() => db.close());

    test('cache hit bypasses the network entirely', () async {
      var apiHits = 0;
      final api = PvgisApiService(
        client: MockClient((_) async {
          apiHits++;
          return http.Response(_pvgisStub(), 200,
              headers: {'content-type': 'application/json'});
        }),
        endpoint: 'https://proxy.example.test',
        minimumInterval: Duration.zero,
      );
      addTearDown(api.dispose);

      final controller = ProjectController(pvgisApi: api, irradianceCache: cache);
      addTearDown(controller.dispose);

      // Pre-seed the cache for the controller's current site.
      cache.store(
        latitudeDeg: controller.draft.latitudeDeg,
        longitudeDeg: controller.draft.longitudeDeg,
        year: controller.draft.siteIrradiance.year,
        radDatabase: controller.draft.siteIrradiance.radDatabase,
        series: _series(
          lat: controller.draft.latitudeDeg,
          lon: controller.draft.longitudeDeg,
          year: controller.draft.siteIrradiance.year,
          radDatabase: controller.draft.siteIrradiance.radDatabase,
        ),
      );

      await controller.loadSiteIrradiance();

      expect(apiHits, 0, reason: 'cache hit must not reach the network');
      expect(controller.draft.siteIrradiance.samples, isNotNull);
      expect(controller.draft.siteIrradiance.loadedFromCache, isTrue);
      expect(controller.lastIrradianceError, isNull);
    });

    test('cache miss fetches from PVGIS and writes through to the cache',
        () async {
      var apiHits = 0;
      final api = PvgisApiService(
        client: MockClient((_) async {
          apiHits++;
          return http.Response(_pvgisStub(), 200,
              headers: {'content-type': 'application/json'});
        }),
        endpoint: 'https://proxy.example.test',
        minimumInterval: Duration.zero,
      );
      addTearDown(api.dispose);

      final controller = ProjectController(pvgisApi: api, irradianceCache: cache);
      addTearDown(controller.dispose);

      await controller.loadSiteIrradiance();

      expect(apiHits, 1);
      expect(controller.draft.siteIrradiance.samples, isNotNull);

      // Second call at the same site/year should now be a cache hit and
      // must NOT issue another request.
      controller.draft.siteIrradiance.samples = null;
      await controller.loadSiteIrradiance();
      expect(apiHits, 1, reason: 'second load should hit the local cache');
      expect(controller.draft.siteIrradiance.samples, isNotNull);
      expect(controller.draft.siteIrradiance.loadedFromCache, isTrue);
    });

    test('moving the pin mid-fetch caches under the captured key but discards the draft write',
        () async {
      // Race: a user edits lat/lon (or year/db) while a PVGIS request
      // is in flight. The response is genuinely valid for the
      // *original* request, so it must still land in the local cache,
      // but it must not silently pin onto the moved-pin draft — that's
      // the silent wrong-weather bug the reviewers flagged.
      final pending = Completer<http.Response>();
      final api = PvgisApiService(
        client: MockClient((_) async => pending.future),
        endpoint: 'https://proxy.example.test',
        minimumInterval: Duration.zero,
      );
      addTearDown(api.dispose);

      final controller = ProjectController(pvgisApi: api, irradianceCache: cache);
      addTearDown(controller.dispose);

      final origLat = controller.draft.latitudeDeg;
      final origLon = controller.draft.longitudeDeg;
      final origYear = controller.draft.siteIrradiance.year;
      final origDb = controller.draft.siteIrradiance.radDatabase;

      final loadFuture = controller.loadSiteIrradiance();
      // Let the http stack schedule its handler invocation.
      await Future<void>.delayed(Duration.zero);

      // Mid-fetch: user picks a different site on the map.
      controller.draft.latitudeDeg = 40.0;
      controller.draft.longitudeDeg = -3.0;

      pending.complete(http.Response(
        _pvgisStub(),
        200,
        headers: {'content-type': 'application/json'},
      ));
      await loadFuture;

      // The response is still cached under the *original* request key
      // — discarded for the draft, not lost.
      expect(
        cache.lookup(
          latitudeDeg: origLat,
          longitudeDeg: origLon,
          year: origYear,
          radDatabase: origDb,
        ),
        isNotNull,
      );
      // And the moved-pin draft is not wearing the old location's
      // samples.
      expect(controller.draft.siteIrradiance.samples, isNull);
    });

    test('loadDraft auto-loads irradiance from cache without touching the API',
        () async {
      var apiHits = 0;
      final api = PvgisApiService(
        client: MockClient((_) async {
          apiHits++;
          return http.Response('{}', 500);
        }),
        endpoint: 'https://proxy.example.test',
        minimumInterval: Duration.zero,
      );
      addTearDown(api.dispose);

      final controller = ProjectController(pvgisApi: api, irradianceCache: cache);
      addTearDown(controller.dispose);

      // Simulate "user opens a saved project at a location whose
      // irradiance is already cached locally". The draft has no
      // samples (engine config never persists them); loadDraft must
      // schedule a cache-only restore.
      final restoredDraft = ConfigDraft.demo()
        ..latitudeDeg = 48.1
        ..longitudeDeg = 11.5;
      cache.store(
        latitudeDeg: restoredDraft.latitudeDeg,
        longitudeDeg: restoredDraft.longitudeDeg,
        year: restoredDraft.siteIrradiance.year,
        radDatabase: restoredDraft.siteIrradiance.radDatabase,
        series: _series(
          lat: restoredDraft.latitudeDeg,
          lon: restoredDraft.longitudeDeg,
          year: restoredDraft.siteIrradiance.year,
          radDatabase: restoredDraft.siteIrradiance.radDatabase,
        ),
      );

      controller.loadDraft('Restored', restoredDraft,
          scenarioId: 's1', projectId: 'p1');

      // The auto-load is fire-and-forget — pump a microtask to let it
      // complete before asserting.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(apiHits, 0,
          reason: 'cache-only restore on load must not call PVGIS');
      expect(controller.draft.siteIrradiance.samples, isNotNull);
      expect(controller.draft.siteIrradiance.loadedFromCache, isTrue);
    });
  });
}
