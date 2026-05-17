import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

/// Tiny single-array + single-inverter + single-battery scaffold so the
/// golden scenarios stay readable.
SimulationConfig _config({
  required List<BatteryConfig> batteries,
  required LoadProfile load,
  required double peakKw,
  DispatchPolicy? policy,
  List<MicroInverterBank> banks = const [],
  double? exportLimitKw,
  int days = 1,
  int startDay = 172, // summer solstice for guaranteed PV
}) => SimulationConfig(
      arrays: [
        PvArray(id: 'a1', label: 'A', peakKw: peakKw, azimuthDeg: 180, tiltDeg: 35, inverterId: 'inv'),
      ],
      inverters: const [Inverter(id: 'inv', label: 'Inv', maxAcKw: 100.0)],
      batteries: batteries,
      microInverterBanks: banks,
      dispatchPolicy: policy,
      loadProfile: load,
      gridExportLimitKw: exportLimitKw,
      startDayOfYear: startDay,
      days: days,
    );

void main() {
  group('SelfConsumptionFirstPolicy (legacy regression)', () {
    test('produces the same summary numbers as the implicit default', () {
      final explicit = const PvSimulator().run(_config(
        batteries: const [
          BatteryConfig(id: 'b1', capacityKwh: 5.0, maxChargeKw: 3.0, maxDischargeKw: 3.0, initialSocKwh: 0.0),
        ],
        load: const LoadProfile(dailyKwh: 8),
        peakKw: 4.0,
        policy: const SelfConsumptionFirstPolicy(),
      ));
      final implicit = const PvSimulator().run(_config(
        batteries: const [
          BatteryConfig(id: 'b1', capacityKwh: 5.0, maxChargeKw: 3.0, maxDischargeKw: 3.0, initialSocKwh: 0.0),
        ],
        load: const LoadProfile(dailyKwh: 8),
        peakKw: 4.0,
      ));
      expect(explicit.summary.pvAcKwh, closeTo(implicit.summary.pvAcKwh, 1e-9));
      expect(explicit.summary.selfConsumptionKwh, closeTo(implicit.summary.selfConsumptionKwh, 1e-9));
      expect(explicit.summary.batteryChargeKwh, closeTo(implicit.summary.batteryChargeKwh, 1e-9));
      expect(explicit.summary.batteryDischargeKwh, closeTo(implicit.summary.batteryDischargeKwh, 1e-9));
      expect(explicit.summary.gridImportKwh, closeTo(implicit.summary.gridImportKwh, 1e-9));
      expect(explicit.summary.gridExportKwh, closeTo(implicit.summary.gridExportKwh, 1e-9));
    });
  });

  group('BatteryReservePolicy', () {
    test('charging stops once SOC reaches reserve ceiling', () {
      final result = const PvSimulator().run(_config(
        batteries: const [
          BatteryConfig(id: 'b1', capacityKwh: 4.0, maxChargeKw: 5.0, maxDischargeKw: 5.0, initialSocKwh: 0.0),
        ],
        load: const LoadProfile(dailyKwh: 0), // pure export scenario
        peakKw: 8.0,
        policy: const BatteryReservePolicy(reserveSocFraction: 0.5),
      ));
      // capacity 4 kWh × 0.5 = 2.0 kWh ceiling.
      for (final step in result.steps) {
        expect(step.batterySocsKwh[0], lessThanOrEqualTo(2.0 + 1e-6),
            reason: 'SOC must not exceed reserve ceiling under BatteryReservePolicy');
      }
      // The battery should reach the ceiling.
      expect(result.steps.map((s) => s.batterySocsKwh[0]).reduce((a, b) => a > b ? a : b),
          closeTo(2.0, 1e-3));
      // Surplus that would have charged past the ceiling is exported instead.
      expect(result.summary.gridExportKwh, greaterThan(0));
    });

    test('reserveSocFraction = 1.0 is equivalent to SelfConsumptionFirst', () {
      final reserve = const PvSimulator().run(_config(
        batteries: const [
          BatteryConfig(id: 'b1', capacityKwh: 4.0, maxChargeKw: 5.0, maxDischargeKw: 5.0, initialSocKwh: 0.0),
        ],
        load: const LoadProfile(dailyKwh: 2),
        peakKw: 4.0,
        policy: const BatteryReservePolicy(reserveSocFraction: 1.0),
      ));
      final base = const PvSimulator().run(_config(
        batteries: const [
          BatteryConfig(id: 'b1', capacityKwh: 4.0, maxChargeKw: 5.0, maxDischargeKw: 5.0, initialSocKwh: 0.0),
        ],
        load: const LoadProfile(dailyKwh: 2),
        peakKw: 4.0,
      ));
      expect(reserve.summary.batteryChargeKwh, closeTo(base.summary.batteryChargeKwh, 1e-9));
      expect(reserve.summary.gridExportKwh, closeTo(base.summary.gridExportKwh, 1e-9));
    });
  });

  group('ConstantFeed24hPolicy', () {
    test('bank delivers continuously and shortfall accrues when battery empties', () {
      final result = const PvSimulator().run(_config(
        batteries: const [
          // Tiny battery so it empties partway through the day.
          BatteryConfig(id: 'b1', capacityKwh: 1.0, maxChargeKw: 5.0, maxDischargeKw: 5.0, initialSocKwh: 1.0),
        ],
        load: const LoadProfile(dailyKwh: 0),
        peakKw: 0.001, // no PV recharging
        policy: const ConstantFeed24hPolicy(),
        banks: const [
          MicroInverterBank(
            id: 'bank-1',
            batteryId: 'b1',
            count: 1,
            unitRatedPowerW: 800,
            minSocShutdown: 0.0,
            inverterEfficiency: 1.0,
          ),
        ],
      ));
      // Some delivery occurred.
      expect(result.summary.microInverterDeliveredKwh, greaterThan(0));
      // Battery is much smaller than 800 W × 24 h = 19.2 kWh, so the
      // bank must hit shortfall once the battery empties.
      expect(result.summary.microInverterShortfallKwh, greaterThan(0));
      // SOC stays non-negative.
      for (final step in result.steps) {
        expect(step.batterySocsKwh[0], greaterThanOrEqualTo(-1e-9));
      }
    });

    test('SOC shutdown stops further delivery once threshold is crossed', () {
      const shutdownFrac = 0.5;
      const capacity = 5.0;
      final result = const PvSimulator().run(_config(
        batteries: const [
          BatteryConfig(id: 'b1', capacityKwh: capacity, maxChargeKw: 5.0, maxDischargeKw: 5.0, initialSocKwh: capacity),
        ],
        load: const LoadProfile(dailyKwh: 0),
        peakKw: 0.001,
        policy: const ConstantFeed24hPolicy(),
        banks: const [
          MicroInverterBank(
            id: 'bank-1',
            batteryId: 'b1',
            count: 1,
            unitRatedPowerW: 800,
            minSocShutdown: shutdownFrac,
            inverterEfficiency: 1.0,
          ),
        ],
      ));
      // Once a step starts with SOC ≤ threshold, no further AC must
      // be delivered. (Inside a step the gate is a per-step check, so
      // the *transition* step may still deliver before the SOC drops
      // past the threshold — that's expected.)
      const threshold = shutdownFrac * capacity;
      var shutdownEngaged = false;
      for (final step in result.steps) {
        if (shutdownEngaged) {
          expect(step.microInverterDeliveredKwh, lessThan(1e-9),
              reason: 'delivery should be 0 after SOC dropped past $threshold (was ${step.batterySocsKwh[0]})');
        }
        if (step.batterySocsKwh[0] <= threshold) {
          shutdownEngaged = true;
        }
      }
      // Final SOC stays at most one full step below the threshold.
      // 800 W × 1 h / discharge eta (~0.949) ≈ 0.843 kWh per step.
      expect(result.summary.finalBatterySocsKwh[0], greaterThanOrEqualTo(threshold - 0.9));
    });
  });

  group('TimeWindowFeedPolicy', () {
    test('bank only delivers inside its time window', () {
      final result = const PvSimulator().run(_config(
        batteries: const [
          BatteryConfig(id: 'b1', capacityKwh: 5.0, maxChargeKw: 5.0, maxDischargeKw: 5.0, initialSocKwh: 5.0),
        ],
        load: const LoadProfile(dailyKwh: 0),
        peakKw: 0.001,
        policy: const TimeWindowFeedPolicy(),
        banks: const [
          MicroInverterBank(
            id: 'bank-1',
            batteryId: 'b1',
            count: 1,
            unitRatedPowerW: 800,
            minSocShutdown: 0.0,
            inverterEfficiency: 1.0,
            schedule: TimeWindowSchedule([TimeWindow(startHour: 18, endHour: 22)]),
          ),
        ],
      ));
      for (final step in result.steps) {
        final delivered = step.microInverterDeliveredKwh;
        if (step.hourOfDay >= 18.0 && step.hourOfDay < 22.0) {
          // Inside the window: nonzero delivery (battery has charge).
          expect(delivered, greaterThan(0), reason: 'expected delivery at hour ${step.hourOfDay}');
        } else {
          expect(delivered, lessThan(1e-9), reason: 'expected no delivery at hour ${step.hourOfDay}');
        }
      }
    });
  });

  group('GridAssistPolicy', () {
    test('without import: unserved load accrues instead of grid import', () {
      final result = const PvSimulator().run(_config(
        batteries: const [],
        load: const LoadProfile(dailyKwh: 12),
        peakKw: 0.001, // negligible PV → load goes unmet
        policy: const GridAssistPolicy(allowGridImport: false),
        startDay: 355, // winter, minimal PV
      ));
      expect(result.summary.gridImportKwh, closeTo(0.0, 1e-9));
      expect(result.summary.unservedLoadKwh, greaterThan(0.0));
    });

    test('with import: behaves like the inner policy', () {
      final assist = const PvSimulator().run(_config(
        batteries: const [],
        load: const LoadProfile(dailyKwh: 12),
        peakKw: 0.001,
        policy: const GridAssistPolicy(allowGridImport: true),
        startDay: 355,
      ));
      expect(assist.summary.unservedLoadKwh, closeTo(0.0, 1e-9));
      expect(assist.summary.gridImportKwh, greaterThan(0.0));
    });
  });

  group('Shared-battery rate cap', () {
    test('two banks sharing one battery never exceed battery maxDischargeKw', () {
      // Two 800 W banks fed by one battery rated at 1.0 kW discharge.
      // Without the per-step cap, both banks would each deliver 0.8 kWh
      // in a 1-h step (1.6 kWh combined), violating the battery's rate.
      final result = const PvSimulator().run(_config(
        batteries: const [
          BatteryConfig(
            id: 'b1',
            capacityKwh: 20.0,
            maxChargeKw: 5.0,
            maxDischargeKw: 1.0,
            initialSocKwh: 20.0,
          ),
        ],
        load: const LoadProfile(dailyKwh: 0),
        peakKw: 0.001,
        policy: const ConstantFeed24hPolicy(),
        banks: const [
          MicroInverterBank(
            id: 'bank-a',
            batteryId: 'b1',
            count: 1,
            unitRatedPowerW: 800,
            minSocShutdown: 0.0,
            inverterEfficiency: 1.0,
          ),
          MicroInverterBank(
            id: 'bank-b',
            batteryId: 'b1',
            count: 1,
            unitRatedPowerW: 800,
            minSocShutdown: 0.0,
            inverterEfficiency: 1.0,
          ),
        ],
      ));
      const stepHours = 1.0;
      const rateCapAcKwh = 1.0 * stepHours;
      for (final step in result.steps) {
        // Per-battery cumulative AC discharge for this step.
        expect(
          step.batteryDischargesKwh[0],
          lessThanOrEqualTo(rateCapAcKwh + 1e-9),
          reason: 'Battery AC discharge ${step.batteryDischargesKwh[0]} '
              'exceeded cap $rateCapAcKwh at hour ${step.hourOfDay}',
        );
        // Combined bank delivery is also limited by the same cap
        // (inverterEfficiency = 1.0 here, so AC and DC coincide).
        expect(
          step.microInverterDeliveredKwh,
          lessThanOrEqualTo(rateCapAcKwh + 1e-9),
        );
      }
      // Sanity: the first bank should saturate at 0.8 kWh, the second
      // gets whatever remains under the 1.0 kWh battery cap.
      final firstStep = result.steps.first;
      expect(firstStep.microInverterDeliveriesKwh[0], closeTo(0.8, 1e-6));
      expect(firstStep.microInverterDeliveriesKwh[1], closeTo(0.2, 1e-6));
    });
  });

  group('Validation', () {
    test('rejects micro-inverter bank with unknown battery', () {
      expect(
        () => const PvSimulator().run(SimulationConfig(
          arrays: [PvArray(id: 'a', label: 'A', peakKw: 1, azimuthDeg: 180, tiltDeg: 30, inverterId: 'i')],
          inverters: [Inverter(id: 'i', label: 'I', maxAcKw: 1)],
          batteries: [BatteryConfig(id: 'real', capacityKwh: 1, maxChargeKw: 1, maxDischargeKw: 1)],
          microInverterBanks: [MicroInverterBank(id: 'bank', batteryId: 'ghost')],
          loadProfile: LoadProfile(dailyKwh: 0),
          days: 1,
        )),
        throwsArgumentError,
      );
    });

    test('rejects duplicate bank ids', () {
      expect(
        () => const PvSimulator().run(SimulationConfig(
          arrays: [PvArray(id: 'a', label: 'A', peakKw: 1, azimuthDeg: 180, tiltDeg: 30, inverterId: 'i')],
          inverters: [Inverter(id: 'i', label: 'I', maxAcKw: 1)],
          batteries: [BatteryConfig(id: 'b', capacityKwh: 1, maxChargeKw: 1, maxDischargeKw: 1)],
          microInverterBanks: [
            MicroInverterBank(id: 'dup', batteryId: 'b'),
            MicroInverterBank(id: 'dup', batteryId: 'b'),
          ],
          loadProfile: LoadProfile(dailyKwh: 0),
          days: 1,
        )),
        throwsArgumentError,
      );
    });
  });
}
