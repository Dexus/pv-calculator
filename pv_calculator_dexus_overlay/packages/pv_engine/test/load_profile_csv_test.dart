import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

void main() {
  group('parseLoadProfileCsv — Smartmeter (hourly power W)', () {
    test('24 hourly rows produce 24-slot shape with matching daily total', () {
      final csv = StringBuffer('Zeitstempel;Wirkleistung [W]\n');
      // Mid-day peak, low night load — 24 hourly values in watts.
      const watts = <int>[
        300, 280, 260, 250, 250, 280, // 00–05
        450, 700, 600, 500, 450, 450, // 06–11
        500, 480, 470, 520, 700, 1200, // 12–17
        1500, 1300, 1000, 700, 450, 350, // 18–23
      ];
      for (var h = 0; h < 24; h++) {
        csv.writeln('2024-01-15 ${h.toString().padLeft(2, '0')}:00:00;${watts[h]}');
      }
      final profile = parseLoadProfileCsv(csv.toString());
      profile.validate();
      // Sum of watts → /1000 → kWh per day (each value is one hour).
      final expectedDaily =
          watts.fold<double>(0, (s, v) => s + v) / 1000.0;
      expect(profile.dailyKwh, closeTo(expectedDaily, 1e-9));
      expect(profile.hourlyShape.length, 24);
      expect(profile.hourlyShape[18], closeTo(1.5, 1e-9));
    });

    test('15-minute samples in one hour collapse to one bucket', () {
      final csv = StringBuffer('Zeitstempel;Wirkleistung [W]\n');
      // Four 15-min samples in hour 10 averaging 1000 W; everything else is 0.
      csv.writeln('2024-01-15 10:00:00;800');
      csv.writeln('2024-01-15 10:15:00;1000');
      csv.writeln('2024-01-15 10:30:00;1200');
      csv.writeln('2024-01-15 10:45:00;1000');
      final profile = parseLoadProfileCsv(csv.toString());
      profile.validate();
      // Average power 1000 W × 1 h → 1 kWh, total daily energy 1 kWh.
      expect(profile.dailyKwh, closeTo(1.0, 1e-9));
      expect(profile.hourlyShape[10], closeTo(1.0, 1e-9));
      for (var h = 0; h < 24; h++) {
        if (h == 10) continue;
        expect(profile.hourlyShape[h], 0);
      }
    });

    test('two distinct days average into a single representative day', () {
      final csv = StringBuffer('Zeitstempel;Wirkleistung [W]\n');
      // Day 1: hour 10 = 600 W. Day 2: hour 10 = 1400 W. Average → 1000 W.
      csv.writeln('2024-01-15 10:00:00;600');
      csv.writeln('2024-01-16 10:00:00;1400');
      final profile = parseLoadProfileCsv(csv.toString());
      profile.validate();
      expect(profile.hourlyShape[10], closeTo(1.0, 1e-9));
      expect(profile.dailyKwh, closeTo(1.0, 1e-9));
    });
  });

  group('parseLoadProfileCsv — Home Assistant (ISO 8601 + kWh state)', () {
    test('kWh state column sums per-hour energy increments', () {
      final csv = StringBuffer('timestamp,state\n');
      // Three energy increments within hour 9; energy adds up.
      csv.writeln('2024-01-15T09:00:00+01:00,0.20');
      csv.writeln('2024-01-15T09:20:00+01:00,0.15');
      csv.writeln('2024-01-15T09:40:00+01:00,0.10');
      // Single increment in hour 18.
      csv.writeln('2024-01-15T18:00:00+01:00,0.55');
      final profile = parseLoadProfileCsv(csv.toString());
      profile.validate();
      expect(profile.hourlyShape[9], closeTo(0.45, 1e-9));
      expect(profile.hourlyShape[18], closeTo(0.55, 1e-9));
      expect(profile.dailyKwh, closeTo(1.0, 1e-9));
    });
  });

  group('parseLoadProfileCsv — Shelly (date,time,power)', () {
    test('separate date and time columns parse correctly', () {
      final csv = StringBuffer('date,time,power\n');
      csv.writeln('2024-01-15,10:00:00,800');
      csv.writeln('2024-01-15,11:00:00,1200');
      final profile = parseLoadProfileCsv(csv.toString());
      profile.validate();
      // 800 W → 0.8 kWh for hour 10, 1200 W → 1.2 kWh for hour 11.
      expect(profile.hourlyShape[10], closeTo(0.8, 1e-9));
      expect(profile.hourlyShape[11], closeTo(1.2, 1e-9));
      expect(profile.dailyKwh, closeTo(2.0, 1e-9));
    });
  });

  group('parseLoadProfileCsv — unit & locale handling', () {
    test('kW values stay as kW (no /1000 division)', () {
      final csv = StringBuffer('timestamp;power [kW]\n');
      // Values in kW (< 200 → no scaling applied).
      csv.writeln('2024-01-15 09:00:00;0.80');
      csv.writeln('2024-01-15 10:00:00;1.20');
      final profile = parseLoadProfileCsv(csv.toString());
      profile.validate();
      expect(profile.hourlyShape[9], closeTo(0.80, 1e-9));
      expect(profile.hourlyShape[10], closeTo(1.20, 1e-9));
    });

    test('German decimal comma is recognised', () {
      final csv = StringBuffer('Zeitstempel;Wirkleistung [kW]\n');
      csv.writeln('2024-01-15 09:00:00;0,80');
      csv.writeln('2024-01-15 10:00:00;1,20');
      final profile = parseLoadProfileCsv(csv.toString());
      profile.validate();
      expect(profile.hourlyShape[9], closeTo(0.80, 1e-9));
      expect(profile.hourlyShape[10], closeTo(1.20, 1e-9));
    });
  });

  group('parseLoadProfileCsv — error paths', () {
    test('empty input throws', () {
      expect(
        () => parseLoadProfileCsv(''),
        throwsA(isA<FormatException>()),
      );
    });

    test('header without time column throws', () {
      expect(
        () => parseLoadProfileCsv('foo;bar\n1;2\n'),
        throwsA(isA<FormatException>()),
      );
    });

    test('header without value column throws', () {
      expect(
        () => parseLoadProfileCsv('timestamp;notes\n2024-01-15 10:00:00;hello\n'),
        throwsA(isA<FormatException>()),
      );
    });

    test('only malformed rows after header throws', () {
      expect(
        () => parseLoadProfileCsv('timestamp;power\nfoo;bar\n'),
        throwsA(isA<FormatException>()),
      );
    });

    test('all-zero values throw', () {
      final csv = StringBuffer('timestamp;power [W]\n');
      for (var h = 0; h < 24; h++) {
        csv.writeln('2024-01-15 ${h.toString().padLeft(2, '0')}:00:00;0');
      }
      expect(
        () => parseLoadProfileCsv(csv.toString()),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
