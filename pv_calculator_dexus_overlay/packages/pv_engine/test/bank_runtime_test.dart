import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

/// Phase 6: ConstantFeed24h / TimeWindowFeed + runtime/coverage
/// aggregation. These tests pin the contract for two end-user-visible
/// behaviours from PRD §8.3 ("Bei leerem Speicher werden 24h-Ausgaenge
/// korrekt reduziert oder abgeschaltet") and PRD §8.1 ("Charts: …
/// Laufzeit der 24h-Ausgaenge").
SimulationConfig _config({
  required List<BatteryConfig> batteries,
  required LoadProfile load,
  required double peakKw,
  DispatchPolicy? policy,
  List<MicroInverterBank> banks = const [],
  int days = 1,
  int startDay = 172,
}) =>
    SimulationConfig(
      arrays: [
        PvArray(id: 'a1', label: 'A', peakKw: peakKw, azimuthDeg: 180, tiltDeg: 35, inverterId: 'inv'),
      ],
      inverters: const [Inverter(id: 'inv', label: 'Inv', maxAcKw: 100.0)],
      batteries: batteries,
      microInverterBanks: banks,
      dispatchPolicy: policy,
      loadProfile: load,
      startDayOfYear: startDay,
      days: days,
    );

void main() {
  group('Empty-storage shutdown (PRD §8.3 acceptance)', () {
    test('battery sitting at minSoc delivers zero, every step is shortfall', () {
      // Battery starts at its floor and cannot charge — synthetic PV is
      // nominally near zero but `maxChargeKw: 0` makes the test
      // independent of the synthetic model's exact behaviour, so every
      // step must report 0 delivery and full shortfall.
      final result = const PvSimulator().run(_config(
        batteries: const [
          BatteryConfig(
            id: 'b1',
            capacityKwh: 5.0,
            maxChargeKw: 0.0,
            maxDischargeKw: 5.0,
            minSocKwh: 1.0,
            initialSocKwh: 1.0,
          ),
        ],
        load: const LoadProfile(dailyKwh: 0),
        peakKw: 0.001, // negligible PV; charging is disabled anyway
        policy: const ConstantFeed24hPolicy(),
        banks: const [
          MicroInverterBank(
            id: 'bank-1',
            batteryId: 'b1',
            count: 1,
            unitRatedPowerW: 800,
            // 0 shutdown floor: the only reason delivery is zero is the
            // empty-usable-storage check inside the router, not the
            // minSocShutdown gate.
            minSocShutdown: 0.0,
            inverterEfficiency: 1.0,
          ),
        ],
      ));
      expect(result.summary.microInverterDeliveredKwh, closeTo(0.0, 1e-9),
          reason: 'usable storage is empty, no AC can leave the bank');
      expect(result.summary.microInverterShortfallKwh, greaterThan(0.0));
      // SOC must not dip below minSocKwh.
      for (final step in result.steps) {
        expect(step.batterySocsKwh[0], greaterThanOrEqualTo(1.0 - 1e-9));
        expect(step.microInverterDeliveredKwh, closeTo(0.0, 1e-9));
      }
    });

    test('minSocShutdown above current SOC keeps the bank silent', () {
      // Capacity 5 kWh, current SOC 1 kWh → SOC fraction 0.2 ≤ shutdown
      // 0.5 → the gate refuses every step regardless of available
      // discharge headroom.
      final result = const PvSimulator().run(_config(
        batteries: const [
          BatteryConfig(
            id: 'b1',
            capacityKwh: 5.0,
            maxChargeKw: 5.0,
            maxDischargeKw: 5.0,
            initialSocKwh: 1.0,
          ),
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
            minSocShutdown: 0.5,
            inverterEfficiency: 1.0,
          ),
        ],
      ));
      expect(result.summary.microInverterDeliveredKwh, closeTo(0.0, 1e-9));
      expect(result.summary.microInverterShortfallKwh, greaterThan(0.0));
    });
  });

  group('TimeWindowFeed schedule fidelity (PRD §8.3)', () {
    test('window wrapping midnight delivers at night, idle by day', () {
      final result = const PvSimulator().run(_config(
        batteries: const [
          // Big enough that the night window cannot drain it.
          BatteryConfig(
            id: 'b1',
            capacityKwh: 50.0,
            maxChargeKw: 5.0,
            maxDischargeKw: 5.0,
            initialSocKwh: 50.0,
          ),
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
            schedule: TimeWindowSchedule([
              // 22:00–06:00 wraps midnight.
              TimeWindow(startHour: 22, endHour: 6),
            ]),
          ),
        ],
      ));
      for (final step in result.steps) {
        final h = step.hourOfDay;
        final inWindow = h >= 22.0 || h < 6.0;
        if (inWindow) {
          expect(step.microInverterDeliveredKwh, greaterThan(0),
              reason: 'expected delivery at hour $h (inside wrapped window)');
        } else {
          expect(step.microInverterDeliveredKwh, closeTo(0.0, 1e-9),
              reason: 'expected silence at hour $h (outside wrapped window)');
        }
      }
    });

    test('hourly schedule respects partial factors', () {
      // 50 % between 10:00 and 12:00, off elsewhere — picks up exactly
      // half of the unit power during those two hours.
      final factors = List<double>.filled(24, 0.0);
      factors[10] = 0.5;
      factors[11] = 0.5;
      final result = const PvSimulator().run(_config(
        batteries: const [
          BatteryConfig(
            id: 'b1',
            capacityKwh: 50.0,
            maxChargeKw: 5.0,
            maxDischargeKw: 5.0,
            initialSocKwh: 50.0,
          ),
        ],
        load: const LoadProfile(dailyKwh: 0),
        peakKw: 0.001,
        policy: const TimeWindowFeedPolicy(),
        banks: [
          MicroInverterBank(
            id: 'bank-1',
            batteryId: 'b1',
            count: 1,
            unitRatedPowerW: 800,
            minSocShutdown: 0.0,
            inverterEfficiency: 1.0,
            schedule: HourlySchedule(factors),
          ),
        ],
      ));
      final hour10 = result.steps.firstWhere((s) => s.hourOfDay >= 10.0 && s.hourOfDay < 11.0);
      // 0.5 factor × 800 W × 1 h = 0.4 kWh.
      expect(hour10.microInverterDeliveredKwh, closeTo(0.4, 1e-3));
      final hour15 = result.steps.firstWhere((s) => s.hourOfDay >= 15.0 && s.hourOfDay < 16.0);
      expect(hour15.microInverterDeliveredKwh, closeTo(0.0, 1e-9));
    });
  });

  group('SummaryAggregator.bankRuntime', () {
    test('reconstructs target from delivered + shortfall and tallies active hours', () {
      final result = const PvSimulator().run(_config(
        batteries: const [
          BatteryConfig(
            id: 'b1',
            capacityKwh: 50.0,
            maxChargeKw: 5.0,
            maxDischargeKw: 5.0,
            initialSocKwh: 50.0,
          ),
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
      final stats = SummaryAggregator.bankRuntime(
        result.steps,
        bankCount: 1,
        timeStep: TimeStep.hourly,
      );
      expect(stats, hasLength(1));
      final bank = stats.first;
      // Target reconstructed via delivered + shortfall must match the
      // engine summary — same invariant the chart uses to label "% of
      // target met".
      expect(bank.targetKwh, closeTo(bank.deliveredKwh + bank.shortfallKwh, 1e-9));
      // 4-hour window, 1 day → 4 active hours and full delivery (battery
      // had plenty of juice).
      expect(bank.scheduledHours, closeTo(4.0, 1e-9));
      expect(bank.activeHours, closeTo(4.0, 1e-9));
      expect(bank.fullDeliveryHours, closeTo(4.0, 1e-9));
      expect(bank.coverageRate, closeTo(1.0, 1e-6));
    });

    test('returns an empty list when bankCount is zero', () {
      final result = const PvSimulator().run(_config(
        batteries: const [],
        load: const LoadProfile(dailyKwh: 5),
        peakKw: 0.5,
      ));
      expect(
        SummaryAggregator.bankRuntime(
          result.steps,
          bankCount: 0,
          timeStep: TimeStep.hourly,
        ),
        isEmpty,
      );
    });
  });

  group('Partial-shortfall accounting', () {
    test('rate-capped bank reports fullDeliveryHours below activeHours', () {
      // Two 800 W banks share one battery rated at 1 kW discharge. Each
      // bank wants 0.8 kWh per step but only 0.5 kWh is left per step
      // for the second bank after the first saturates, so every step
      // is *active* yet *not fully covered* for bank-b.
      final result = const PvSimulator().run(_config(
        batteries: const [
          BatteryConfig(
            id: 'b1',
            capacityKwh: 50.0,
            maxChargeKw: 5.0,
            maxDischargeKw: 1.0,
            initialSocKwh: 50.0,
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
      final runtime = SummaryAggregator.bankRuntime(
        result.steps,
        bankCount: 2,
        timeStep: TimeStep.hourly,
      );
      // bank-a gets its full 0.8 kWh every step → fullDeliveryHours == scheduledHours.
      expect(runtime[0].fullDeliveryHours, closeTo(runtime[0].scheduledHours, 1e-9));
      // bank-b is rate-capped to 0.2 kWh per step → still active every
      // step but never *fully* delivers; the chart must therefore split
      // partial vs. full to show the residual shortfall.
      expect(runtime[1].activeHours, closeTo(runtime[1].scheduledHours, 1e-9));
      expect(runtime[1].fullDeliveryHours, closeTo(0.0, 1e-9));
      expect(runtime[1].shortfallKwh, greaterThan(0));

      // Same split must propagate into the per-day series the chart
      // actually plots.
      final dailyA = SummaryAggregator.bankDaily(
        result.steps,
        bankIndex: 0,
        timeStep: TimeStep.hourly,
      );
      final dailyB = SummaryAggregator.bankDaily(
        result.steps,
        bankIndex: 1,
        timeStep: TimeStep.hourly,
      );
      final activeDayA = dailyA[171];
      final activeDayB = dailyB[171];
      expect(activeDayA.fullDeliveryHours, closeTo(activeDayA.scheduledHours, 1e-9));
      expect(activeDayB.activeHours, closeTo(activeDayB.scheduledHours, 1e-9));
      expect(activeDayB.fullDeliveryHours, closeTo(0.0, 1e-9));
    });
  });

  group('SummaryAggregator.bankDaily', () {
    test('puts delivery into the right day-of-year slot, zero elsewhere', () {
      final result = const PvSimulator().run(_config(
        batteries: const [
          BatteryConfig(
            id: 'b1',
            capacityKwh: 50.0,
            maxChargeKw: 5.0,
            maxDischargeKw: 5.0,
            initialSocKwh: 50.0,
          ),
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
            minSocShutdown: 0.0,
            inverterEfficiency: 1.0,
          ),
        ],
        // Day 172 (summer solstice) — see _config default.
        days: 1,
      ));
      final daily = SummaryAggregator.bankDaily(
        result.steps,
        bankIndex: 0,
        timeStep: TimeStep.hourly,
      );
      expect(daily, hasLength(365));
      // The simulated day is dayOfYear 172 → index 171.
      expect(daily[171].activeHours, closeTo(24.0, 1e-9));
      expect(daily[171].deliveredKwh, greaterThan(0));
      // Every other day must be zero — the simulator only walked one day.
      for (var i = 0; i < 365; i++) {
        if (i == 171) continue;
        expect(daily[i].activeHours, 0.0, reason: 'day index $i should be empty');
        expect(daily[i].deliveredKwh, 0.0);
        expect(daily[i].shortfallKwh, 0.0);
      }
    });
  });
}
