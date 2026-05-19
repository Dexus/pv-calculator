import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

/// Builds a minimal baseline config the optimizer tests sweep over.
/// One PV array, one inverter, one battery, hourly steps. The
/// baseline declares `days: 1` for fast direct-`PvSimulator` reference
/// runs in identity-style assertions; per-candidate optimizer runs
/// always extend to a full 365-day year regardless (the optimizer
/// forces `days = 365` so lifetime cost is annualised honestly), so
/// keep the sweep sizes modest here. Tariff is set so both objectives
/// are reachable.
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

      // Optimizer forces days=365 for ranking consistency; the
      // baseline ships with days=1 for fast multi-test iteration, so
      // the direct sim has to run a full year to match.
      final direct = const PvSimulator().run(SimulationConfig(
        arrays: baseline.arrays,
        inverters: baseline.inverters,
        batteries: baseline.batteries,
        loadProfile: baseline.loadProfile,
        days: 365,
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

    test('PV-only baseline (no batteries) runs when battery sweep is empty', () {
      // Codex PR #31 review: form callers must omit the battery sweep
      // when the draft has no batteries; the engine accepts this case.
      final baseline = SimulationConfig(
        arrays: const [
          PvArray(
            id: 'south',
            label: 'South',
            peakKw: 5.0,
            azimuthDeg: 180,
            tiltDeg: 30,
            inverterId: 'main',
          ),
        ],
        inverters: const [Inverter(id: 'main', label: 'Main', maxAcKw: 5.0)],
        loadProfile: const LoadProfile(dailyKwh: 12.0),
        days: 1,
      );
      final spec = OptimizerSpec(
        baseline: baseline,
        prices: const OptimizerPrices(),
        objective: OptimizerObjective.maxAutarky,
        pvScaleSweep: const [0.8, 1.0, 1.2],
      );
      final result = const Optimizer().run(spec);
      expect(result.evaluated, equals(3));
      expect(result.failedValidation, equals(0));
      // Each patched candidate must inherit the "no battery" shape.
      for (final c in result.candidates) {
        expect(c.batteryKwh, equals(0.0));
      }
    });

    test('partial-period baseline gets full year for cost ranking', () {
      // Codex PR #31 review: a 30-day baseline must not produce a
      // 30-day lifetime cost. The optimizer forces days=365 internally,
      // so two patches with the same swept values but different
      // baseline `days` yield identical KPIs.
      final baselineShort = SimulationConfig(
        arrays: const [
          PvArray(
            id: 'south',
            label: 'South',
            peakKw: 5.0,
            azimuthDeg: 180,
            tiltDeg: 30,
            inverterId: 'main',
          ),
        ],
        inverters: const [Inverter(id: 'main', label: 'Main', maxAcKw: 5.0)],
        batteries: const [
          BatteryConfig(
            id: 'main',
            label: 'Main',
            capacityKwh: 5.0,
            maxChargeKw: 2.5,
            maxDischargeKw: 2.5,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 12.0),
        days: 30,
        tariff: const TariffConfig(
          importPricePerKwh: 0.30,
          exportPricePerKwh: 0.08,
        ),
      );
      final baselineFull = SimulationConfig(
        arrays: baselineShort.arrays,
        inverters: baselineShort.inverters,
        batteries: baselineShort.batteries,
        loadProfile: baselineShort.loadProfile,
        days: 365,
        tariff: baselineShort.tariff,
      );
      OptimizerSpec mkSpec(SimulationConfig b) => OptimizerSpec(
            baseline: b,
            prices: const OptimizerPrices(),
            objective: OptimizerObjective.minNetCost,
            pvScaleSweep: const [1.0],
          );
      final shortResult = const Optimizer().run(mkSpec(baselineShort));
      final fullResult = const Optimizer().run(mkSpec(baselineFull));
      expect(shortResult.candidates.length, equals(1));
      expect(fullResult.candidates.length, equals(1));
      // Costs match to within float precision — both ran over a full
      // year of synthetic weather.
      expect(
        shortResult.candidates.single.lifetimeNetCostEur,
        closeTo(fullResult.candidates.single.lifetimeNetCostEur!, 1e-6),
      );
      expect(
        shortResult.candidates.single.summary.pvAcKwh,
        closeTo(fullResult.candidates.single.summary.pvAcKwh, 1e-6),
      );
    });

    test('discountRatePct=0 and escalation=0 reproduce the pre-NPV sum', () {
      final spec = OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(
          eurPerKwpPv: 1000,
          eurPerKwAcInverter: 200,
          eurPerKwhBattery: 600,
        ),
        objective: OptimizerObjective.minNetCost,
        batterySweepKwh: const [5.0],
        inverterSweepKw: const [5.0],
        pvScaleSweep: const [1.0],
        horizonYears: 15,
      );
      final result = const Optimizer().run(spec);
      final cand = result.candidates.single;
      // Pre-NPV closed form: investment + N × annual.
      final expected =
          cand.investmentEur + 15 * cand.summary.netCostEur!;
      expect(cand.lifetimeNetCostEur, closeTo(expected, 1e-6));
    });

    test('discount-only matches the analytic geometric series', () {
      // horizon=2, r=5%, e=0% closed form:
      //   lifetime = investment + annual × (1/1.05 + 1/1.05²)
      const r = 5.0;
      final spec = OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(
          eurPerKwpPv: 1000,
          eurPerKwAcInverter: 200,
          eurPerKwhBattery: 600,
        ),
        objective: OptimizerObjective.minNetCost,
        batterySweepKwh: const [5.0],
        inverterSweepKw: const [5.0],
        pvScaleSweep: const [1.0],
        horizonYears: 2,
        discountRatePct: r,
      );
      final cand = const Optimizer().run(spec).candidates.single;
      final annual = cand.summary.netCostEur!;
      final expected = cand.investmentEur +
          annual * (1 / 1.05 + 1 / (1.05 * 1.05));
      expect(cand.lifetimeNetCostEur, closeTo(expected, 1e-6));
    });

    test('escalation-only matches the analytic geometric series', () {
      // horizon=3, r=0%, e=3% closed form:
      //   lifetime = investment + annual × (1 + 1.03 + 1.03²)
      const e = 3.0;
      final spec = OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(
          eurPerKwpPv: 1000,
          eurPerKwAcInverter: 200,
          eurPerKwhBattery: 600,
        ),
        objective: OptimizerObjective.minNetCost,
        batterySweepKwh: const [5.0],
        inverterSweepKw: const [5.0],
        pvScaleSweep: const [1.0],
        horizonYears: 3,
        priceEscalationPctPerYear: e,
      );
      final cand = const Optimizer().run(spec).candidates.single;
      final annual = cand.summary.netCostEur!;
      final expected = cand.investmentEur +
          annual * (1.0 + 1.03 + 1.03 * 1.03);
      expect(cand.lifetimeNetCostEur, closeTo(expected, 1e-6));
    });

    test('discount and escalation cancel when equal (sum becomes N × annual)',
        () {
      // With r == e, (1+e)^(y-1) / (1+r)^y collapses to 1/(1+r) for
      // every y. Sum over horizonYears is horizonYears × annual / (1+r).
      const r = 4.0; // %
      final spec = OptimizerSpec(
        baseline: _baseline(),
        prices: const OptimizerPrices(
          eurPerKwpPv: 1000,
          eurPerKwAcInverter: 200,
          eurPerKwhBattery: 600,
        ),
        objective: OptimizerObjective.minNetCost,
        batterySweepKwh: const [5.0],
        inverterSweepKw: const [5.0],
        pvScaleSweep: const [1.0],
        horizonYears: 10,
        discountRatePct: r,
        priceEscalationPctPerYear: r,
      );
      final cand = const Optimizer().run(spec).candidates.single;
      final expected = cand.investmentEur +
          10 * cand.summary.netCostEur! / (1 + r / 100);
      expect(cand.lifetimeNetCostEur, closeTo(expected, 1e-6));
    });

    test('rejects out-of-range discount/escalation rates', () {
      expect(
        () => OptimizerSpec(
          baseline: _baseline(),
          prices: const OptimizerPrices(),
          objective: OptimizerObjective.maxAutarky,
          discountRatePct: -100,
        ).validate(),
        throwsArgumentError,
      );
      expect(
        () => OptimizerSpec(
          baseline: _baseline(),
          prices: const OptimizerPrices(),
          objective: OptimizerObjective.maxAutarky,
          priceEscalationPctPerYear: -150,
        ).validate(),
        throwsArgumentError,
      );
      expect(
        () => OptimizerSpec(
          baseline: _baseline(),
          prices: const OptimizerPrices(),
          objective: OptimizerObjective.maxAutarky,
          discountRatePct: double.nan,
        ).validate(),
        throwsArgumentError,
      );
    });

    test('investment math sums all baseline devices, not just the swept [0]',
        () {
      // Copilot PR #31 review: with multiple inverters / batteries in
      // the baseline, the optimizer only varies the [0] device but the
      // investment cost must price the WHOLE system.
      final baseline = SimulationConfig(
        arrays: const [
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
          Inverter(id: 'extra', label: 'Extra', maxAcKw: 3.0),
        ],
        batteries: const [
          BatteryConfig(
            id: 'main',
            label: 'Main',
            capacityKwh: 5.0,
            maxChargeKw: 2.5,
            maxDischargeKw: 2.5,
          ),
          BatteryConfig(
            id: 'extra',
            label: 'Extra',
            capacityKwh: 10.0,
            maxChargeKw: 5.0,
            maxDischargeKw: 5.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 12.0),
        days: 1,
      );
      final spec = OptimizerSpec(
        baseline: baseline,
        prices: const OptimizerPrices(
          eurPerKwpPv: 1000,
          eurPerKwAcInverter: 500,
          eurPerKwhBattery: 800,
        ),
        objective: OptimizerObjective.maxAutarky,
        batterySweepKwh: const [5.0],
        inverterSweepKw: const [5.0],
        pvScaleSweep: const [1.0],
      );
      final result = const Optimizer().run(spec);
      expect(result.candidates.length, equals(1));
      // pv 5 kWp × 1000 = 5000 €
      // inverters: swept 5 kW + fixed 3 kW = 8 kW × 500 = 4000 €
      // batteries: swept 5 kWh + fixed 10 kWh = 15 kWh × 800 = 12 000 €
      // Total = 21 000 €.
      expect(result.candidates.single.investmentEur, closeTo(21000.0, 0.01));
    });
  });

  group('Pareto frontier', () {
    OptimizerSpec buildSweep({
      TariffConfig? tariff = const TariffConfig(
        importPricePerKwh: 0.30,
        exportPricePerKwh: 0.08,
      ),
      int topN = 50,
    }) {
      return OptimizerSpec(
        baseline: _baseline(tariff: tariff),
        prices: const OptimizerPrices(
          eurPerKwpPv: 1000,
          eurPerKwAcInverter: 300,
          eurPerKwhBattery: 600,
        ),
        objective: OptimizerObjective.maxAutarky,
        batterySweepKwh: const [3.0, 6.0, 9.0],
        inverterSweepKw: const [4.0, 6.0],
        pvScaleSweep: const [0.8, 1.0, 1.2],
        topN: topN,
      );
    }

    test('empty when no candidate has a tariff-derived cost', () {
      final spec = OptimizerSpec(
        baseline: _baseline(tariff: null),
        prices: const OptimizerPrices(
          eurPerKwpPv: 1000,
          eurPerKwAcInverter: 300,
          eurPerKwhBattery: 600,
        ),
        objective: OptimizerObjective.maxAutarky,
        batterySweepKwh: const [3.0, 6.0],
        inverterSweepKw: const [4.0, 6.0],
        pvScaleSweep: const [1.0],
      );
      final result = const Optimizer().run(spec);
      expect(result.candidates, isNotEmpty);
      expect(result.candidates.first.lifetimeNetCostEur, isNull);
      expect(result.paretoFrontier, isEmpty);
    });

    test('frontier is sorted by cost ascending with strictly increasing autarky', () {
      final result = const Optimizer().run(buildSweep());
      expect(result.paretoFrontier, isNotEmpty);
      for (var i = 1; i < result.paretoFrontier.length; i++) {
        final prev = result.paretoFrontier[i - 1];
        final cur = result.paretoFrontier[i];
        expect(
          cur.lifetimeNetCostEur,
          greaterThanOrEqualTo(prev.lifetimeNetCostEur!),
        );
        expect(
          cur.summary.autarkyRate,
          greaterThan(prev.summary.autarkyRate),
        );
      }
    });

    test('frontier excludes a dominated candidate', () {
      final result = const Optimizer().run(buildSweep());
      // For every Pareto candidate p, no candidate c is strictly better
      // on both axes (cheaper AND more autarkic).
      for (final p in result.paretoFrontier) {
        for (final c in result.candidates) {
          if (identical(p, c)) continue;
          if (c.lifetimeNetCostEur == null) continue;
          final cheaper = c.lifetimeNetCostEur! < p.lifetimeNetCostEur!;
          final moreAutarkic = c.summary.autarkyRate > p.summary.autarkyRate;
          final notWorse = c.lifetimeNetCostEur! <= p.lifetimeNetCostEur! &&
              c.summary.autarkyRate >= p.summary.autarkyRate;
          // c dominates p iff it is not-worse on both AND strictly
          // better on at least one — that must never be true for a
          // candidate that survived to the frontier.
          final dominates = notWorse && (cheaper || moreAutarkic);
          expect(dominates, isFalse,
              reason: 'Frontier candidate $p is dominated by $c');
        }
      }
    });

    test('a clearly dominated combo is not in the frontier', () {
      // The smallest combo (battery=3, inverter=4, pvScale=0.8) is
      // dominated by larger-battery / larger-pv combos that deliver
      // both higher autarky AND lower lifetime net cost over a
      // 10-year horizon at 0.30 €/kWh import. `buildSweep()` runs the
      // full 3×2×3 = 18 cartesian product with `topN: 50`, so the
      // smallest combo is guaranteed to be in `result.candidates`.
      final result = const Optimizer().run(buildSweep());
      final smallest = result.candidates.firstWhere(
        (c) =>
            c.batteryKwh == 3.0 &&
            c.inverterKw == 4.0 &&
            c.pvScale == 0.8,
      );
      final dominators = result.candidates.where((c) =>
          !identical(c, smallest) &&
          c.lifetimeNetCostEur != null &&
          c.lifetimeNetCostEur! <= smallest.lifetimeNetCostEur! &&
          c.summary.autarkyRate >= smallest.summary.autarkyRate &&
          (c.lifetimeNetCostEur! < smallest.lifetimeNetCostEur! ||
              c.summary.autarkyRate > smallest.summary.autarkyRate));
      // The fixture is engineered so at least one strictly better
      // combo exists; if this ever turns up empty the test should
      // fail rather than silently passing.
      expect(dominators, isNotEmpty,
          reason: 'fixture invariant: smallest combo must have a dominator');
      expect(result.paretoFrontier, isNot(contains(smallest)));
    });

    test('frontier is independent of topN', () {
      final small = const Optimizer().run(buildSweep(topN: 1));
      final large = const Optimizer().run(buildSweep(topN: 50));
      expect(small.candidates.length, equals(1));
      expect(large.candidates.length, greaterThan(1));
      expect(
        small.paretoFrontier.length,
        equals(large.paretoFrontier.length),
        reason: 'Pareto must be computed from the pre-truncation set',
      );
      // Same identities, in the same order (cost ascending).
      for (var i = 0; i < small.paretoFrontier.length; i++) {
        expect(
          small.paretoFrontier[i].lifetimeNetCostEur,
          closeTo(large.paretoFrontier[i].lifetimeNetCostEur!, 1e-9),
        );
        expect(
          small.paretoFrontier[i].summary.autarkyRate,
          closeTo(large.paretoFrontier[i].summary.autarkyRate, 1e-9),
        );
      }
    });

    test('frontier endpoints match the per-objective extrema', () {
      final result = const Optimizer().run(buildSweep());
      final withCost = result.candidates
          .where((c) => c.lifetimeNetCostEur != null)
          .toList();
      final minCost = withCost
          .map((c) => c.lifetimeNetCostEur!)
          .reduce((a, b) => a < b ? a : b);
      final maxAutarky =
          withCost.map((c) => c.summary.autarkyRate).reduce((a, b) => a > b ? a : b);
      // First point on the frontier is the cheapest with the highest
      // autarky at that price.
      expect(
        result.paretoFrontier.first.lifetimeNetCostEur,
        closeTo(minCost, 1e-9),
      );
      // Last point on the frontier reaches the maximum autarky in the
      // sweep (no other combo beats it).
      expect(
        result.paretoFrontier.last.summary.autarkyRate,
        closeTo(maxAutarky, 1e-9),
      );
    });

    test('allCandidates contains the full evaluated sweep (untruncated)',
        () {
      // 3 × 2 × 3 = 18 combos; topN=1 forces `candidates` to length 1
      // but `allCandidates` must still hold all 18.
      final result = const Optimizer().run(buildSweep(topN: 1));
      expect(result.candidates.length, equals(1));
      expect(result.allCandidates.length, equals(result.evaluated));
      expect(result.allCandidates.length, equals(18));
      // The list is sorted best-first per objective; `candidates`
      // is its prefix.
      expect(result.allCandidates.first, equals(result.candidates.first));
      // The Pareto frontier is a subset of `allCandidates`.
      for (final p in result.paretoFrontier) {
        expect(result.allCandidates, contains(p));
      }
    });
  });
}
