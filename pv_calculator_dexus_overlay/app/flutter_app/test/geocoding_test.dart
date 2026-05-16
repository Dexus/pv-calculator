import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pv_calculator_app/services/geocoding.dart';

void main() {
  group('NominatimGeocoder', () {
    test('parses a successful jsonv2 response into results', () async {
      final mock = MockClient((request) async {
        expect(request.url.host, 'nominatim.openstreetmap.org');
        expect(request.url.queryParameters['q'], 'Frankfurt am Main');
        expect(request.url.queryParameters['format'], 'jsonv2');
        // Usage policy on native: User-Agent must be set.
        expect(request.headers['User-Agent'], isNotNull);
        expect(request.headers['User-Agent'], isNotEmpty);
        return http.Response(
          jsonEncode([
            {
              'display_name': 'Frankfurt am Main, Hessen, Deutschland',
              'lat': '50.1106',
              'lon': '8.6822',
            },
            {
              'display_name': 'Frankfurt (Oder), Brandenburg, Deutschland',
              'lat': '52.3471',
              'lon': '14.5505',
            },
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final geocoder = NominatimGeocoder(client: mock, minimumInterval: Duration.zero);
      final results = await geocoder.search('Frankfurt am Main');
      expect(results, hasLength(2));
      expect(results[0].displayName, startsWith('Frankfurt am Main'));
      expect(results[0].latitudeDeg, closeTo(50.1106, 1e-6));
      expect(results[0].longitudeDeg, closeTo(8.6822, 1e-6));
    });

    test('on web, sends Referer and omits User-Agent (which browsers strip)', () async {
      final mock = MockClient((request) async {
        // The browser would drop User-Agent anyway; we don't even
        // try to set it on web so the request looks honest.
        expect(request.headers.containsKey('User-Agent'), isFalse);
        expect(request.headers['Referer'], isNotNull);
        expect(request.headers['Referer'], isNotEmpty);
        return http.Response('[]', 200);
      });
      final geocoder = NominatimGeocoder(
        client: mock,
        isWeb: true,
        minimumInterval: Duration.zero,
      );
      await geocoder.search('whatever');
    });

    test('returns empty for blank query without hitting the network', () async {
      var called = false;
      final mock = MockClient((_) async {
        called = true;
        return http.Response('[]', 200);
      });
      final geocoder = NominatimGeocoder(client: mock, minimumInterval: Duration.zero);
      expect(await geocoder.search('   '), isEmpty);
      expect(called, isFalse);
    });

    test('surfaces 429 as a GeocodingException', () async {
      final mock = MockClient((_) async => http.Response('rate limited', 429));
      final geocoder = NominatimGeocoder(client: mock, minimumInterval: Duration.zero);
      await expectLater(
        geocoder.search('anywhere'),
        throwsA(isA<GeocodingException>()
            .having((e) => e.message, 'message', contains('429'))),
      );
    });

    test('surfaces non-200 status codes as GeocodingException', () async {
      final mock = MockClient((_) async => http.Response('server died', 500));
      final geocoder = NominatimGeocoder(client: mock, minimumInterval: Duration.zero);
      await expectLater(geocoder.search('anything'), throwsA(isA<GeocodingException>()));
    });

    test('skips malformed entries instead of crashing', () async {
      final mock = MockClient((_) async => http.Response(
            jsonEncode([
              {'display_name': 'ok', 'lat': '1.0', 'lon': '2.0'},
              {'lat': '1.0'}, // missing display_name and lon
              {'display_name': 'bad', 'lat': 'not-a-number', 'lon': '0'},
              'not even an object',
            ]),
            200,
          ));
      final geocoder = NominatimGeocoder(client: mock, minimumInterval: Duration.zero);
      final results = await geocoder.search('whatever');
      expect(results, hasLength(1));
      expect(results.single.displayName, 'ok');
    });

    test('enforces the minimum interval between successive requests', () async {
      var calls = 0;
      final mock = MockClient((_) async {
        calls++;
        return http.Response(jsonEncode([
          {'display_name': 'X', 'lat': '0', 'lon': '0'}
        ]), 200);
      });
      final geocoder = NominatimGeocoder(
        client: mock,
        minimumInterval: const Duration(milliseconds: 150),
      );
      final start = DateTime.now();
      await geocoder.search('first');
      await geocoder.search('second');
      final elapsed = DateTime.now().difference(start);
      expect(calls, 2);
      expect(elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 140)));
    });
  });
}
