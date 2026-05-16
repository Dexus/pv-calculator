import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

void main() {
  group('multi-battery dispatch', () {
    test('charges battery[0] before battery[1] in declared order', () {
      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(id: 'big', label: 'Big', peakKw: 8.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'main'),
        ],
        inverters: const [Inverter(id: 'main', label: 'Main', maxAcKw: 10.0)],
        // High charge rates keep capacity (not rate) as the per-step limiter, so
        // the "battery[1] only sees the leftover" property is cleanly assertable.
        batteries: const [
          BatteryConfig(id: 'first', capacityKwh: 1.0, maxChargeKw: 10.0, maxDischargeKw: 10.0, initialSocKwh: 0.0),
          BatteryConfig(id: 'second', capacityKwh: 5.0, maxChargeKw: 10.0, maxDischargeKw: 10.0, initialSocKwh: 0.0),
        ],
        loadProfile: const LoadProfile(dailyKwh: 0),
        startDayOfYear: 172,
        days: 1,
      ));

      for (final step in result.steps) {
        if (step.batteryChargesKwh[1] > 1e-9) {
          expect(step.batterySocsKwh[0], closeTo(1.0, 1e-6),
              reason: 'battery[1] should only absorb leftover surplus after battery[0] is full');
        }
      }

      expect(result.steps.last.batterySocsKwh.length, 2);
      expect(result.steps.last.batterySocsKwh[0], closeTo(1.0, 1e-6),
          reason: 'first battery ends the day full');
    });

    test('discharges battery[0] before battery[1] in declared order', () {
      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(id: 'tiny', label: 'Tiny', peakKw: 0.001, azimuthDeg: 180, tiltDeg: 35, inverterId: 'main'),
        ],
        inverters: const [Inverter(id: 'main', label: 'Main', maxAcKw: 10.0)],
        // High discharge rates again let us assert that battery[1] only fires
        // once battery[0] has hit its minSocKwh floor in that step.
        batteries: const [
          BatteryConfig(id: 'first', capacityKwh: 2.0, maxChargeKw: 10.0, maxDischargeKw: 10.0, initialSocKwh: 2.0),
          BatteryConfig(id: 'second', capacityKwh: 5.0, maxChargeKw: 10.0, maxDischargeKw: 10.0, initialSocKwh: 5.0),
        ],
        loadProfile: const LoadProfile(dailyKwh: 24),
        startDayOfYear: 355,
        days: 1,
      ));

      for (final step in result.steps) {
        if (step.batteryDischargesKwh[1] > 1e-9) {
          expect(step.batterySocsKwh[0], closeTo(0.0, 1e-6),
              reason: 'battery[1] should only discharge once battery[0] reached its minSocKwh');
        }
      }
    });

    test('tracks independent SOCs across timesteps', () {
      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(id: 'big', label: 'Big', peakKw: 6.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'main'),
        ],
        inverters: const [Inverter(id: 'main', label: 'Main', maxAcKw: 10.0)],
        batteries: const [
          BatteryConfig(id: 'a', capacityKwh: 3.0, maxChargeKw: 2.0, maxDischargeKw: 2.0, initialSocKwh: 0.5),
          BatteryConfig(id: 'b', capacityKwh: 4.0, maxChargeKw: 2.0, maxDischargeKw: 2.0, initialSocKwh: 3.0),
        ],
        loadProfile: const LoadProfile(dailyKwh: 10),
        startDayOfYear: 200,
        days: 1,
      ));

      for (final step in result.steps) {
        expect(step.batterySocsKwh.length, 2);
        expect(step.batterySocsKwh[0], greaterThanOrEqualTo(0));
        expect(step.batterySocsKwh[0], lessThanOrEqualTo(3.0 + 1e-9));
        expect(step.batterySocsKwh[1], greaterThanOrEqualTo(0));
        expect(step.batterySocsKwh[1], lessThanOrEqualTo(4.0 + 1e-9));
      }
      expect(result.summary.finalBatterySocsKwh.length, 2);
    });

    test('handles empty battery list', () {
      final result = const PvSimulator().run(SimulationConfig(
        arrays: const [
          PvArray(id: 'a', label: 'A', peakKw: 3.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'main'),
        ],
        inverters: const [Inverter(id: 'main', label: 'Main', maxAcKw: 5.0)],
        loadProfile: const LoadProfile(dailyKwh: 5),
        startDayOfYear: 172,
        days: 1,
      ));

      for (final step in result.steps) {
        expect(step.batterySocsKwh, isEmpty);
        expect(step.batteryChargesKwh, isEmpty);
        expect(step.batteryDischargesKwh, isEmpty);
        expect(step.batterySocKwh, 0);
      }
      expect(result.summary.finalBatterySocsKwh, isEmpty);
    });

    test('rejects duplicate battery ids', () {
      expect(
        () => const PvSimulator().run(SimulationConfig(
          arrays: const [
            PvArray(id: 'a', label: 'A', peakKw: 1.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'main'),
          ],
          inverters: const [Inverter(id: 'main', label: 'Main', maxAcKw: 1.0)],
          batteries: const [
            BatteryConfig(id: 'same', capacityKwh: 1.0, maxChargeKw: 1.0, maxDischargeKw: 1.0),
            BatteryConfig(id: 'same', capacityKwh: 1.0, maxChargeKw: 1.0, maxDischargeKw: 1.0),
          ],
          loadProfile: const LoadProfile(dailyKwh: 1),
          days: 1,
        )),
        throwsArgumentError,
      );
    });

    test('rejects whitespace-only battery id', () {
      expect(
        () => const BatteryConfig(id: '   ', capacityKwh: 1, maxChargeKw: 1, maxDischargeKw: 1).validate(),
        throwsArgumentError,
      );
    });

    test('rejects initialSocKwh outside [minSocKwh, capacityKwh]', () {
      expect(
        () => const BatteryConfig(
          id: 'b', capacityKwh: 5, maxChargeKw: 1, maxDischargeKw: 1,
          minSocKwh: 1.0, initialSocKwh: 0.5,
        ).validate(),
        throwsArgumentError,
        reason: 'below minSocKwh',
      );
      expect(
        () => const BatteryConfig(
          id: 'b', capacityKwh: 5, maxChargeKw: 1, maxDischargeKw: 1, initialSocKwh: 6.0,
        ).validate(),
        throwsArgumentError,
        reason: 'above capacityKwh',
      );
      // null and in-range values both pass.
      const BatteryConfig(id: 'b', capacityKwh: 5, maxChargeKw: 1, maxDischargeKw: 1).validate();
      const BatteryConfig(
        id: 'b', capacityKwh: 5, maxChargeKw: 1, maxDischargeKw: 1, initialSocKwh: 2.0,
      ).validate();
    });

    test('BatteryConfig.fromJson trims surrounding whitespace on the id', () {
      final decoded = BatteryConfig.fromJson({
        'id': '  primary  ',
        'capacityKwh': 5.0, 'maxChargeKw': 2.0, 'maxDischargeKw': 2.0,
      });
      expect(decoded.id, 'primary');
    });
  });
}
