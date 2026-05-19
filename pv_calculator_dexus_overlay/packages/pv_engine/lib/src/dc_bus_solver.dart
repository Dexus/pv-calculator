import 'dart:math' as math;

import 'topology.dart';

/// Solves the per-step energy balance on **one** DC bus.
///
/// Phase 4b accumulated 30+ review findings, all of the same shape:
/// scattered η / cap / unit conversions across the simulator, the
/// dispatch policies, and the energy router. This solver owns the
/// bus-level balance atomically — every PV‑in, battery charge /
/// discharge, hybrid bypass to AC, and curtailment for one bus in one
/// step is decided here. Callers feed inputs and consume outputs;
/// they do not make their own routing decisions.
///
/// Allocation order (deterministic, documented):
///
///   1. **Load coverage via the bus inverter** (hybrid mode only):
///      the inverter delivers `min(loadAcShareKwh,
///      inverterAcCapRemainingKwh, pvDcInKwh × bus_eta)` AC.
///   2. **Battery charging** in input order: each battery takes
///      `min(chargeTargetKwh, chargeRateCapKwh, headroomDc,
///      remainingBusPool)`.
///   3. **Hybrid bypass export** (hybrid only): any DC left over
///      flows through the bus inverter, capped by remaining
///      AC / DC / edge headroom.
///   4. **Battery discharge** in input order: covers any
///      `loadAcShareKwh` still unmet (hybrid only), routed through
///      the bus inverter and capped by remaining AC headroom.
///   5. **Curtailment**: anything still on the DC bus that has
///      nowhere to go.
///
/// The solver enforces these invariants in `solve()`:
///
/// ```
///   pvDcInKwh + Σ dischargeDc[i]
///     = Σ chargeDc[i] + bypassDcEffective + curtailedDcKwh
///   bypassDcEffective × bus_eta = bypassAcKwh ≤ inverterAcCapRemainingKwh
///   bypassDcEffective ≤ inverterDcCapRemainingKwh and edgeMaxPowerKwh
///   Σ chargeDc[i] ≤ chargeRateCapKwh[i] per battery, headroomDc[i]
///   Σ dischargeDc[i] ≤ dischargeRateCapKwh[i] per battery
///   bus_eta = busInverter.edgeEfficiency × busInverter.inverterEfficiency
///   batteryFed mode ⇒ bypassAcKwh = 0
/// ```

/// Bus-inverter metadata for the AC bypass / discharge paths. `null`
/// on a charge-only bus (no `dcBus → inverter` edge in the topology).
class HybridInverterInfo {
  const HybridInverterInfo({
    required this.inverterId,
    required this.edgeEfficiency,
    required this.inverterEfficiency,
    required this.inverterAcCapRemainingKwh,
    this.inverterDcCapRemainingKwh,
    this.edgeMaxPowerKwh,
  });

  /// Id of the inverter on the bus's outgoing edge.
  final String inverterId;

  /// `BusEdge.efficiency` of the `dcBus → inverter` edge. Multiplied
  /// with `inverterEfficiency` to convert bus-side DC into delivered
  /// AC.
  final double edgeEfficiency;

  /// `Inverter.efficiency` of the bus inverter (DC stage own loss).
  final double inverterEfficiency;

  /// `effectiveMaxAcKw × stepHours` minus AC the inverter has already
  /// emitted via other paths (AC-side PV through MPPT, prior solvers
  /// on a shared inverter). The solver may consume up to this much
  /// AC in steps 1 + 3 + 4.
  final double inverterAcCapRemainingKwh;

  /// `Inverter.maxDcInputKw × stepHours` minus DC already consumed.
  /// `null` when the inverter has no DC-side rating. The cap applies
  /// at the inverter input — bus-side energy must be ≤ this / edgeEta
  /// before the edge loss.
  final double? inverterDcCapRemainingKwh;

  /// `BusEdge.maxPowerKw × stepHours` for the `dcBus → inverter`
  /// edge. `null` when the edge has no power cap. Limits bus-side
  /// energy crossing the edge directly.
  final double? edgeMaxPowerKwh;

  /// Combined DC→AC conversion factor `edge.eta × inverter.eta`.
  double get acPerBusDc => edgeEfficiency * inverterEfficiency;
}

/// One DC-coupled battery's input view to the solver.
class DcBusBattery {
  const DcBusBattery({
    required this.batteryIndex,
    required this.chargeRateCapKwh,
    required this.dischargeRateCapKwh,
    required this.chargeEfficiency,
    required this.dischargeEfficiency,
    required this.headroomStoredKwh,
    required this.usableStoredKwh,
    required this.chargeTargetKwh,
    required this.dischargeTargetKwh,
  });

  /// Index into the parent `SimulationConfig.batteries` list. The
  /// solver uses it only as an opaque key on its outputs.
  final int batteryIndex;

  /// `battery.maxChargeKw × stepHours` — DC-side rate cap on the
  /// energy the battery can take this step.
  final double chargeRateCapKwh;

  /// `battery.maxDischargeKw × stepHours` — DC-side rate cap on the
  /// energy the battery can give back this step.
  final double dischargeRateCapKwh;

  /// `sqrt(roundTripEfficiency)`; multiplies bus-side DC kWh into
  /// stored kWh on charge.
  final double chargeEfficiency;

  /// `sqrt(roundTripEfficiency)`; multiplies stored kWh into bus-side
  /// DC kWh on discharge.
  final double dischargeEfficiency;

  /// `capacity − soc` — how many stored kWh of headroom the battery
  /// has at step entry.
  final double headroomStoredKwh;

  /// `soc − minSoc` — how many stored kWh the battery may still give
  /// up at step entry.
  final double usableStoredKwh;

  /// Policy target: how many bus-side DC kWh of charging the battery
  /// is allowed this step. `double.infinity` means "as much as
  /// physically possible". For `BatteryReserve` this is the residual
  /// distance to the reserve ceiling expressed in bus-side DC kWh.
  final double chargeTargetKwh;

  /// Policy target: how many bus-side DC kWh of discharge are
  /// permitted. Default `double.infinity`. For policies that disable
  /// direct discharge (e.g. bank-only setups) pass `0`.
  final double dischargeTargetKwh;
}

/// Per-bus solver input.
class DcBusInput {
  const DcBusInput({
    required this.busId,
    required this.mode,
    required this.pvDcInKwh,
    required this.loadAcShareKwh,
    required this.batteries,
    required this.stepHours,
    this.busInverter,
  });

  /// Topology bus id (carried through for logging / outcome keying).
  final String busId;

  /// `hybrid` allows PV bypass and battery discharge to feed the AC
  /// bus through `busInverter`. `batteryFed` forbids any direct
  /// PV → AC path: PV that doesn't fit in the battery is curtailed.
  final BusMode mode;

  /// PV-DC available on this bus this step, AFTER any per-controller
  /// `maxInputKw` clip, `array → cc` edge η, and `cc.efficiency` have
  /// been applied by the caller. Must be ≥ 0.
  final double pvDcInKwh;

  /// AC kWh of household load assigned to this bus for direct
  /// coverage via the bus inverter. Pre-allocated by the caller from
  /// a global pool so multiple hybrid buses don't each independently
  /// reserve the full load. `0` for charge-only or batteryFed buses,
  /// or when the load is already covered by another path.
  final double loadAcShareKwh;

  /// DC-coupled batteries on this bus, in the order the dispatch
  /// policy wants them charged / discharged.
  final List<DcBusBattery> batteries;

  /// Step length in hours (carried only so the solver's outputs can
  /// be summed with the rest of the simulator's per-step kWh values
  /// without further unit work).
  final double stepHours;

  /// Bus inverter info if a `dcBus → inverter` edge exists. `null`
  /// turns this bus into a charge-only sink (no AC path, no
  /// discharge to AC).
  final HybridInverterInfo? busInverter;
}

/// Per-bus solver output.
class DcBusOutcome {
  const DcBusOutcome({
    required this.batteryChargesDcKwh,
    required this.batteryDischargesDcKwh,
    required this.bypassAcKwh,
    required this.loadCoveredAcKwh,
    required this.dischargeAcKwh,
    required this.curtailedDcKwh,
    required this.inverterAcConsumedKwh,
    required this.inverterDcConsumedKwh,
  });

  /// `batteryIndex → bus-side DC kWh charged this step`. Stored kWh
  /// gained = `chargeDcKwh × chargeEfficiency`. Entries omitted when
  /// zero.
  final Map<int, double> batteryChargesDcKwh;

  /// `batteryIndex → bus-side DC kWh discharged this step`. Stored
  /// kWh lost = `dischargeDcKwh / dischargeEfficiency`. Entries
  /// omitted when zero.
  final Map<int, double> batteryDischargesDcKwh;

  /// Surplus PV-DC that flowed through the bus inverter to AC after
  /// load coverage and battery charging. `0` for batteryFed buses.
  final double bypassAcKwh;

  /// AC kWh that the bus inverter delivered to cover `loadAcShareKwh`
  /// (capped by inverter / edge headroom). Always ≤ `loadAcShareKwh`.
  final double loadCoveredAcKwh;

  /// AC kWh delivered by discharging batteries through the bus
  /// inverter, to cover remaining load (after step 1). Caller adds
  /// this to `selfConsumption` and treats it as battery-served AC.
  final double dischargeAcKwh;

  /// PV-DC that couldn't be stored or pushed to AC and is therefore
  /// lost. Both `batteryFed` residual and "hybrid with full battery
  /// & saturated inverter" cases land here.
  final double curtailedDcKwh;

  /// Total AC the bus inverter emitted this step
  /// (`loadCoveredAcKwh + bypassAcKwh + dischargeAcKwh`). Use it to
  /// decrement an inverter's shared AC headroom across multiple
  /// solver calls (e.g. an inverter that ALSO serves the legacy
  /// AC-path PV).
  final double inverterAcConsumedKwh;

  /// Total DC the bus inverter ingested this step on its DC input
  /// (`bypass + discharge_after_battery`). Use it to decrement the
  /// inverter's shared DC input headroom across multiple paths.
  final double inverterDcConsumedKwh;
}

/// Stateless, pure-function solver. One instance can be reused
/// across steps and buses.
class DcBusSolver {
  const DcBusSolver();

  DcBusOutcome solve(DcBusInput input) {
    final pool = math.max(0.0, input.pvDcInKwh);
    final loadShare = math.max(0.0, input.loadAcShareKwh);
    final busInv = input.busInverter;
    // PV bypass / load cover via the inverter is allowed only on
    // `hybrid` buses (per `BusMode`). Battery discharge to the
    // inverter, however, is the WHOLE POINT of `batteryFed` and
    // must remain allowed — those flow paths are gated separately
    // (Codex P2 round 7 finding "batteryFed solver discharge").
    final acFromPvAllowed =
        input.mode == BusMode.hybrid && busInv != null;
    final acFromBatteryAllowed = busInv != null;

    // Live counters mutated step-by-step. `invDcRemaining` and
    // `edgeRemaining` are kept in their NATIVE units:
    //   - `invDcRemaining`: inverter-input DC kWh.
    //   - `edgeRemaining`: bus-side DC kWh (the edge sits on the bus
    //     side of the inverter).
    // The `route()` helper converts between the two via the edge η.
    var poolBusDc = pool;
    var invAcRemaining = busInv?.inverterAcCapRemainingKwh ?? 0.0;
    var invDcRemaining = busInv?.inverterDcCapRemainingKwh ?? double.infinity;
    var edgeRemaining = busInv?.edgeMaxPowerKwh ?? double.infinity;
    final edgeEta = busInv?.edgeEfficiency ?? 1.0;
    final acPerBusDc = busInv?.acPerBusDc ?? 0.0;

    final charges = <int, double>{};
    final discharges = <int, double>{};
    var loadCoveredAc = 0.0;
    var bypassAc = 0.0;
    var dischargeAc = 0.0;
    var inverterAcConsumed = 0.0;
    var inverterDcConsumed = 0.0;

    /// Routes `dcAmount` bus-side DC through the bus inverter to AC,
    /// clipping by the remaining AC, DC and edge headroom. Returns
    /// `(dcUsed, acDelivered)` — `dcUsed` may be < `dcAmount` if a
    /// cap binds.
    ///
    /// All cap conversions are explicit:
    ///   - `invDcRemaining` is at the inverter input. The bus-side
    ///     equivalent is `invDcRemaining / edgeEta`.
    ///   - `edgeRemaining` is already bus-side (the edge cap sits on
    ///     the bus side of the inverter).
    ///   - `invAcRemaining` is at the inverter output. The bus-side
    ///     equivalent is `invAcRemaining / acPerBusDc`.
    /// After routing, decrement each in its own unit
    /// (`invDcRemaining -= dcUsed × edgeEta`).
    ({double dcUsed, double acDelivered}) route(double dcAmount,
        {required bool allowed}) {
      if (!allowed || dcAmount <= 0 || acPerBusDc <= 0) {
        return (dcUsed: 0.0, acDelivered: 0.0);
      }
      var dcLimit = edgeRemaining;
      if (invDcRemaining.isFinite && edgeEta > 0) {
        final invLimitBusSide = invDcRemaining / edgeEta;
        if (invLimitBusSide < dcLimit) dcLimit = invLimitBusSide;
      }
      final acLimitAsBusDc =
          invAcRemaining <= 0 ? 0.0 : invAcRemaining / acPerBusDc;
      if (acLimitAsBusDc < dcLimit) dcLimit = acLimitAsBusDc;
      final dcUsed = math.min(dcAmount, math.max(0.0, dcLimit));
      if (dcUsed <= 0) return (dcUsed: 0.0, acDelivered: 0.0);
      final acDelivered = dcUsed * acPerBusDc;
      invAcRemaining -= acDelivered;
      if (invDcRemaining.isFinite) invDcRemaining -= dcUsed * edgeEta;
      if (edgeRemaining.isFinite) edgeRemaining -= dcUsed;
      inverterAcConsumed += acDelivered;
      inverterDcConsumed += dcUsed;
      return (dcUsed: dcUsed, acDelivered: acDelivered);
    }

    // === 1. Cover assigned AC load via the bus inverter ===
    if (acFromPvAllowed && loadShare > 0 && poolBusDc > 0) {
      final dcNeeded = acPerBusDc <= 0 ? 0.0 : loadShare / acPerBusDc;
      final routed = route(math.min(dcNeeded, poolBusDc),
          allowed: acFromPvAllowed);
      poolBusDc -= routed.dcUsed;
      loadCoveredAc = routed.acDelivered;
    }

    // === 2. Charge DC-coupled batteries from remaining DC ===
    for (final b in input.batteries) {
      if (poolBusDc <= 0) break;
      final target = math.max(0.0, b.chargeTargetKwh);
      if (target <= 0) continue;
      if (b.chargeEfficiency <= 0) continue;
      // Headroom in bus-side DC: capacity-soc / chargeEff, because
      // stored gained = dcUsed × chargeEff.
      final headroomDc = b.headroomStoredKwh / b.chargeEfficiency;
      final rateCap = b.chargeRateCapKwh;
      final take =
          math.min(poolBusDc, math.min(target, math.min(rateCap, headroomDc)));
      if (take <= 0) continue;
      charges[b.batteryIndex] = take;
      poolBusDc -= take;
    }

    // === 3. Hybrid bypass: push remaining DC to AC for export ===
    if (acFromPvAllowed && poolBusDc > 0) {
      final routed = route(poolBusDc, allowed: acFromPvAllowed);
      poolBusDc -= routed.dcUsed;
      bypassAc = routed.acDelivered;
    }

    // === 4. Battery discharge to cover any load not yet served ===
    //
    // Discharge through the bus inverter is allowed on BOTH hybrid
    // and `batteryFed` buses — the bus-mode distinction is about
    // whether PV can bypass the battery, not about whether the
    // battery can reach AC at all. `batteryFed` is specifically the
    // case where stored energy is the ONLY path to AC.
    var loadUnmetAc = math.max(0.0, loadShare - loadCoveredAc);
    if (acFromBatteryAllowed && loadUnmetAc > 0 && invAcRemaining > 0) {
      for (final b in input.batteries) {
        if (loadUnmetAc <= 0) break;
        if (invAcRemaining <= 0) break;
        final target = math.max(0.0, b.dischargeTargetKwh);
        if (target <= 0) continue;
        if (b.dischargeEfficiency <= 0) continue;
        // Bus-side DC the battery can give: usableStored × dischEff.
        final availableBusDc = b.usableStoredKwh * b.dischargeEfficiency;
        if (availableBusDc <= 0) continue;
        // Convert load (AC) and inverter remaining (AC) back to
        // bus-side DC for a clean cap chain.
        final acAsBusDc =
            acPerBusDc <= 0 ? 0.0 : loadUnmetAc / acPerBusDc;
        final invAsBusDc =
            acPerBusDc <= 0 ? 0.0 : invAcRemaining / acPerBusDc;
        final cap = [
          target,
          b.dischargeRateCapKwh,
          availableBusDc,
          acAsBusDc,
          invAsBusDc,
        ].reduce(math.min);
        if (cap <= 0) continue;
        final routed = route(cap, allowed: acFromBatteryAllowed);
        if (routed.dcUsed <= 0) continue;
        discharges[b.batteryIndex] = routed.dcUsed;
        dischargeAc += routed.acDelivered;
        loadUnmetAc -= routed.acDelivered;
      }
    }

    // === 5. Whatever's still on the bus is lost ===
    final curtailed = math.max(0.0, poolBusDc);

    return DcBusOutcome(
      batteryChargesDcKwh: Map<int, double>.unmodifiable(charges),
      batteryDischargesDcKwh: Map<int, double>.unmodifiable(discharges),
      bypassAcKwh: bypassAc,
      loadCoveredAcKwh: loadCoveredAc,
      dischargeAcKwh: dischargeAc,
      curtailedDcKwh: curtailed,
      inverterAcConsumedKwh: inverterAcConsumed,
      inverterDcConsumedKwh: inverterDcConsumed,
    );
  }
}
