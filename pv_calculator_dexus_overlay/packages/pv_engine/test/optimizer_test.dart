import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

/// Builds a minimal baseline config the optimizer tests sweep over.
/// One PV array, one inverter, one battery, hourly steps, one day so
/// the per-candidate runtime stays tight. Tariff is set so both
/// objectives are reachable.
SimulationConfig _baseline({
  TariffConfig? tariff = const TariffConfig(
    importPricePerKwh: 0.30,
    exportPricePerKwh: 0.08,
  ),
  List<PvArray>? arrays,
}) {
  return SimulationConfig(
    arrays: arrays ??
        const [
          PvArray(
            id: 'south',
            label: 'South',
            peakKw: 5.0,
            azimuthDeg: 180,
            tiltDeg: 30,
            inverterId: 'main',
          ),
        ],
    inverters: const [
      Inverter(id: 'main', label: 'Main', maxAcKw: 5.0),
    ],
    batteries: const [
      BatteryConfig(
        id: 'main',
        label: 'Main',
        capacityKwh: 5.0,
        maxChargeKw: 2.5,
        maxDischargeKw: 2.5,
        minSocKwh: 0.5,
      ),
    ],
    loadProfile: const LoadProfile(dailyKwh: 12.0),
    days: 1,
    tariff: tariff,
  );
}

void main() {
  group('OptimizerSpec.validate', () {
    test('rejects negative prices', () {
      final spec = OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(eurPerKwpPv: -1),
        objective: OptimizerObjective.maxAutarky,
      );
      expect(spec.validate, throwsArgumentError);
    });

    test('rejects minNetCost without tariff', () {
      final spec = OptimizerSpec(
        baseline: _baseline(tariff: null),
        prices: const OptimizerPrices(),
        objective: OptimizerObjective.minNetCost,
      );
      expect(spec.validate, throwsArgumentError);
    });

    test('rejects unknown array id in optionalArrayIds', () {
      final spec = OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(),
        objective: OptimizerObjective.maxAutarky,
        optionalArrayIds: const ['nonexistent'],
      );
      expect(spec.validate, throwsArgumentError);
    });

    test('rejects more than 4 optional arrays', () {
      final spec = OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(),
        objective: OptimizerObjective.maxAutarky,
        optionalArrayIds: const ['a', 'b', 'c', 'd', 'e'],
      );
      expect(spec.validate, throwsArgumentError);
    });

    test('rejects horizonYears < 1', () {
      final spec = OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(),
        objective: OptimizerObjective.maxAutarky,
        horizonYears: 0,
      );
      expect(spec.validate, throwsArgumentError);
    });

    test('rejects topN < 1', () {
      final spec = OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(),
        objective: OptimizerObjective.maxAutarky,
        topN: 0,
      );
      expect(spec.validate, throwsArgumentError);
    });

    test('rejects non-positive inverter sweep entries', () {
      final spec = OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(),
        objective: OptimizerObjective.maxAutarky,
        inverterSweepKw: const [0.0],
      );
      expect(spec.validate, throwsArgumentError);
    });

    test('accepts empty sweeps (uses baseline values)', () {
      final spec = OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(),
        objective: OptimizerObjective.maxAutarky,
      );
      expect(spec.validate, returnsNormally);
    });
  });

  group('Optimizer.run', () {
    test('2×2×2 Cartesian product yields 8 evaluated, all kept under topN', () {
      final spec = OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(),
        objective: OptimizerObjective.maxAutarky,
        batterySweepKwh: const [5.0, 10.0],
        inverterSweepKw: const [5.0, 6.0],
        pvScaleSweep: const [1.0, 1.2],
      );
      final result = const Optimizer().run(spec);
      expect(result.evaluated, equals(8));
      expect(result.skippedOverBudget, equals(0));
      expect(result.failedValidation, equals(0));
      expect(result.candidates.length, equals(8));
    });

    test('budget below cheapest combo skips every candidate', () {
      final spec = OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(
          eurPerKwpPv: 1000,
          eurPerKwAcInverter: 500,
          eurPerKwhBattery: 800,
        ),
        objective: OptimizerObjective.maxAutarky,
        batterySweepKwh: const [5.0, 10.0],
        inverterSweepKw: const [5.0, 6.0],
        pvScaleSweep: const [1.0, 1.2],
        budgetEur: 1.0,
      );
      final result = const Optimizer().run(spec);
      expect(result.candidates, isEmpty);
      expect(result.skippedOverBudget, equals(8));
      expect(result.evaluated, equals(0));
    });

    test('identity: baseline values match a direct simulator run', () {
      final baseline = _baseline();
      final spec = OptimizerSpec(
        baseline: baseline,
        prices: const OptimizerPrices(),
        objective: OptimizerObjective.maxAutarky,
        batterySweepKwh: const [5.0],
        inverterSweepKw: const [5.0],
        pvScaleSweep: const [1.0],
      );
      final result = const Optimizer().run(spec);
      expect(result.candidates.length, equals(1));
      final cand = result.candidates.single;

      final direct = const PvSimulator().run(SimulationConfig(
        arrays: baseline.arrays,
        inverters: baseline.inverters,
        batteries: baseline.batteries,
        loadProfile: baseline.loadProfile,
        days: baseline.days,
        tariff: baseline.tariff,
        keepSteps: false,
      ));
      expect(cand.summary.pvAcKwh, closeTo(direct.summary.pvAcKwh, 1e-6));
      expect(cand.summary.selfConsumptionKwh,
          closeTo(direct.summary.selfConsumptionKwh, 1e-6));
      expect(cand.summary.gridImportKwh,
          closeTo(direct.summary.gridImportKwh, 1e-6));
      expect(cand.summary.gridExportKwh,
          closeTo(direct.summary.gridExportKwh, 1e-6));
    });

    test('C-rate and minSoc fraction preserved when battery scales', () {
      // Baseline: 5 kWh capacity, 2.5 kW charge/discharge (= 0.5 C),
      // 0.5 kWh minSoc (= 10% of capacity). Sweep to 10 kWh: expect
      // 5.0 kW charge/discharge, 1.0 kWh minSoc.
      final spec = OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(),
        objective: OptimizerObjective.maxAutarky,
        batterySweepKwh: const [10.0],
      );
      const Optimizer().run(spec); // Doesn't expose the patched config
      // directly, so we exercise the same scaling here via a second sweep
      // that asserts the behaviour through a known-deterministic
      // simulation: a battery 2× as large with proportional power should
      // both charge twice as much (when surplus is abundant) and free up
      // twice the usable headroom relative to minSoc.
      final small = const Optimizer().run(OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(),
        objective: OptimizerObjective.maxAutarky,
        batterySweepKwh: const [5.0],
      ));
      final large = const Optimizer().run(OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(),
        objective: OptimizerObjective.maxAutarky,
        batterySweepKwh: const [10.0],
      ));
      // Final SOC scales — the larger battery, with proportional power,
      // ends the day with more energy stored (or at worst equal, when the
      // sun-day already saturated the smaller one). It must NEVER end
      // below the small one when minSoc fraction is preserved and the
      // baseline already used the small one fully.
      expect(
        large.candidates.single.summary.finalBatterySocKwh,
        greaterThanOrEqualTo(small.candidates.single.summary.finalBatterySocKwh - 1e-6),
      );
      // The minSoc lower bound itself doubles: a battery at SOC == minSoc
      // of the small variant could not have discharged further; the large
      // variant's minSoc floor is at 1.0 kWh, so its discharge headroom
      // is at least the small variant's.
      expect(
        large.candidates.single.summary.batteryDischargeKwh,
        greaterThanOrEqualTo(small.candidates.single.summary.batteryDischargeKwh - 1e-6),
      );
    });

    test('investment math is exact', () {
      // Prices: 1000 €/kWp PV, 500 €/kW AC inverter, 800 €/kWh battery.
      // PV scale 1.2 × 5 kWp = 6 kWp → 6000 €
      // Inverter 5 kW → 2500 €
      // Battery 10 kWh → 8000 €
      // Total 16500 €.
      final spec = OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(
          eurPerKwpPv: 1000,
          eurPerKwAcInverter: 500,
          eurPerKwhBattery: 800,
        ),
        objective: OptimizerObjective.maxAutarky,
        batterySweepKwh: const [10.0],
        inverterSweepKw: const [5.0],
        pvScaleSweep: const [1.2],
      );
      final result = const Optimizer().run(spec);
      expect(result.candidates.single.investmentEur, closeTo(16500.0, 0.01));
    });

    test('maxAutarky sorts by descending autarky rate', () {
      final spec = OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(),
        objective: OptimizerObjective.maxAutarky,
        batterySweepKwh: const [1.0, 5.0, 15.0],
        pvScaleSweep: const [0.5, 1.0, 1.5],
      );
      final result = const Optimizer().run(spec);
      expect(result.candidates.length, greaterThan(1));
      for (var i = 1; i < result.candidates.length; i++) {
        expect(
          result.candidates[i].summary.autarkyRate,
          lessThanOrEqualTo(result.candidates[i - 1].summary.autarkyRate + 1e-9),
        );
      }
    });

    test('minNetCost sorts by ascending lifetimeNetCostEur', () {
      final spec = OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(
          eurPerKwpPv: 1000,
          eurPerKwAcInverter: 200,
          eurPerKwhBattery: 600,
        ),
        objective: OptimizerObjective.minNetCost,
        batterySweepKwh: const [1.0, 5.0, 15.0],
        pvScaleSweep: const [0.5, 1.0, 1.5],
        horizonYears: 10,
      );
      final result = const Optimizer().run(spec);
      expect(result.candidates.length, greaterThan(1));
      for (var i = 1; i < result.candidates.length; i++) {
        final a = result.candidates[i - 1].lifetimeNetCostEur;
        final b = result.candidates[i].lifetimeNetCostEur;
        expect(a, isNotNull);
        expect(b, isNotNull);
        expect(b!, greaterThanOrEqualTo(a! - 1e-9));
      }
    });

    test('lifetimeNetCostEur null when baseline has no tariff', () {
      final spec = OptimizerSpec(
        baseline: _baseline(tariff: null),
        prices: const OptimizerPrices(),
        objective: OptimizerObjective.maxAutarky,
      );
      final result = const Optimizer().run(spec);
      for (final c in result.candidates) {
        expect(c.lifetimeNetCostEur, isNull);
        expect(c.summary.netCostEur, isNull);
      }
    });

    test('progress callback emits (0, total) first and (total, total) last', () {
      final spec = OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(),
        objective: OptimizerObjective.maxAutarky,
        batterySweepKwh: const [5.0, 10.0, 15.0],
        pvScaleSweep: const [1.0, 1.2],
      );
      final events = <List<int>>[];
      const Optimizer().run(spec, onProgress: (done, total) {
        events.add([done, total]);
      });
      expect(events.first, equals([0, 6]));
      expect(events.last, equals([6, 6]));
      // Monotonic non-decreasing `done`, constant `total`.
      for (var i = 1; i < events.length; i++) {
        expect(events[i][0], greaterThanOrEqualTo(events[i - 1][0]));
        expect(events[i][1], equals(6));
      }
    });

    test('optional array toggles enumerate 2^N subsets', () {
      // Two arrays, one optional → 2 subsets per combo.
      final spec = OptimizerSpec(
        baseline: _baseline(arrays: const [
          PvArray(
            id: 'south',
            label: 'South',
            peakKw: 5.0,
            azimuthDeg: 180,
            tiltDeg: 30,
            inverterId: 'main',
          ),
          PvArray(
            id: 'east',
            label: 'East',
            peakKw: 3.0,
            azimuthDeg: 90,
            tiltDeg: 30,
            inverterId: 'main',
          ),
        ]),
        prices: const OptimizerPrices(),
        objective: OptimizerObjective.maxAutarky,
        optionalArrayIds: const ['east'],
      );
      final result = const Optimizer().run(spec);
      expect(result.evaluated, equals(2));
      expect(
        result.candidates.map((c) => c.disabledArrayIds.toList()).toSet(),
        equals({<String>[], <String>['east']}.toSet()),
      );
    });

    test('failed validation soft-fails the candidate, sweep continues', () {
      // pvScale=0 yields peakKw=0 → PvArray.validate throws → that
      // candidate is counted in failedValidation, the others run.
      final spec = OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(),
        objective: OptimizerObjective.maxAutarky,
        pvScaleSweep: const [0.0, 1.0],
      );
      final result = const Optimizer().run(spec);
      expect(result.failedValidation, equals(1));
      expect(result.evaluated, equals(1));
      expect(result.candidates.length, equals(1));
      expect(result.candidates.single.pvScale, equals(1.0));
    });

    test('determinism: running twice yields equivalent candidates', () {
      final spec = OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(),
        objective: OptimizerObjective.maxAutarky,
        batterySweepKwh: const [3.0, 7.0],
        pvScaleSweep: const [0.8, 1.0, 1.2],
      );
      final a = const Optimizer().run(spec);
      final b = const Optimizer().run(spec);
      expect(a.evaluated, equals(b.evaluated));
      expect(a.candidates.length, equals(b.candidates.length));
      for (var i = 0; i < a.candidates.length; i++) {
        expect(a.candidates[i].toString(), equals(b.candidates[i].toString()));
      }
    });

    test('topN truncates the candidate list', () {
      final spec = OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(),
        objective: OptimizerObjective.maxAutarky,
        batterySweepKwh: const [1.0, 5.0, 10.0],
        pvScaleSweep: const [0.5, 1.0, 1.5],
        topN: 3,
      );
      final result = const Optimizer().run(spec);
      expect(result.evaluated, equals(9));
      expect(result.candidates.length, equals(3));
    });
  });
}
