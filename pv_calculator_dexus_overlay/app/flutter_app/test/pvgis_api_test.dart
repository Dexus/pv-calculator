import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pv_calculator_app/services/pvgis_api.dart';
import 'package:pv_engine/pv_engine.dart';

String _samplePvgisBody() => jsonEncode({
      'inputs': {
        'location': {'latitude': 50.1, 'longitude': 8.6},
        'mounting_system': {
          'fixed': {
            'slope': {'value': 35.0, 'optimal': false},
            'azimuth': {'value': 0.0, 'optimal': false},
          }
        }
      },
      'outputs': {
        'hourly': [
          {'time': '20200101:0010', 'G(i)': 0.0, 'T2m': 2.5, 'WS10m': 3.2, 'P': 0.0},
          {'time': '20200101:1210', 'G(i)': 750.0, 'T2m': 8.1, 'WS10m': 4.0, 'P': 2400.0},
        ]
      }
    });

const PvgisRequest _frankfurtRequest = PvgisRequest(
  latitudeDeg: 50.1,
  longitudeDeg: 8.6,
  peakKw: 4.8,
  tiltDeg: 35,
  appAzimuthDeg: 180,
  lossFactor: 0.14,
  startYear: 2020,
  endYear: 2023,
);

void main() {
  group('PvgisApiService.fetch', () {
    test('issues a seriescalc request and parses the response', () async {
      Uri? captured;
      final mock = MockClient((request) async {
        captured = request.url;
        return http.Response(_samplePvgisBody(), 200,
            headers: {'content-type': 'application/json'});
      });
      final api = PvgisApiService(client: mock, minimumInterval: Duration.zero);
      final data = await api.fetch(_frankfurtRequest);

      expect(captured, isNotNull);
      expect(captured!.host, 're.jrc.ec.europa.eu');
      expect(captured!.path, endsWith('/seriescalc'));
      expect(captured!.queryParameters['pvcalculation'], '1');
      expect(captured!.queryParameters['outputformat'], 'json');
      expect(captured!.queryParameters['startyear'], '2020');
      expect(captured!.queryParameters['endyear'], '2023');
      expect(captured!.queryParameters['aspect'], '0'); // south

      expect(data.entries, hasLength(2));
      expect(data.latitudeDeg, closeTo(50.1, 1e-9));
      expect(data.slopeDeg, closeTo(35.0, 1e-9));
    });

    test('honours a custom endpoint override', () async {
      Uri? captured;
      final mock = MockClient((request) async {
        captured = request.url;
        return http.Response(_samplePvgisBody(), 200);
      });
      final api = PvgisApiService(
        client: mock,
        endpoint: 'https://pvgis.example.test/api/v5_3/seriescalc',
        minimumInterval: Duration.zero,
      );
      await api.fetch(_frankfurtRequest);
      expect(captured!.host, 'pvgis.example.test');
    });

    test('surfaces non-200 status as PvgisApiException with status', () async {
      final mock = MockClient((_) async => http.Response('not found', 404));
      final api = PvgisApiService(client: mock, minimumInterval: Duration.zero);
      await expectLater(
        api.fetch(_frankfurtRequest),
        throwsA(isA<PvgisApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message', contains('404'))),
      );
    });

    test('surfaces malformed JSON as PvgisApiException', () async {
      final mock = MockClient((_) async => http.Response('not json', 200));
      final api = PvgisApiService(client: mock, minimumInterval: Duration.zero);
      await expectLater(
        api.fetch(_frankfurtRequest),
        throwsA(isA<PvgisApiException>()),
      );
    });

    test('rejects an invalid PvgisRequest before issuing a request', () async {
      var called = false;
      final mock = MockClient((_) async {
        called = true;
        return http.Response(_samplePvgisBody(), 200);
      });
      final api = PvgisApiService(client: mock, minimumInterval: Duration.zero);
      await expectLater(
        api.fetch(const PvgisRequest(
          latitudeDeg: 50, longitudeDeg: 8, peakKw: 0, tiltDeg: 30,
          appAzimuthDeg: 180, startYear: 2020, endYear: 2020,
        )),
        throwsA(isA<PvgisApiException>()),
      );
      expect(called, isFalse);
    });
  });
}
