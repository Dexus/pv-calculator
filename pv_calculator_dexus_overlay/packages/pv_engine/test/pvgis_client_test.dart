import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

void main() {
  group('appAzimuthToPvgis', () {
    test('canonical quadrants round-trip with appAzimuthDeg', () {
      // 0/360 = north → PVGIS ±180 (canonicalised to +180).
      expect(appAzimuthToPvgis(0), closeTo(180.0, 1e-9));
      expect(appAzimuthToPvgis(360), closeTo(180.0, 1e-9));
      // 90 = east → PVGIS -90.
      expect(appAzimuthToPvgis(90), closeTo(-90.0, 1e-9));
      // 180 = south → PVGIS 0.
      expect(appAzimuthToPvgis(180), closeTo(0.0, 1e-9));
      // 270 = west → PVGIS +90.
      expect(appAzimuthToPvgis(270), closeTo(90.0, 1e-9));
    });

    test('inverse of PvgisHourlyData.appAzimuthDeg for sample angles', () {
      for (final pvgisIn in <double>[-180, -135, -90, -45, 0, 45, 90, 135, 180]) {
        final viaData = PvgisHourlyData(
          entries: const [], latitudeDeg: 0, longitudeDeg: 0,
          azimuthDegPvgis: pvgisIn,
        ).appAzimuthDeg!;
        final back = appAzimuthToPvgis(viaData);
        // ±180 collapse to a single canonical north (+180); compare
        // modulo 360 to accept either representation.
        final delta = ((back - pvgisIn).abs() % 360.0);
        expect(delta < 1e-9 || (360.0 - delta) < 1e-9, isTrue,
            reason: 'pvgisIn=$pvgisIn → app=$viaData → back=$back');
      }
    });
  });

  group('buildPvgisSeriesCalcUrl', () {
    PvgisRequest baseRequest() => const PvgisRequest(
          latitudeDeg: 50.1,
          longitudeDeg: 8.6,
          peakKw: 4.8,
          tiltDeg: 35,
          appAzimuthDeg: 180,
          lossFactor: 0.14,
          startYear: 2020,
          endYear: 2023,
        );

    test('hits the v5_3 seriescalc endpoint with required PVGIS params', () {
      final url = buildPvgisSeriesCalcUrl(baseRequest());
      expect(url.host, 're.jrc.ec.europa.eu');
      expect(url.path, '/api/v5_3/seriescalc');
      final q = url.queryParameters;
      expect(q['lat'], '50.100000');
      expect(q['lon'], '8.600000');
      expect(q['startyear'], '2020');
      expect(q['endyear'], '2023');
      expect(q['pvcalculation'], '1');
      expect(q['peakpower'], '4.8');
      expect(q['loss'], '14');
      expect(q['angle'], '35');
      expect(q['aspect'], '0'); // south
      expect(q['outputformat'], 'json');
      expect(q['usehorizon'], '1');
      expect(q['mountingplace'], 'building');
      expect(q.containsKey('raddatabase'), isFalse);
    });

    test('converts app azimuth to PVGIS aspect (east → -90)', () {
      final url = buildPvgisSeriesCalcUrl(const PvgisRequest(
        latitudeDeg: 50, longitudeDeg: 8, peakKw: 1, tiltDeg: 30,
        appAzimuthDeg: 90, startYear: 2020, endYear: 2020,
      ));
      expect(url.queryParameters['aspect'], '-90');
    });

    test('forwards raddatabase when set', () {
      final url = buildPvgisSeriesCalcUrl(const PvgisRequest(
        latitudeDeg: 50, longitudeDeg: 8, peakKw: 1, tiltDeg: 30,
        appAzimuthDeg: 180, startYear: 2020, endYear: 2020,
        radDatabase: 'PVGIS-SARAH3',
      ));
      expect(url.queryParameters['raddatabase'], 'PVGIS-SARAH3');
    });

    test('honours a custom endpoint (self-hosted / proxy)', () {
      final url = buildPvgisSeriesCalcUrl(
        baseRequest(),
        endpoint: 'https://pvgis.example.test/api/v5_3/seriescalc',
      );
      expect(url.host, 'pvgis.example.test');
      expect(url.path, '/api/v5_3/seriescalc');
      expect(url.queryParameters['lat'], '50.100000');
    });

    test('loss fraction is multiplied by 100 for PVGIS', () {
      final url = buildPvgisSeriesCalcUrl(const PvgisRequest(
        latitudeDeg: 50, longitudeDeg: 8, peakKw: 1, tiltDeg: 30,
        appAzimuthDeg: 180, lossFactor: 0.075,
        startYear: 2020, endYear: 2020,
      ));
      expect(url.queryParameters['loss'], '7.5');
    });

    test('usehorizon=false maps to the "0" flag', () {
      final url = buildPvgisSeriesCalcUrl(const PvgisRequest(
        latitudeDeg: 50, longitudeDeg: 8, peakKw: 1, tiltDeg: 30,
        appAzimuthDeg: 180, startYear: 2020, endYear: 2020,
        useHorizon: false,
      ));
      expect(url.queryParameters['usehorizon'], '0');
    });
  });

  group('PvgisRequest.validate', () {
    test('rejects out-of-range latitude', () {
      expect(
        () => const PvgisRequest(
          latitudeDeg: 95, longitudeDeg: 0, peakKw: 1, tiltDeg: 30,
          appAzimuthDeg: 180, startYear: 2020, endYear: 2020,
        ).validate(),
        throwsArgumentError,
      );
    });

    test('rejects non-positive peak power', () {
      expect(
        () => const PvgisRequest(
          latitudeDeg: 50, longitudeDeg: 8, peakKw: 0, tiltDeg: 30,
          appAzimuthDeg: 180, startYear: 2020, endYear: 2020,
        ).validate(),
        throwsArgumentError,
      );
    });

    test('rejects inverted year window', () {
      expect(
        () => const PvgisRequest(
          latitudeDeg: 50, longitudeDeg: 8, peakKw: 1, tiltDeg: 30,
          appAzimuthDeg: 180, startYear: 2022, endYear: 2020,
        ).validate(),
        throwsArgumentError,
      );
    });

    test('rejects unknown mounting place', () {
      expect(
        () => const PvgisRequest(
          latitudeDeg: 50, longitudeDeg: 8, peakKw: 1, tiltDeg: 30,
          appAzimuthDeg: 180, startYear: 2020, endYear: 2020,
          mountingPlace: 'orbital',
        ).validate(),
        throwsArgumentError,
      );
    });

    test('rejects startYear earlier than PVGIS coverage', () {
      expect(
        () => const PvgisRequest(
          latitudeDeg: 50, longitudeDeg: 8, peakKw: 1, tiltDeg: 30,
          appAzimuthDeg: 180, startYear: 1999, endYear: 2020,
        ).validate(),
        throwsArgumentError,
      );
    });
  });
}
