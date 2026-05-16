import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

void main() {
  group('stepsCsv', () {
    test('emits header + one row per step with CRLF line endings', () {
      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(id: 'r', label: 'R', peakKw: 1.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i'),
        ],
        inverters: const [Inverter(id: 'i', label: 'I', maxAcKw: 5.0)],
        loadProfile: const LoadProfile(dailyKwh: 5),
        startDayOfYear: 172,
        days: 1,
      ));

      final csv = stepsCsv(result.steps);
      final lines = csv.split('\r\n');
      // 24 data rows + 1 header + 1 empty trailing element from split on final CRLF
      expect(lines, hasLength(24 + 1 + 1));
      expect(lines.first.split(';'), contains('pvAcKwh'));
      for (final col in ['socKwh_1', 'chargeKwh_1', 'dischargeKwh_1']) {
        expect(lines.first.split(';'), isNot(contains(col)),
            reason: 'no per-battery columns when batteryCount is 0');
      }
    });

    test('appends per-battery charge / discharge / soc columns in declared order', () {
      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(id: 'r', label: 'R', peakKw: 2.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'i'),
        ],
        inverters: const [Inverter(id: 'i', label: 'I', maxAcKw: 5.0)],
        batteries: const [
          BatteryConfig(id: 'a', capacityKwh: 2, maxChargeKw: 2, maxDischargeKw: 2),
          BatteryConfig(id: 'b', capacityKwh: 2, maxChargeKw: 2, maxDischargeKw: 2),
        ],
        loadProfile: const LoadProfile(dailyKwh: 3),
        startDayOfYear: 172,
        days: 1,
      ));

      final csv = stepsCsv(result.steps, batteryCount: 2);
      final lines = csv.split('\r\n');
      final headers = lines.first.split(';');
      expect(headers, containsAll([
        'chargeKwh_1', 'chargeKwh_2',
        'dischargeKwh_1', 'dischargeKwh_2',
        'socKwh_1', 'socKwh_2',
      ]));
      // Charge → discharge → soc, each in declared order.
      expect(headers.indexOf('chargeKwh_1'), lessThan(headers.indexOf('chargeKwh_2')));
      expect(headers.indexOf('chargeKwh_2'), lessThan(headers.indexOf('dischargeKwh_1')));
      expect(headers.indexOf('dischargeKwh_2'), lessThan(headers.indexOf('socKwh_1')));
      expect(headers.indexOf('socKwh_1'), lessThan(headers.indexOf('socKwh_2')));
    });

    test('comma delimiter is honoured', () {
      final csv = stepsCsv(const [], delimiter: ',');
      expect(csv.split('\r\n').first, contains('pvAcKwh'));
      expect(csv.split('\r\n').first, contains(','));
      expect(csv.split('\r\n').first, isNot(contains(';')));
    });
  });

  group('monthlyCsv', () {
    test('emits 12 data rows', () {
      final csv = monthlyCsv(SummaryAggregator.monthly(const []));
      final lines = csv.split('\r\n');
      expect(lines, hasLength(12 + 1 + 1));
      expect(lines.first.split(';').first, 'month');
      expect(lines[1].split(';').first, '1');
      expect(lines[12].split(';').first, '12');
    });
  });
}
