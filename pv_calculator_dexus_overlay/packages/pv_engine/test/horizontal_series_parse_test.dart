import 'dart:convert';

import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

/// Minimal PVGIS-shaped horizontal-irradiance fixture covering a single
/// summer day. Real responses have 8760 entries; we exercise the parser
/// on a small slice and assert the values it should produce.
String _buildFixture() {
  final hourly = <Map<String, dynamic>>[];
  for (var hour = 0; hour < 24; hour++) {
    final beam = hour >= 6 && hour <= 18 ? 400.0 : 0.0;
    final diffuse = hour >= 6 && hour <= 18 ? 150.0 : 0.0;
    hourly.add({
      'time': '20220621:${hour.toString().padLeft(2, '0')}10',
      'Gb(i)': beam,
      'Gd(i)': diffuse,
      'Gr(i)': 0.0,
      'T2m': 18.0,
      'WS10m': 2.0,
    });
  }
  // Leap-day record that must be silently dropped (PVGIS includes Feb 29
  // for leap years; the engine uses a 365-day calendar).
  hourly.add({
    'time': '20240229:1210',
    'Gb(i)': 999.0,
    'Gd(i)': 999.0,
    'Gr(i)': 0.0,
    'T2m': 999.0,
    'WS10m': 999.0,
  });
  return jsonEncode({
    'inputs': {
      'location': {'latitude': 52.41, 'longitude': 7.976},
      'meteo_data': {'radiation_db': 'PVGIS-SARAH3'},
    },
    'outputs': {'hourly': hourly},
  });
}

void main() {
  group('parsePvgisHorizontalSeries', () {
    test('produces a 365×24 series with site metadata', () {
      final series = parsePvgisHorizontalSeries(_buildFixture(), year: 2022);
      expect(series.samples.length, 365 * 24);
      expect(series.year, 2022);
      expect(series.latitudeDeg, closeTo(52.41, 1e-9));
      expect(series.longitudeDeg, closeTo(7.976, 1e-9));
      expect(series.radDatabase, 'PVGIS-SARAH3');
    });

    test('reconstructs GHI = Gb(i) + Gd(i) and keeps DHI = Gd(i)', () {
      final series = parsePvgisHorizontalSeries(_buildFixture(), year: 2022);
      // 21 June 2022 is day-of-year 172. Hour 12 picks the noon sample.
      final noon = series.sampleAt(dayOfYear: 172, hourOfDay: 12.0);
      expect(noon.globalHorizontalWPerM2, closeTo(550.0, 1e-9));
      expect(noon.diffuseHorizontalWPerM2, closeTo(150.0, 1e-9));
      expect(noon.ambientTempC, closeTo(18.0, 1e-9));
    });

    test('dropped leap-day record does not pollute any 365-day slot', () {
      final series = parsePvgisHorizontalSeries(_buildFixture(), year: 2022);
      // 28 February is day-of-year 59; 1 March is day 60. Neither bucket
      // received the 20240229 entry, so both must stay at the empty default.
      for (final doy in [59, 60]) {
        for (var hour = 0; hour < 24; hour++) {
          final s = series.sampleAt(dayOfYear: doy, hourOfDay: hour.toDouble());
          expect(s.globalHorizontalWPerM2, 0.0,
              reason: 'unexpected non-zero at doy=$doy hour=$hour');
        }
      }
    });

    test('annual GHI sum lands in a plausible mid-latitude band', () {
      // Build a fixture where every day of the year has the same shape as
      // our summer day. That gives a known annual sum we can sanity-check
      // the helper against (~1.6 MWh/m² at 13 × 550 W/m²·d × 365). The
      // production fixture would land in the typical European 800–1400
      // kWh/m²/yr band; here we just assert the helper computes the sum
      // additively and in the right unit.
      final fixture = {
        'inputs': {
          'location': {'latitude': 50.0, 'longitude': 10.0},
          'meteo_data': {'radiation_db': 'PVGIS-SARAH3'},
        },
        'outputs': {
          'hourly': [
            for (var doy = 1; doy <= 365; doy++)
              for (var hour = 0; hour < 24; hour++)
                {
                  'time': _doyToPvgisTime(doy, hour),
                  'Gb(i)': hour >= 6 && hour <= 18 ? 400.0 : 0.0,
                  'Gd(i)': hour >= 6 && hour <= 18 ? 150.0 : 0.0,
                  'Gr(i)': 0.0,
                  'T2m': 15.0,
                  'WS10m': 1.0,
                }
          ],
        },
      };
      final series = parsePvgisHorizontalSeries(jsonEncode(fixture), year: 2022);
      // 13 hours × 550 W/m²·h × 365 d ÷ 1000 = 2 609.75 kWh/m²
      expect(series.annualGlobalKWhPerM2, closeTo(2609.75, 1e-3));
    });
  });
}

String _doyToPvgisTime(int doy, int hour) {
  final base = DateTime.utc(2022, 1, 1).add(Duration(days: doy - 1));
  final mm = base.month.toString().padLeft(2, '0');
  final dd = base.day.toString().padLeft(2, '0');
  final hh = hour.toString().padLeft(2, '0');
  return '${base.year}$mm$dd:${hh}10';
}
