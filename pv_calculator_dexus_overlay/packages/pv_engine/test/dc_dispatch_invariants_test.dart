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
///   I6: pvDcKwh + gridImport + Σ discharge ≥ load + gridExport +
///       Σ charge (the "≥" is the slack absorbing conversion losses
///       and curtailment).
///   I7: pvAcKwh + Σ discharge ≤ Σ_inverter effectiveMaxAcKw ×
///       stepHours (coarse — per-inverter caps are stricter but
///       this sum bounds the total AC delivered).
///
/// 200 random configs × up to 24 hourly steps ≈ 4800 step-invariant
/// checks. Any future patch that breaks these invariants fails the
/// test immediately with the failing config + step dumped so the
/// fix can target the root cause instead of triggering yet another
/// review round.

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
    b.mppts.add(MpptNode(id: 'mppt-${inv.id}', inverterId: inv.id));
    b.edges.add(BusEdge(
      fromId: 'mppt-${inv.id}',
      toId: inv.id,
      efficiency: inv.efficiency,
      maxPowerKw: inv.maxDcInputKw,
    ));
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
  final addDc = rng.nextBool();
  final acCoupledBatteries = <BatteryConfig>[];
  if (addDc) {
    // Bus inverter (may share with an AC inverter sometimes — but
    // keep it simple here: a separate inverter dedicated to the bus).
    final busInv = b.addInverter(
      maxAcKw: 3.0 + rng.nextDouble() * 5.0,
      eta: 0.9 + rng.nextDouble() * 0.08,
      maxDcKw: rng.nextBool() ? null : 4.0 + rng.nextDouble() * 5.0,
    );
    final mode = rng.nextDouble() < 0.4 ? BusMode.batteryFed : BusMode.hybrid;
    final bus = DcBus(id: 'dc-1', mode: mode);
    b.dcBuses.add(bus);
    final edgeEta = 0.9 + rng.nextDouble() * 0.09;
    final edgeCap = rng.nextBool() ? null : 3.0 + rng.nextDouble() * 5.0;
    b.edges.add(BusEdge(
      fromId: bus.id,
      toId: busInv.id,
      efficiency: edgeEta,
      maxPowerKw: edgeCap,
    ));
    // Charge controller + array wired to it. Use a peakKw small
    // enough that PV stays within usual sizing.
    final cc = ChargeController(
      id: 'cc-1',
      dcBusId: bus.id,
      efficiency: 0.92 + rng.nextDouble() * 0.07,
      maxInputKw: rng.nextBool() ? null : 2.0 + rng.nextDouble() * 4.0,
    );
    b.chargeControllers.add(cc);
    final dcArray = b.addArray(
      inverterId: busInv.id, // satisfies validation (inverterId must exist)
      peakKw: 1.5 + rng.nextDouble() * 3.0,
    );
    final ccEdgeEta = 0.9 + rng.nextDouble() * 0.1;
    final ccEdgeCap = rng.nextBool() ? null : 2.0 + rng.nextDouble() * 4.0;
    b.edges.add(BusEdge(
      fromId: dcArray.id,
      toId: cc.id,
      efficiency: ccEdgeEta,
      maxPowerKw: ccEdgeCap,
    ));
    // For batteryFed mode rules: exactly 1 DC battery, no extra MPPT
    // arrays on the bus inverter.
    if (mode == BusMode.batteryFed) {
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

void _checkStepInvariants({
  required SimulationConfig config,
  required SimulationStep step,
  required int seed,
  required double prevAggregateSoc,
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

  // I6: per-step energy balance with SOC tracking.
  //   pvDcKwh + gridImport = selfConsumption + gridExport + ΔSOC
  //                         + losses + curtailment.
  //
  // `losses + curtailment` ≥ 0, so the inequality
  //   pvDcKwh + gridImport ≥ selfConsumption + gridExport + ΔSOC
  // must hold (within fp tolerance). `selfConsumption` already covers
  // every load-serving path — PV-to-load, battery discharge to load,
  // bank delivery to load — so this is the physical "no energy out
  // of nowhere" check.
  final deltaSoc = step.batterySocKwh - prevAggregateSoc;
  final inputs = step.pvDcKwh + step.gridImportKwh;
  final outputs =
      step.selfConsumptionKwh + step.gridExportKwh + deltaSoc;
  expect(inputs + 1e-6, greaterThanOrEqualTo(outputs - 1e-6),
      reason: '${ctx()}: inputs $inputs < outputs $outputs '
          '(selfCons=${step.selfConsumptionKwh}, '
          'export=${step.gridExportKwh}, ΔSOC=$deltaSoc)');

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
    const sampleCount = 200;
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
        var prevSoc = config.batteries
            .fold<double>(0.0, (s, b) => s + b.effectiveInitialSocKwh);
        for (final step in result.steps) {
          _checkStepInvariants(
            config: config,
            step: step,
            seed: seed,
            prevAggregateSoc: prevSoc,
          );
          prevSoc = step.batterySocKwh;
        }
      }
    });
  });
}
