import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

void main() {
  group('pvgisHorizontalSeriesUrl', () {
    test('builds canonical horizontal-irradiance query for a default endpoint', () {
      final url = pvgisHorizontalSeriesUrl(
        latitudeDeg: 52.410000,
        longitudeDeg: 7.976000,
        year: 2022,
        radDatabase: 'PVGIS-SARAH3',
      );
      expect(url.host, 're.jrc.ec.europa.eu');
      expect(url.path, '/api/v5_3/seriescalc');
      final q = url.queryParameters;
      expect(q['lat'], '52.410000');
      expect(q['lon'], '7.976000');
      expect(q['angle'], '0');
      expect(q['aspect'], '0');
      expect(q['components'], '1');
      expect(q['pvcalculation'], '0');
      expect(q['outputformat'], 'json');
      expect(q['startyear'], '2022');
      expect(q['endyear'], '2022');
      expect(q['usehorizon'], '1');
      expect(q['raddatabase'], 'PVGIS-SARAH3');
      // PV-mode-only params must not leak into a horizontal request.
      expect(q.containsKey('peakpower'), isFalse);
      expect(q.containsKey('loss'), isFalse);
    });

    test('forwards a proxy endpoint while keeping every horizontal flag', () {
      final url = pvgisHorizontalSeriesUrl(
        latitudeDeg: 52.41,
        longitudeDeg: 7.976,
        year: 2022,
        endpoint: 'https://pv-calculator.example.workers.dev/',
      );
      expect(url.host, 'pv-calculator.example.workers.dev');
      expect(url.queryParameters['components'], '1');
      expect(url.queryParameters['pvcalculation'], '0');
    });

    test('rejects out-of-range coordinates and pre-2005 years', () {
      expect(
        () => pvgisHorizontalSeriesUrl(latitudeDeg: 95, longitudeDeg: 0, year: 2022),
        throwsArgumentError,
      );
      expect(
        () => pvgisHorizontalSeriesUrl(latitudeDeg: 0, longitudeDeg: -200, year: 2022),
        throwsArgumentError,
      );
      expect(
        () => pvgisHorizontalSeriesUrl(latitudeDeg: 0, longitudeDeg: 0, year: 2000),
        throwsArgumentError,
      );
    });
  });
}
