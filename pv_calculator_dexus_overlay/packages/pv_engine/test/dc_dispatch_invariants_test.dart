import 'dart:math' as math;

import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

/// Phase 4c: property-based backstop for the DC dispatch chain.
///
/// The Phase-4b refactor consolidated all per-bus energy bookkeeping
/// into a single [DcBusSolver]. The seven Codex review rounds prior
/// to that refactor each turned up 3-5 P2 findings of the same shape
/// — an η or cap that was applied in one layer but not another. This
/// test generates random valid topologies, runs the simulator for one
/// day, and asserts step-level invariants that would catch any
/// reintroduced unit-mismatch immediately:
///
///   I1: SOC ∈ [minSoc, capacity] at the end of every step.
///   I2: charge[i] ≤ maxChargeKw[i] × stepHours.
///   I3: discharge[i] ≤ maxDischargeKw[i] × stepHours (AC delivery
///       ≤ DC rate because every η ≤ 1).
///   I4: every reported per-step kWh field is finite and ≥ 0.
///   I5: grid export ≤ gridExportLimitKw × stepHours when set.
///   I6: two-sided energy balance — `inputs - outputs` is the
///       conversion-loss slack (curtailment buckets are subtracted
///       inside `outputs`), which must be ≥ 0 and ≤ an η-derived
///       upper bound. The Phase 4b/4c review rounds found
///       cases where η or clip energy disappeared silently into the
///       slack; bounding it forces every kWh into either a delivery
///       bucket, a curtailment bucket, or a known conversion loss.
///   I7: pvAcKwh + Σ discharge ≤ Σ_inverter effectiveMaxAcKw ×
///       stepHours (coarse — per-inverter caps are stricter but
///       this sum bounds the total AC delivered).
///   I8: DC-side ledger — `pvDcKwh ≥ Σ DC-coupled charges +
///       curtailedDcKwh`. The remainder is PV that left the DC bus
///       as AC via the bus inverter. Catches any future regression
///       that books DC throughput on the AC ledger by mistake.
///
/// 250 random configs × up to 24 hourly steps ≈ 6000 step-invariant
/// checks. The generator emits both single-bus and multi-bus shapes
/// (two DC buses sharing one inverter, optionally with one hybrid +
/// one batteryFed) so the three Round-8 findings that needed a
/// shared resource between buses (inverter DC-cap, shared AC load
/// pool) are now in the search space. Any future patch that breaks
/// these invariants fails the test immediately with the failing
/// config + step dumped so the fix can target the root cause
/// instead of triggering yet another review round.

class _ConfigBuilder {
  _ConfigBuilder(this.rng);

  final math.Random rng;
  final inverters = <Inverter>[];
  final arrays = <PvArray>[];
  final batteries = <BatteryConfig>[];
  final dcBuses = <DcBus>[];
  final acBuses = <AcBus>[];
  final mppts = <MpptNode>[];
  final edges = <BusEdge>[];
  final couplings = <BatteryCouplingSpec>[];
  final chargeControllers = <ChargeController>[];
  // Inverters that must NOT get a default `mppt-<id>` node in
  // `_buildTopology`. Used for shared bus-inverters that feed at
  // least one batteryFed bus — topology Rule 4 (the "no array→mppt
  // on batteryFed inverter" half of "Rules 3 + 4" in
  // `lib/src/topology.dart:568`) forbids `array → mppt` on such
  // inverters.
  final mpptlessInverters = <String>{};
  int _nextId = 0;

  String _id(String prefix) => '$prefix-${_nextId++}';

  double _range(double lo, double hi) => lo + (hi - lo) * rng.nextDouble();

  Inverter addInverter({
    double? maxAcKw,
    double? eta,
    double? maxDcKw,
  }) {
    final inv = Inverter(
      id: _id('inv'),
      label: 'inv',
      maxAcKw: maxAcKw ?? _range(3.0, 8.0),
      efficiency: eta ?? _range(0.9, 1.0),
      maxDcInputKw: maxDcKw,
    );
    inverters.add(inv);
    return inv;
  }

  PvArray addArray({required String inverterId, double? peakKw}) {
    final a = PvArray(
      id: _id('a'),
      label: 'a',
      peakKw: peakKw ?? _range(1.0, 4.0),
      azimuthDeg: 180,
      tiltDeg: 30,
      inverterId: inverterId,
      lossFactor: 0.0,
      shadingFactor: 0.0,
    );
    arrays.add(a);
    return a;
  }

  BatteryConfig addBattery({
    double? capacityKwh,
    double? maxChargeKw,
    double? maxDischargeKw,
    double? roundTripEfficiency,
  }) {
    final b = BatteryConfig(
      id: _id('b'),
      capacityKwh: capacityKwh ?? _range(5.0, 20.0),
      maxChargeKw: maxChargeKw ?? _range(1.0, 5.0),
      maxDischargeKw: maxDischargeKw ?? _range(1.0, 5.0),
      roundTripEfficiency: roundTripEfficiency ?? _range(0.85, 0.98),
      minSocKwh: 0,
    );
    batteries.add(b);
    return b;
  }
}

/// Builds an explicit topology that wraps the AC-path arrays + the
/// optional DC bus segments. The legacy `fromLegacy` graph emits a
/// `mppt-<inv>` node per inverter and `array → mppt` edges; we
/// reproduce that here so the AC-path validation rule "every cc must
/// have an incoming edge" doesn't kick in unexpectedly.
TopologyGraph _buildTopology(_ConfigBuilder b) {
  final ac = const AcBus(id: 'ac-main');
  b.acBuses.add(ac);
  for (final inv in b.inverters) {
    // Inverters in `mpptlessInverters` are shared bus-inverters that
    // feed at least one batteryFed DC bus. Rule 4 (the second half
    // of the "Rules 3 + 4" block in `topology.dart:583-614`) requires
    // those to have no `array → mppt` path, so skip the MPPT node +
    // edges entirely. PV arrays for these inverters reach the bus
    // via a charge controller instead.
    if (!b.mpptlessInverters.contains(inv.id)) {
      b.mppts.add(MpptNode(id: 'mppt-${inv.id}', inverterId: inv.id));
      b.edges.add(BusEdge(
        fromId: 'mppt-${inv.id}',
        toId: inv.id,
        efficiency: inv.efficiency,
        maxPowerKw: inv.maxDcInputKw,
      ));
    }
    b.edges.add(BusEdge(
      fromId: inv.id,
      toId: ac.id,
      maxPowerKw: inv.effectiveMaxAcKw,
    ));
  }
  for (final a in b.arrays) {
    // If this array is on a charge-controller path (added by the
    // generator below), an `array → cc` edge already exists; skip the
    // MPPT edge.
    if (b.edges.any((e) => e.fromId == a.id)) continue;
    // An array routed to an mpptless inverter has no MPPT to point at;
    // the generator should have wired it through a charge controller.
    // Skip silently — `validate()` in the test loop catches any
    // generator slip-up.
    if (b.mpptlessInverters.contains(a.inverterId)) continue;
    b.edges.add(BusEdge(fromId: a.id, toId: 'mppt-${a.inverterId}'));
  }
  return TopologyGraph(
    dcBuses: b.dcBuses,
    acBuses: b.acBuses,
    mppts: b.mppts,
    edges: b.edges,
    batteryCouplings: b.couplings,
    chargeControllers: b.chargeControllers,
  );
}

/// Adds one DC bus + charge controller + array + DC-coupled battery
/// (or two batteries for hybrid) to [b], wiring everything to the
/// caller-supplied [busInv]. [busIndex] disambiguates ids so a config
/// can carry multiple buses without collisions.
void _addDcBus(
  _ConfigBuilder b,
  math.Random rng,
  Inverter busInv,
  int busIndex,
  BusMode mode,
) {
  final bus = DcBus(id: 'dc-$busIndex', mode: mode);
  b.dcBuses.add(bus);
  final edgeEta = 0.9 + rng.nextDouble() * 0.09;
  final edgeCap = rng.nextBool() ? null : 3.0 + rng.nextDouble() * 5.0;
  b.edges.add(BusEdge(
    fromId: bus.id,
    toId: busInv.id,
    efficiency: edgeEta,
    maxPowerKw: edgeCap,
  ));
  final cc = ChargeController(
    id: 'cc-$busIndex',
    dcBusId: bus.id,
    efficiency: 0.92 + rng.nextDouble() * 0.07,
    maxInputKw: rng.nextBool() ? null : 2.0 + rng.nextDouble() * 4.0,
  );
  b.chargeControllers.add(cc);
  final dcArray = b.addArray(
    inverterId: busInv.id,
    peakKw: 1.5 + rng.nextDouble() * 3.0,
  );
  final ccEdgeEta = 0.9 + rng.nextDouble() * 0.1;
  // Three regimes so the property test exercises both the binding
  // and non-binding paths:
  //   30% — no cap
  //   30% — generous cap (2-6 kW, never binding on a ≤4.5 kWp array)
  //   40% — deliberately undersized (0.3-1.5 kW) so the edge clip
  //         fires on most PV-bearing steps. Round-8 Finding #2 was
  //         exactly this case: silently dropped clip energy. The
  //         strengthened I6 catches it because the lost kWh lands
  //         outside every output bucket.
  double? ccEdgeCap;
  final capRoll = rng.nextDouble();
  if (capRoll < 0.3) {
    ccEdgeCap = null;
  } else if (capRoll < 0.6) {
    ccEdgeCap = 2.0 + rng.nextDouble() * 4.0;
  } else {
    ccEdgeCap = 0.3 + rng.nextDouble() * 1.2;
  }
  b.edges.add(BusEdge(
    fromId: dcArray.id,
    toId: cc.id,
    efficiency: ccEdgeEta,
    maxPowerKw: ccEdgeCap,
  ));
  if (mode == BusMode.batteryFed) {
    // Rule 3: exactly one DC battery on a batteryFed bus.
    final batt = b.addBattery();
    b.couplings.add(BatteryCouplingSpec(
      batteryId: batt.id,
      coupling: BatteryCoupling.dc,
      dcBusId: bus.id,
    ));
  } else {
    // Hybrid: 1 or 2 DC batteries.
    final nDc = 1 + rng.nextInt(2);
    for (var i = 0; i < nDc; i++) {
      final batt = b.addBattery();
      b.couplings.add(BatteryCouplingSpec(
        batteryId: batt.id,
        coupling: BatteryCoupling.dc,
        dcBusId: bus.id,
      ));
    }
  }
}

SimulationConfig _randomConfig(int seed) {
  final rng = math.Random(seed);
  final b = _ConfigBuilder(rng);

  // === AC PV stage ===
  // One AC inverter that owns 1-2 arrays (legacy MPPT path).
  final acInv = b.addInverter(
    maxAcKw: 5.0 + rng.nextDouble() * 5.0,
    eta: 0.92 + rng.nextDouble() * 0.06,
    maxDcKw: rng.nextBool() ? null : 4.0 + rng.nextDouble() * 6.0,
  );
  final nAcArrays = 1 + rng.nextInt(2);
  for (var i = 0; i < nAcArrays; i++) {
    b.addArray(inverterId: acInv.id);
  }

  // === Optional DC bus + charge controllers + DC batteries ===
  // Four shapes (probabilities chosen so ~70 % of seeds stay on the
  // legacy single-bus/no-bus paths and ~60 of 250 explore the new
  // multi-bus shapes that catch Round-8 findings #1/#3/#4):
  //   roll < 0.40 → no DC bus
  //   roll < 0.70 → one DC bus + dedicated inverter (legacy "true" branch)
  //   roll < 0.85 → two DC buses sharing one inverter, both hybrid
  //   roll < 1.00 → two DC buses sharing one inverter, hybrid + batteryFed
  final acCoupledBatteries = <BatteryConfig>[];
  final dcRoll = rng.nextDouble();
  if (dcRoll < 0.40) {
    // no DC bus — fall through
  } else if (dcRoll < 0.70) {
    // Single dedicated bus inverter (current behaviour).
    final busInv = b.addInverter(
      maxAcKw: 3.0 + rng.nextDouble() * 5.0,
      eta: 0.9 + rng.nextDouble() * 0.08,
      maxDcKw: rng.nextBool() ? null : 4.0 + rng.nextDouble() * 5.0,
    );
    final mode = rng.nextDouble() < 0.4 ? BusMode.batteryFed : BusMode.hybrid;
    if (mode == BusMode.batteryFed) {
      // Rule 4: the inverter on a batteryFed bus must not also carry
      // an MPPT array. Mark the dedicated inverter mpptless so
      // `_buildTopology` skips the `mppt-<inv>` node and edges.
      b.mpptlessInverters.add(busInv.id);
    }
    _addDcBus(b, rng, busInv, 0, mode);
  } else {
    // Two DC buses sharing one bus-inverter.
    final shareInv = b.addInverter(
      maxAcKw: 4.0 + rng.nextDouble() * 6.0,
      eta: 0.9 + rng.nextDouble() * 0.08,
      maxDcKw: rng.nextBool() ? null : 6.0 + rng.nextDouble() * 6.0,
    );
    final modes = dcRoll < 0.85
        ? <BusMode>[BusMode.hybrid, BusMode.hybrid]
        : <BusMode>[BusMode.hybrid, BusMode.batteryFed];
    if (modes.contains(BusMode.batteryFed)) {
      // Rule 4 again — drop the default MPPT node on the shared
      // inverter so neither bus violates it. PV reaches the buses
      // via charge controllers only.
      b.mpptlessInverters.add(shareInv.id);
    }
    for (var i = 0; i < modes.length; i++) {
      _addDcBus(b, rng, shareInv, i, modes[i]);
    }
  }

  // Optional AC-coupled battery.
  if (rng.nextBool()) {
    final ab = b.addBattery();
    acCoupledBatteries.add(ab);
    b.couplings.add(BatteryCouplingSpec(
      batteryId: ab.id,
      inverterId: acInv.id,
    ));
  }
  // Make sure every battery has at least an empty coupling so the
  // topology validation handles missing entries gracefully.
  final couplingIds = b.couplings.map((c) => c.batteryId).toSet();
  for (final batt in b.batteries) {
    if (!couplingIds.contains(batt.id)) {
      b.couplings.add(BatteryCouplingSpec(batteryId: batt.id));
    }
  }

  final topology = _buildTopology(b);

  final gridExportLimitKw =
      rng.nextDouble() < 0.5 ? null : 3.0 + rng.nextDouble() * 7.0;

  return SimulationConfig(
    arrays: b.arrays,
    inverters: b.inverters,
    batteries: b.batteries,
    loadProfile: LoadProfile(dailyKwh: 5.0 + rng.nextDouble() * 25.0),
    days: 1,
    latitudeDeg: 50.0,
    longitudeDeg: 10.0,
    topology: topology,
    gridExportLimitKw: gridExportLimitKw,
  );
}

/// Smallest single-stage efficiency in [config] across inverters,
/// charge controllers, bus edges, and battery halves. Used to bound
/// the conversion-loss slack in I6. With the generator's η ranges
/// (inverter / edge / cc ≥ 0.9, battery sqrt(roundTrip) ≥ 0.92) the
/// typical floor sits at 0.9.
double _etaMinPath(SimulationConfig config) {
  var minEta = 1.0;
  for (final inv in config.inverters) {
    if (inv.efficiency < minEta) minEta = inv.efficiency;
  }
  for (final batt in config.batteries) {
    final half = math.sqrt(batt.roundTripEfficiency);
    if (half < minEta) minEta = half;
  }
  final topo = config.topology;
  if (topo != null) {
    for (final cc in topo.chargeControllers) {
      if (cc.efficiency < minEta) minEta = cc.efficiency;
    }
    for (final edge in topo.edges) {
      final e = edge.efficiency;
      if (e < minEta) minEta = e;
    }
  }
  return minEta;
}

/// Indices into `config.batteries` that are DC-coupled.
Set<int> _dcBatteryIndices(SimulationConfig config) {
  final topo = config.topology;
  if (topo == null) return const <int>{};
  final dcIds = <String>{
    for (final c in topo.batteryCouplings)
      if (c.coupling == BatteryCoupling.dc) c.batteryId,
  };
  final out = <int>{};
  for (var i = 0; i < config.batteries.length; i++) {
    if (dcIds.contains(config.batteries[i].id)) out.add(i);
  }
  return out;
}

void _checkStepInvariants({
  required SimulationConfig config,
  required SimulationStep step,
  required int seed,
  required double prevAggregateSoc,
  required double etaMinPath,
  required Set<int> dcBatteryIndices,
}) {
  const tol = 1e-7;
  final stepHours = config.timeStep.hours;
  String ctx() =>
      'seed=$seed step=${step.dayOfYear}/${step.stepOfDay}';

  // I1: SOC bounds per battery.
  for (var i = 0; i < config.batteries.length; i++) {
    final batt = config.batteries[i];
    final soc = step.batterySocsKwh[i];
    expect(soc, greaterThanOrEqualTo(batt.minSocKwh - tol),
        reason: '${ctx()}: battery ${batt.id} SOC=$soc < minSoc=${batt.minSocKwh}');
    expect(soc, lessThanOrEqualTo(batt.capacityKwh + tol),
        reason:
            '${ctx()}: battery ${batt.id} SOC=$soc > capacity=${batt.capacityKwh}');
  }

  // I2 + I3: rate caps per battery.
  for (var i = 0; i < config.batteries.length; i++) {
    final batt = config.batteries[i];
    final c = step.batteryChargesKwh[i];
    final d = step.batteryDischargesKwh[i];
    expect(c, lessThanOrEqualTo(batt.maxChargeKw * stepHours + tol),
        reason:
            '${ctx()}: battery ${batt.id} charge=$c exceeds rate cap ${batt.maxChargeKw * stepHours}');
    expect(d, lessThanOrEqualTo(batt.maxDischargeKw * stepHours + tol),
        reason:
            '${ctx()}: battery ${batt.id} discharge=$d exceeds rate cap ${batt.maxDischargeKw * stepHours}');
  }

  // I4: no NaN / negative kWh values.
  final scalars = <String, double>{
    'pvDcKwh': step.pvDcKwh,
    'pvAcKwh': step.pvAcKwh,
    'loadKwh': step.loadKwh,
    'selfConsumptionKwh': step.selfConsumptionKwh,
    'batteryChargeKwh': step.batteryChargeKwh,
    'batteryDischargeKwh': step.batteryDischargeKwh,
    'gridImportKwh': step.gridImportKwh,
    'gridExportKwh': step.gridExportKwh,
    'curtailedDcKwh': step.curtailedDcKwh,
    'curtailedAcKwh': step.curtailedAcKwh,
    'curtailedExportKwh': step.curtailedExportKwh,
    'dcDirectChargeKwh': step.dcDirectChargeKwh,
    'dcCurtailedKwh': step.dcCurtailedKwh,
  };
  scalars.forEach((name, value) {
    expect(value.isFinite, isTrue, reason: '${ctx()}: $name = $value not finite');
    expect(value, greaterThanOrEqualTo(-tol),
        reason: '${ctx()}: $name = $value is negative');
  });

  // I5: grid export limit (when set).
  final cap = config.gridExportLimitKw;
  if (cap != null) {
    expect(step.gridExportKwh, lessThanOrEqualTo(cap * stepHours + tol),
        reason: '${ctx()}: gridExport ${step.gridExportKwh} exceeds limit $cap');
  }

  // I6: two-sided energy balance with explicit curtailment.
  //   pvDcKwh + gridImport
  //     = loadServed + gridExport + ΔSOC
  //       + curtailedDc + curtailedAc + curtailedExport
  //       + conversion_losses
  //
  // `loadServed = loadKwh - unservedLoadKwh` covers every path that
  // delivered to load (PV, battery, banks, AND grid import). Using
  // `selfConsumptionKwh` instead would omit the grid-serving-load
  // portion, inflating the slack when batteries are empty and grid
  // covers most of the load (seen in seed 2 step 18 during testing).
  //
  // The conversion-loss slack is bounded from above by an η-derived
  // budget. Phase-4b/4c review rounds repeatedly turned up bugs that
  // dumped real energy into the unbounded "losses" term (the
  // `array → cc` edge clip silently dropped 2 kWh on a 3 kWh step
  // pre-fix). Bounding the slack forces every kWh into a delivery
  // bucket, a curtailment bucket, or a known conversion loss.
  //
  // The bound is `(1 - etaMinPath^4) × throughput`. See the inline
  // comment on `lossFactor` below for the derivation. Legitimate
  // long lossy chains (with all η at the minimum) stay inside it;
  // a 1+ kWh phantom on a 3-4 kWh PV step trips it.
  final deltaSoc = step.batterySocKwh - prevAggregateSoc;
  final loadServed = step.loadKwh - step.unservedLoadKwh;
  final inputs = step.pvDcKwh + step.gridImportKwh;
  final outputs = loadServed +
      step.gridExportKwh +
      deltaSoc +
      step.curtailedDcKwh +
      step.curtailedAcKwh +
      step.curtailedExportKwh;
  final lossSlack = inputs - outputs;
  expect(lossSlack, greaterThanOrEqualTo(-1e-6),
      reason: '${ctx()}: inputs $inputs < outputs $outputs '
          '(loadServed=$loadServed, export=${step.gridExportKwh}, '
          'ΔSOC=$deltaSoc, curtDc=${step.curtailedDcKwh}, '
          'curtAc=${step.curtailedAcKwh}, curtExp=${step.curtailedExportKwh})');
  var sumCharge = 0.0;
  var sumDischarge = 0.0;
  for (var i = 0; i < config.batteries.length; i++) {
    sumCharge += step.batteryChargesKwh[i];
    sumDischarge += step.batteryDischargesKwh[i];
  }
  final throughput = step.pvDcKwh + sumCharge + sumDischarge;
  // Worst-case 4-stage chain at the smallest η in the config. Each
  // kWh of throughput can lose up to `1 - etaMin^4` along the
  // longest realistic single-direction conversion path (array →
  // cc-edge → cc → bus-edge → inverter is 4 multiplicative stages
  // for the DC chain; PV-only paths are shorter). Multiplied across
  // `pvDc + Σchg + Σdis` this bounds the slack tight enough that a
  // kWh-scale phantom on a 3-4 kWh PV step trips it, while
  // legitimate long lossy chains (with all η at the minimum) still
  // fit under the ceiling.
  final lossFactor = 1.0 - math.pow(etaMinPath, 4).toDouble();
  final slackUpper = throughput * lossFactor + 5e-6;
  expect(lossSlack, lessThanOrEqualTo(slackUpper),
      reason: '${ctx()}: conversion-loss slack $lossSlack > bound '
          '$slackUpper (throughput=$throughput, etaMin=$etaMinPath). '
          'Some real energy is being swallowed silently — check '
          'the curtailment buckets and η accounting on each path.');

  // I8: DC-side ledger sanity check.
  //   pvDcKwh ≥ Σ DC-coupled batteryChargesKwh + curtailedDcKwh
  //
  // `batteryChargesKwh[i]` for a DC-coupled battery is bus-side DC kWh
  // (already after cc + edge η + clip — see pv_engine.dart Z. 2324-2329
  // where `dcDirectCharges[k]` is summed in). `curtailedDcKwh` is
  // reported at the array-side reference (dc_coupled_dispatch_test.dart
  // Z. 1322 documents `3 kWh PV - 1 kWh through → curtailedDcKwh = 2`).
  // Bus-side DC charge can be at most as large as the array-side PV
  // that fed it, so the bus-side sum + array-side curtailment is
  // bounded by array-side `pvDcKwh`. The remainder is PV that left
  // the DC bus as AC via the bus inverter.
  if (dcBatteryIndices.isNotEmpty || step.curtailedDcKwh > 0) {
    var dcChargeKwh = 0.0;
    for (final i in dcBatteryIndices) {
      dcChargeKwh += step.batteryChargesKwh[i];
    }
    final dcOutflow = dcChargeKwh + step.curtailedDcKwh;
    expect(step.pvDcKwh + 1e-6, greaterThanOrEqualTo(dcOutflow - 1e-6),
        reason: '${ctx()}: pvDcKwh ${step.pvDcKwh} < DC outflow '
            '$dcOutflow (dcCharge=$dcChargeKwh, '
            'curtailedDc=${step.curtailedDcKwh}). DC-side ledger '
            'over-allocated.');
  }

  // I7: AC delivery sum vs aggregate inverter cap.
  final invCapTotal = config.inverters
      .fold<double>(0.0, (s, i) => s + i.effectiveMaxAcKw * stepHours);
  expect(
    step.pvAcKwh + step.batteryDischargeKwh - tol,
    lessThanOrEqualTo(invCapTotal + tol),
    reason: '${ctx()}: pvAc ${step.pvAcKwh} + discharge ${step.batteryDischargeKwh} '
        '> sum of inverter caps $invCapTotal',
  );
}

void main() {
  group('Phase 4c — DC dispatch invariants (property test)', () {
    const sampleCount = 250;
    test('$sampleCount random topologies satisfy step-level invariants', () {
      for (var seed = 0; seed < sampleCount; seed++) {
        SimulationConfig config;
        try {
          config = _randomConfig(seed);
          config.validate();
        } catch (_) {
          // Generator can occasionally produce a topology that
          // doesn't pass `validate()` (e.g. when the random
          // batteryFed path turned out to need an MPPT-less inverter
          // but the generator put one on by accident). Skip those.
          continue;
        }
        final result = const PvSimulator().run(config);
        final etaMinPath = _etaMinPath(config);
        final dcBatteryIndices = _dcBatteryIndices(config);
        var prevSoc = config.batteries
            .fold<double>(0.0, (s, b) => s + b.effectiveInitialSocKwh);
        for (final step in result.steps) {
          _checkStepInvariants(
            config: config,
            step: step,
            seed: seed,
            prevAggregateSoc: prevSoc,
            etaMinPath: etaMinPath,
            dcBatteryIndices: dcBatteryIndices,
          );
          prevSoc = step.batterySocKwh;
        }
      }
    });
  });
}
