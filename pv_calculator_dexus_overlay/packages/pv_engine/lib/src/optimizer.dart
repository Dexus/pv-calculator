part of '../pv_engine.dart';

/// Objective the [Optimizer] ranks candidates by.
///
/// `minNetCost` requires the baseline [SimulationConfig.tariff] to be
/// set so the engine surfaces [SimulationSummary.netCostEur]. Without
/// it [OptimizerSpec.validate] throws — silently producing nulls would
/// make the sort order meaningless.
///
/// `maxAutarky` works without a tariff: it ranks by
/// [SimulationSummary.autarkyRate] (covered load / total load).
enum OptimizerObjective { minNetCost, maxAutarky }

/// Linear cost model the optimizer applies to each candidate to compute
/// `investmentEur`. All prices in €, non-negative. Component-catalog
/// entries currently carry no price data, so the optimizer takes prices
/// as separate user input — the UI surfaces three fields and forwards
/// them here.
///
/// Investment per candidate is:
/// `pvKwp * eurPerKwpPv + inverterKw * eurPerKwAcInverter
///  + batteryKwh * eurPerKwhBattery`.
///
/// `pvKwp` is the sum of *enabled* arrays' baseline `peakKw × pvScale`.
class OptimizerPrices {
  const OptimizerPrices({
    this.eurPerKwpPv = 0,
    this.eurPerKwAcInverter = 0,
    this.eurPerKwhBattery = 0,
  });

  final double eurPerKwpPv;
  final double eurPerKwAcInverter;
  final double eurPerKwhBattery;

  void validate() {
    if (!eurPerKwpPv.isFinite || eurPerKwpPv < 0) {
      throw ArgumentError('OptimizerPrices.eurPerKwpPv must be finite and >= 0.');
    }
    if (!eurPerKwAcInverter.isFinite || eurPerKwAcInverter < 0) {
      throw ArgumentError('OptimizerPrices.eurPerKwAcInverter must be finite and >= 0.');
    }
    if (!eurPerKwhBattery.isFinite || eurPerKwhBattery < 0) {
      throw ArgumentError('OptimizerPrices.eurPerKwhBattery must be finite and >= 0.');
    }
  }
}

/// Input to [Optimizer.run].
///
/// Sweep dimensions are explicit lists — the UI converts min/max/steps
/// fields into these arrays. An empty sweep collapses that dimension to
/// a single baseline value (so a user who only wants to sweep battery
/// doesn't have to repeat the inverter or PV scale).
///
/// `optionalArrayIds` toggles per-array inclusion. For each combo of
/// the other dimensions the optimizer also iterates every subset of
/// `optionalArrayIds`; arrays NOT in this list are always enabled.
/// Capped at 4 entries → at most `2^4 = 16` array subsets per combo,
/// keeping the search space tractable and the UI honest.
///
/// The optimizer always varies `batteries[0]` and `inverters[0]` —
/// targeted multi-component sweeps are deferred (see ROADMAP Phase 10).
class OptimizerSpec {
  const OptimizerSpec({
    required this.baseline,
    required this.prices,
    required this.objective,
    this.batterySweepKwh = const [],
    this.inverterSweepKw = const [],
    this.pvScaleSweep = const [],
    this.optionalArrayIds = const [],
    this.budgetEur,
    this.horizonYears = 10,
    this.topN = 20,
  });

  /// Template config. Cloned per candidate via `fromJson(toJson())` and
  /// patched.
  final SimulationConfig baseline;

  final OptimizerPrices prices;
  final OptimizerObjective objective;

  /// Candidate battery capacities (kWh). Replaces `baseline.batteries[0]
  /// .capacityKwh`. `maxChargeKw`/`maxDischargeKw`/`minSocKwh` scale
  /// proportionally so the baseline's C-rate and SOC floor fraction are
  /// preserved. Empty → keep baseline.
  final List<double> batterySweepKwh;

  /// Candidate inverter AC caps (kW). Replaces `baseline.inverters[0]
  /// .maxAcKw`. Empty → keep baseline.
  final List<double> inverterSweepKw;

  /// PV scale factors applied uniformly to every enabled array's
  /// `peakKw`. Empty → keep baseline.
  final List<double> pvScaleSweep;

  /// IDs of arrays the user marked "optional". The sweep enumerates
  /// every subset of these (max 4 entries → ≤ 16 subsets).
  final List<String> optionalArrayIds;

  /// Hard budget cap on `investmentEur`. Candidates exceeding it are
  /// counted in [OptimizerResult.skippedOverBudget] without running the
  /// simulator. `null` = no cap.
  final double? budgetEur;

  /// Years over which `lifetimeNetCostEur = investmentEur + horizonYears
  /// × summary.netCostEur` is computed. Undiscounted — adding a discount
  /// rate / NPV is deferred (ROADMAP Phase 10).
  final int horizonYears;

  /// Returned candidates are sorted best-first and truncated to this
  /// length.
  final int topN;

  void validate() {
    // Validate the baseline up front so an invalid SimulationConfig
    // surfaces as a single ArgumentError instead of silently soft-
    // failing every patched candidate as `failedValidation`.
    baseline.validate();
    prices.validate();
    if (horizonYears < 1 || horizonYears > 100) {
      throw ArgumentError('OptimizerSpec.horizonYears must be in [1, 100].');
    }
    if (topN < 1) {
      throw ArgumentError('OptimizerSpec.topN must be >= 1.');
    }
    final budget = budgetEur;
    if (budget != null && (!budget.isFinite || budget < 0)) {
      throw ArgumentError('OptimizerSpec.budgetEur must be finite and >= 0 when set.');
    }
    for (final v in batterySweepKwh) {
      if (!v.isFinite || v < 0) {
        throw ArgumentError('OptimizerSpec.batterySweepKwh entries must be finite and >= 0.');
      }
    }
    for (final v in inverterSweepKw) {
      if (!v.isFinite || v <= 0) {
        throw ArgumentError('OptimizerSpec.inverterSweepKw entries must be finite and > 0.');
      }
    }
    for (final v in pvScaleSweep) {
      if (!v.isFinite || v < 0) {
        throw ArgumentError('OptimizerSpec.pvScaleSweep entries must be finite and >= 0.');
      }
    }
    if (optionalArrayIds.length > 4) {
      throw ArgumentError(
          'OptimizerSpec.optionalArrayIds may contain at most 4 entries (2^4=16 subsets).');
    }
    final knownArrayIds = {for (final a in baseline.arrays) a.id};
    final seen = <String>{};
    for (final id in optionalArrayIds) {
      if (!knownArrayIds.contains(id)) {
        throw ArgumentError(
            'OptimizerSpec.optionalArrayIds references unknown array $id.');
      }
      if (!seen.add(id)) {
        throw ArgumentError(
            'OptimizerSpec.optionalArrayIds contains duplicate $id.');
      }
    }
    if (objective == OptimizerObjective.minNetCost && baseline.tariff == null) {
      throw ArgumentError(
          'OptimizerObjective.minNetCost requires baseline.tariff to be set.');
    }
    if (batterySweepKwh.isNotEmpty && baseline.batteries.isEmpty) {
      throw ArgumentError(
          'OptimizerSpec.batterySweepKwh is set but baseline has no batteries.');
    }
    if (inverterSweepKw.isNotEmpty && baseline.inverters.isEmpty) {
      throw ArgumentError(
          'OptimizerSpec.inverterSweepKw is set but baseline has no inverters.');
    }
  }
}

/// One evaluated combination of sweep parameters and the simulator
/// output it produced.
///
/// `lifetimeNetCostEur` is `null` when the baseline has no tariff (only
/// the `maxAutarky` objective is reachable in that case). When set it
/// equals `investmentEur + horizonYears × summary.netCostEur` and is
/// strictly the optimizer's ranking metric — it is *not* a financial
/// forecast (no discount rate, no inflation, no tariff escalation).
class OptimizerCandidate {
  const OptimizerCandidate({
    required this.batteryKwh,
    required this.inverterKw,
    required this.pvScale,
    required this.disabledArrayIds,
    required this.investmentEur,
    required this.lifetimeNetCostEur,
    required this.summary,
  });

  final double batteryKwh;
  final double inverterKw;
  final double pvScale;
  final Set<String> disabledArrayIds;
  final double investmentEur;
  final double? lifetimeNetCostEur;
  final SimulationSummary summary;

  @override
  String toString() => 'OptimizerCandidate('
      'batteryKwh: $batteryKwh, inverterKw: $inverterKw, pvScale: $pvScale, '
      'disabled: ${(disabledArrayIds.toList()..sort()).join(",")}, '
      'investmentEur: ${investmentEur.toStringAsFixed(2)}, '
      'lifetimeNetCostEur: ${lifetimeNetCostEur?.toStringAsFixed(2)}, '
      'autarky: ${summary.autarkyRate.toStringAsFixed(4)})';
}

/// Output of [Optimizer.run].
///
/// `candidates` is sorted best-first per [OptimizerSpec.objective] and
/// truncated to `topN`. Counters expose what happened to the
/// non-surviving combos.
class OptimizerResult {
  const OptimizerResult({
    required this.candidates,
    required this.evaluated,
    required this.skippedOverBudget,
    required this.failedValidation,
  });

  final List<OptimizerCandidate> candidates;
  final int evaluated;
  final int skippedOverBudget;
  final int failedValidation;
}

/// Parametric sweep over a [SimulationConfig] template. Pure-Dart,
/// runtime-dep-free — usable from CLI/server contexts as well as the
/// Flutter app.
///
/// The sweep is a Cartesian product of (battery kWh × inverter kW × PV
/// scale × array subset). For each combo the optimizer:
///   1. Computes the linear investment from [OptimizerPrices].
///   2. Skips it when over [OptimizerSpec.budgetEur].
///   3. Clones the baseline via `fromJson(toJson())` and patches the
///      relevant fields, scaling battery power and minSoc to preserve
///      C-rate and SOC-floor fraction.
///   4. Filters topology edges that reference disabled arrays (so a
///      user-disabled array doesn't dangle in `topology.edges`).
///   5. Forces `keepSteps: false` and `simulationYears: 1` (cost is
///      multiplied by `horizonYears` externally; multi-year is a
///      separate Pro feature and combining the two would explode the
///      runtime).
///   6. Runs `PvSimulator().run(patched)`. Configs that fail engine
///      `validate()` increment `failedValidation` and the sweep
///      continues.
///   7. Computes `lifetimeNetCostEur` (when the tariff is set) and
///      emplaces the candidate.
///
/// Candidates are sorted ascending by an internal score: `-autarkyRate`
/// for `maxAutarky`, `lifetimeNetCostEur` for `minNetCost`. The top-N
/// is returned.
class Optimizer {
  const Optimizer();

  OptimizerResult run(
    OptimizerSpec spec, {
    void Function(int done, int total)? onProgress,
  }) {
    spec.validate();

    final batteryValues = spec.batterySweepKwh.isEmpty
        ? [spec.baseline.batteries.isEmpty ? 0.0 : spec.baseline.batteries.first.capacityKwh]
        : spec.batterySweepKwh;
    final inverterValues = spec.inverterSweepKw.isEmpty
        ? [spec.baseline.inverters.isEmpty ? 0.0 : spec.baseline.inverters.first.maxAcKw]
        : spec.inverterSweepKw;
    final pvValues = spec.pvScaleSweep.isEmpty ? const [1.0] : spec.pvScaleSweep;
    final disabledSubsets = _arraySubsets(spec.optionalArrayIds);

    final total = batteryValues.length *
        inverterValues.length *
        pvValues.length *
        disabledSubsets.length;
    onProgress?.call(0, total);

    // Pre-encode the baseline JSON once. `_patchConfig` decodes a fresh
    // copy per candidate; hoisting the encode out of the hot loop is
    // measurable on large sweeps and the result is identical because
    // none of the swept fields mutate the source map.
    final baselineJsonString = jsonEncode(spec.baseline.toJson());
    final baselineBatteryKwh =
        spec.baseline.batteries.isEmpty ? 0.0 : spec.baseline.batteries.first.capacityKwh;

    final candidates = <OptimizerCandidate>[];
    var evaluated = 0;
    var skippedOverBudget = 0;
    var failedValidation = 0;
    var done = 0;

    for (final batteryKwh in batteryValues) {
      for (final inverterKw in inverterValues) {
        for (final pvScale in pvValues) {
          for (final disabled in disabledSubsets) {
            done++;
            final enabledArrays =
                spec.baseline.arrays.where((a) => !disabled.contains(a.id));
            final pvKwp =
                enabledArrays.fold<double>(0.0, (sum, a) => sum + a.peakKw * pvScale);
            final investment = pvKwp * spec.prices.eurPerKwpPv +
                inverterKw * spec.prices.eurPerKwAcInverter +
                batteryKwh * spec.prices.eurPerKwhBattery;

            if (spec.budgetEur != null && investment > spec.budgetEur!) {
              skippedOverBudget++;
              onProgress?.call(done, total);
              continue;
            }

            SimulationConfig patched;
            try {
              patched = _patchConfig(
                baseline: spec.baseline,
                baselineJsonString: baselineJsonString,
                batteryKwh: batteryKwh,
                baselineBatteryKwh: baselineBatteryKwh,
                inverterKw: inverterKw,
                pvScale: pvScale,
                disabled: disabled,
              );
              patched.validate();
            } on ArgumentError {
              failedValidation++;
              onProgress?.call(done, total);
              continue;
            }

            SimulationResult result;
            try {
              result = const PvSimulator().run(patched);
            } on ArgumentError {
              failedValidation++;
              onProgress?.call(done, total);
              continue;
            }
            evaluated++;
            final netCost = result.summary.netCostEur;
            final lifetimeNetCost = netCost == null
                ? null
                : investment + spec.horizonYears * netCost;
            candidates.add(OptimizerCandidate(
              batteryKwh: batteryKwh,
              inverterKw: inverterKw,
              pvScale: pvScale,
              disabledArrayIds: Set.unmodifiable(disabled),
              investmentEur: investment,
              lifetimeNetCostEur: lifetimeNetCost,
              summary: result.summary,
            ));
            onProgress?.call(done, total);
          }
        }
      }
    }

    candidates.sort((a, b) {
      final sa = _score(a, spec.objective);
      final sb = _score(b, spec.objective);
      return sa.compareTo(sb);
    });
    final top = candidates.length <= spec.topN
        ? candidates
        : candidates.sublist(0, spec.topN);

    return OptimizerResult(
      candidates: List.unmodifiable(top),
      evaluated: evaluated,
      skippedOverBudget: skippedOverBudget,
      failedValidation: failedValidation,
    );
  }

  /// Enumerates every subset of [optionalArrayIds] as a `Set<String>` of
  /// **disabled** ids. The empty set (all arrays enabled) is always
  /// included; the full set (all optional arrays disabled) is included
  /// last. With N optional ids this returns `2^N` sets.
  List<Set<String>> _arraySubsets(List<String> optionalArrayIds) {
    final n = optionalArrayIds.length;
    final out = <Set<String>>[];
    for (var mask = 0; mask < (1 << n); mask++) {
      final s = <String>{};
      for (var i = 0; i < n; i++) {
        if ((mask & (1 << i)) != 0) s.add(optionalArrayIds[i]);
      }
      out.add(s);
    }
    return out;
  }

  /// Computes the sort key (lower is better) for [candidate] under
  /// [objective]. `maxAutarky` uses `-autarkyRate` so ascending sort
  /// puts the highest autarky first; `minNetCost` uses
  /// `lifetimeNetCostEur` directly (always non-null when the objective
  /// is `minNetCost` because `validate()` requires the tariff).
  double _score(OptimizerCandidate candidate, OptimizerObjective objective) {
    switch (objective) {
      case OptimizerObjective.maxAutarky:
        return -candidate.summary.autarkyRate;
      case OptimizerObjective.minNetCost:
        return candidate.lifetimeNetCostEur ?? double.infinity;
    }
  }

  /// Decodes [baselineJsonString] into a fresh map and patches the
  /// swept fields, returning a [SimulationConfig]. Topology edges that
  /// reference a disabled array are filtered out so the user-facing
  /// "disable this array" gesture doesn't leave a dangling edge.
  /// Battery power scales with capacity to preserve the baseline's
  /// C-rate; `minSocKwh` scales with capacity to preserve the SOC-floor
  /// fraction. The non-serialised [SimulationConfig.weatherSource] and
  /// [SimulationConfig.temperatureModel] are re-attached from
  /// [baseline] so the optimizer sees the user's loaded PVGIS data
  /// instead of silently dropping back to the synthetic model.
  ///
  /// Forces `days = 365` so `summary.netCostEur` is always a per-year
  /// cost — multiplying that by `horizonYears` gives an honest lifetime
  /// estimate even when the user's underlying Results-tab draft uses a
  /// partial-period run (e.g. a 30-day debug sim). Cyclic-convergence
  /// already requires `days == 365`; non-cyclic modes are unaffected
  /// because the engine wraps `dayOfYear` into `[1, 365]` regardless.
  SimulationConfig _patchConfig({
    required SimulationConfig baseline,
    required String baselineJsonString,
    required double batteryKwh,
    required double baselineBatteryKwh,
    required double inverterKw,
    required double pvScale,
    required Set<String> disabled,
  }) {
    // Deep-clone via JSON round-trip. The encode is hoisted to the
    // caller (`Optimizer.run`) so the hot loop only pays for the
    // per-candidate decode.
    final cloned = jsonDecode(baselineJsonString) as Map<String, dynamic>;

    final arraysJson = (cloned['arrays'] as List).cast<Map<String, dynamic>>();
    final keptArrays = <Map<String, dynamic>>[];
    for (final a in arraysJson) {
      if (disabled.contains(a['id'])) continue;
      a['peakKw'] = ((a['peakKw'] as num).toDouble()) * pvScale;
      keptArrays.add(a);
    }
    cloned['arrays'] = keptArrays;

    final invertersJson = (cloned['inverters'] as List).cast<Map<String, dynamic>>();
    if (invertersJson.isNotEmpty) {
      invertersJson.first['maxAcKw'] = inverterKw;
    }

    final batteriesJson = (cloned['batteries'] as List?)?.cast<Map<String, dynamic>>();
    if (batteriesJson != null && batteriesJson.isNotEmpty) {
      final b = batteriesJson.first;
      final ratio = baselineBatteryKwh > 1e-6 ? batteryKwh / baselineBatteryKwh : 1.0;
      b['capacityKwh'] = batteryKwh;
      b['maxChargeKw'] = (b['maxChargeKw'] as num).toDouble() * ratio;
      b['maxDischargeKw'] = (b['maxDischargeKw'] as num).toDouble() * ratio;
      final minSoc = b['minSocKwh'];
      if (minSoc is num) b['minSocKwh'] = minSoc.toDouble() * ratio;
      final initial = b['initialSocKwh'];
      if (initial is num) {
        b['initialSocKwh'] = initial.toDouble() * ratio;
      }
    }

    if (disabled.isNotEmpty) {
      final topology = cloned['topology'] as Map<String, dynamic>?;
      if (topology != null) {
        final edges = (topology['edges'] as List?)?.cast<Map<String, dynamic>>();
        if (edges != null) {
          topology['edges'] = edges
              .where((e) =>
                  !disabled.contains(e['fromId']) && !disabled.contains(e['toId']))
              .toList();
        }
      }
    }

    // Force per-candidate flags: per-step retention off, full 365-day
    // year, single year. The user-facing baseline may run a partial
    // period (e.g. 30 debug days) but lifetime cost is computed as
    // `horizonYears × per-year netCostEur` and so MUST be evaluated
    // against a full year — otherwise the ranking compares apples to
    // calendar fractions. The engine wraps dayOfYear into [1, 365]
    // regardless, so a partial-period baseline with `startDayOfYear !=
    // 1` still yields a sensible full annual cycle here.
    cloned['keepSteps'] = false;
    cloned['simulationYears'] = 1;
    cloned['days'] = 365;
    // `preRunDays` is preserved; cyclic-convergence in the baseline
    // continues to mean "until SOC stabilises" because the engine
    // already validated `days == 365` for that mode.

    final patched = SimulationConfig.fromJson(cloned);
    // Re-attach the non-serialised fields so the optimizer mirrors the
    // baseline's runtime environment instead of dropping back to
    // defaults. `weatherSource` and `temperatureModel` are deliberately
    // omitted from `toJson()` (they may be backed by a multi-MB cache or
    // a model that doesn't round-trip).
    return SimulationConfig(
      arrays: patched.arrays,
      inverters: patched.inverters,
      batteries: patched.batteries,
      microInverterBanks: patched.microInverterBanks,
      topology: patched.topology,
      dispatchPolicy: patched.dispatchPolicy,
      loadProfile: patched.loadProfile,
      startDayOfYear: patched.startDayOfYear,
      days: patched.days,
      timeStep: patched.timeStep,
      preRunDays: patched.preRunDays,
      preRunMode: patched.preRunMode,
      convergenceToleranceFraction: patched.convergenceToleranceFraction,
      maxConvergenceIterations: patched.maxConvergenceIterations,
      gridExportLimitKw: patched.gridExportLimitKw,
      latitudeDeg: patched.latitudeDeg,
      longitudeDeg: patched.longitudeDeg,
      weatherSource: baseline.weatherSource,
      temperatureModel: baseline.temperatureModel,
      keepSteps: false,
      simulationYears: 1,
      tariff: patched.tariff,
    );
  }
}
