import 'dart:convert';

import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

HorizontalIrradianceSeries _buildSeries() {
  final samples = List<HorizontalIrradianceSample>.generate(365 * 24, (i) {
    final hour = i % 24;
    final ghi = hour >= 6 && hour <= 18 ? 100.0 + i * 0.001 : 0.0;
    return HorizontalIrradianceSample(
      globalHorizontalWPerM2: ghi,
      diffuseHorizontalWPerM2: ghi * 0.4,
      ambientTempC: 15.0 + (i % 30),
      windMS: 2.0,
    );
  });
  return HorizontalIrradianceSeries(
    samples: samples,
    year: 2022,
    latitudeDeg: 52.41,
    longitudeDeg: 7.976,
    radDatabase: 'PVGIS-SARAH3',
  );
}

void main() {
  group('HorizontalIrradianceSeries JSON round-trip', () {
    test('preserves metadata and all 8760 samples', () {
      final source = _buildSeries();
      final encoded = jsonEncode(source.toJson());
      final decoded = HorizontalIrradianceSeries.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      expect(decoded.year, source.year);
      expect(decoded.latitudeDeg, source.latitudeDeg);
      expect(decoded.longitudeDeg, source.longitudeDeg);
      expect(decoded.radDatabase, source.radDatabase);
      expect(decoded.samples.length, source.samples.length);
      for (final i in const [0, 1, 123, 4321, 8000, 8759]) {
        expect(decoded.samples[i].globalHorizontalWPerM2,
            source.samples[i].globalHorizontalWPerM2);
        expect(decoded.samples[i].diffuseHorizontalWPerM2,
            source.samples[i].diffuseHorizontalWPerM2);
        expect(decoded.samples[i].ambientTempC, source.samples[i].ambientTempC);
        expect(decoded.samples[i].windMS, source.samples[i].windMS);
      }
    });

    test('omits radDatabase when null', () {
      final source = HorizontalIrradianceSeries(
        samples: List<HorizontalIrradianceSample>.filled(
          365 * 24,
          HorizontalIrradianceSample.empty,
        ),
        year: 2020,
        latitudeDeg: 50.0,
        longitudeDeg: 10.0,
      );
      final json = source.toJson();
      expect(json.containsKey('radDatabase'), isFalse);
      final round = HorizontalIrradianceSeries.fromJson(json);
      expect(round.radDatabase, isNull);
    });

    test('rejects payloads with the wrong number of samples', () {
      expect(
        () => HorizontalIrradianceSeries.fromJson({
          'year': 2022,
          'latitudeDeg': 50.0,
          'longitudeDeg': 10.0,
          'samples': <double>[1.0, 2.0, 3.0],
        }),
        throwsFormatException,
      );
    });

    test('rejects payloads with an unknown version', () {
      // A future schema bump emits version: 2; this build only knows
      // v1, so fromJson must surface a FormatException rather than
      // silently mis-parsing whatever shape v2 happens to have.
      expect(
        () => HorizontalIrradianceSeries.fromJson({
          'version': 99,
          'year': 2022,
          'latitudeDeg': 50.0,
          'longitudeDeg': 10.0,
          'samples':
              List<double>.filled(365 * 24 * 4, 0.0, growable: false),
        }),
        throwsFormatException,
      );
    });
  });
}
