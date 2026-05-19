import 'dart:math' as math;

import 'dispatch_policy.dart';
import 'topology.dart';

/// Default policy: PV covers load first, surplus charges every battery
/// in declared order up to full capacity, batteries discharge in
/// declared order to cover unmet load, anything left exports to grid,
/// and the grid covers whatever load remains. Reproduces the
/// pre-Phase-4 dispatch when no banks are configured.
class SelfConsumptionFirstPolicy extends DispatchPolicy {
  const SelfConsumptionFirstPolicy();

  @override
  String get id => 'self-consumption-first';

  @override
  DispatchPlan plan(DispatchContext ctx) {
    final n = ctx.batteryIds.length;
    final charge = List<double>.filled(n, 0.0);
    final discharge = List<double>.filled(n, 0.0);

    var surplus = math.max(0.0, ctx.pvAcKwh - ctx.loadKwh);
    var unmet = math.max(0.0, ctx.loadKwh - ctx.pvAcKwh);

    for (var i = 0; i < n; i++) {
      final dcBus = ctx.dcBusForBattery[i];
      if (dcBus != null) {
        // DC-coupled battery: source charge from the bus's DC pool
        // rather than the AC surplus.
        //
        // For a `hybrid` bus the bus's inverter covers any AC load not
        // already met by AC-path PV before charging the battery —
        // approximate by deducting `max(0, loadKwh − pvAcKwh)` from
        // the DC pool so a DC battery doesn't get its charge target
        // reduced by load that another array already covers on AC.
        //
        // For a `batteryFed` bus PV cannot bypass to AC at all, so
        // the entire DC pool is available for charging — subtracting
        // load would otherwise leave the battery uncharged while the
        // unreservable surplus gets curtailed and the load imports
        // from grid.
        final dcPool = ctx.pvDcByBus[dcBus] ?? 0.0;
        final bus = ctx.topology.dcBusById(dcBus);
        final isHybrid = (bus?.mode ?? BusMode.hybrid) == BusMode.hybrid;
        final remainingLoad = isHybrid
            ? math.max(0.0, ctx.loadKwh - ctx.pvAcKwh)
            : 0.0;
        final dcAvailable = math.max(0.0, dcPool - remainingLoad);
        final headroom = math.max(0.0,
            ctx.batteryCapacitiesKwh[i] - ctx.batteryStates[i]);
        final ackHeadroom = ctx.batteryChargeEfficiency[i] == 0
            ? 0.0
            : headroom / ctx.batteryChargeEfficiency[i];
        final rateCap = ctx.batteryMaxChargeKw[i] * ctx.stepHours;
        charge[i] = math.min(dcAvailable, math.min(rateCap, ackHeadroom));
        continue;
      }
      if (surplus <= 0) continue;
      final headroom = math.max(0.0, ctx.batteryCapacitiesKwh[i] - ctx.batteryStates[i]);
      final rateCap = ctx.batteryMaxChargeKw[i] * ctx.stepHours;
      // Express the request as the AC kWh going **into** the battery
      // path; the router converts via the charge efficiency. We translate
      // the headroom (stored-energy units) back into AC units so the
      // router's eta application doesn't double-clip.
      final ackHeadroom = ctx.batteryChargeEfficiency[i] == 0
          ? 0.0
          : headroom / ctx.batteryChargeEfficiency[i];
      final req = math.min(surplus, math.min(rateCap, ackHeadroom));
      if (req > 0) {
        charge[i] = req;
        surplus -= req;
      }
    }

    for (var i = 0; i < n; i++) {
      if (unmet <= 0) break;
      final usableStored = math.max(0.0, ctx.batteryStates[i] - ctx.batteryMinSocsKwh[i]);
      // discharge output in AC kWh = stored * eta_discharge
      final acAvailable = usableStored * ctx.batteryDischargeEfficiency[i];
      final rateCap = ctx.batteryMaxDischargeKw[i] * ctx.stepHours;
      final req = math.min(unmet, math.min(rateCap, acAvailable));
      if (req > 0) {
        discharge[i] = req;
        unmet -= req;
      }
    }

    return DispatchPlan(
      batteryChargeRequestsKwh: List<double>.unmodifiable(charge),
      batteryDirectDischargeRequestsKwh: List<double>.unmodifiable(discharge),
      bankDeliveryRequestsKwh: const {},
    );
  }

  @override
  Map<String, dynamic> toJson() => {'id': id};
}

/// Like SelfConsumptionFirst, but PV surplus stops charging a battery
/// once its SOC reaches `reserveSocFraction * capacity` (per battery).
/// Excess goes to grid export earlier, leaving room for later
/// reservation. Discharge below the reserve is still allowed when load
/// exceeds PV — the reserve is a *charging* ceiling, not a discharge
/// floor.
class BatteryReservePolicy extends DispatchPolicy {
  const BatteryReservePolicy({this.reserveSocFraction = 0.5});

  /// Charging stops at this fraction of nominal capacity. `0.0` =
  /// never charge from PV; `1.0` = same as `SelfConsumptionFirst`.
  final double reserveSocFraction;

  @override
  String get id => 'battery-reserve';

  @override
  DispatchPlan plan(DispatchContext ctx) {
    final n = ctx.batteryIds.length;
    final charge = List<double>.filled(n, 0.0);
    final discharge = List<double>.filled(n, 0.0);

    var surplus = math.max(0.0, ctx.pvAcKwh - ctx.loadKwh);
    var unmet = math.max(0.0, ctx.loadKwh - ctx.pvAcKwh);

    for (var i = 0; i < n; i++) {
      final cap = ctx.batteryCapacitiesKwh[i];
      final reserveCeiling = reserveSocFraction * cap;
      final headroom = math.max(0.0, reserveCeiling - ctx.batteryStates[i]);
      if (headroom <= 0) continue;
      final rateCap = ctx.batteryMaxChargeKw[i] * ctx.stepHours;
      final ackHeadroom = ctx.batteryChargeEfficiency[i] == 0
          ? 0.0
          : headroom / ctx.batteryChargeEfficiency[i];
      final dcBus = ctx.dcBusForBattery[i];
      if (dcBus != null) {
        // DC-coupled battery: like SelfConsumptionFirst but capped at
        // `reserveCeiling`. The DC pre-step honours this cap (the
        // unconditional physics path would otherwise sail past it).
        // Same load-reservation rules as SelfConsumptionFirst — only
        // reserve the *remaining* load after AC-path PV, and skip
        // reservation entirely on `batteryFed` buses where there is
        // no hybrid bypass to AC.
        final dcPool = ctx.pvDcByBus[dcBus] ?? 0.0;
        final bus = ctx.topology.dcBusById(dcBus);
        final isHybrid = (bus?.mode ?? BusMode.hybrid) == BusMode.hybrid;
        final remainingLoad = isHybrid
            ? math.max(0.0, ctx.loadKwh - ctx.pvAcKwh)
            : 0.0;
        final dcAvailable = math.max(0.0, dcPool - remainingLoad);
        charge[i] = math.min(dcAvailable, math.min(rateCap, ackHeadroom));
        continue;
      }
      if (surplus <= 0) continue;
      final req = math.min(surplus, math.min(rateCap, ackHeadroom));
      if (req > 0) {
        charge[i] = req;
        surplus -= req;
      }
    }

    for (var i = 0; i < n; i++) {
      if (unmet <= 0) break;
      final usableStored = math.max(0.0, ctx.batteryStates[i] - ctx.batteryMinSocsKwh[i]);
      final acAvailable = usableStored * ctx.batteryDischargeEfficiency[i];
      final rateCap = ctx.batteryMaxDischargeKw[i] * ctx.stepHours;
      final req = math.min(unmet, math.min(rateCap, acAvailable));
      if (req > 0) {
        discharge[i] = req;
        unmet -= req;
      }
    }

    return DispatchPlan(
      batteryChargeRequestsKwh: List<double>.unmodifiable(charge),
      batteryDirectDischargeRequestsKwh: List<double>.unmodifiable(discharge),
    );
  }

  @override
  Map<String, dynamic> toJson() => {'id': id, 'reserveSocFraction': reserveSocFraction};
}

/// Bank-centric policy: every micro-inverter bank tries to hit its
/// scheduled AC target every step, drawing from its source battery.
/// PV charges batteries normally first; whatever load remains after
/// bank output is covered by grid import.
///
/// Direct battery discharge to household load is disabled — when banks
/// are configured the user expects them to be the only discharge path.
class ConstantFeed24hPolicy extends DispatchPolicy {
  const ConstantFeed24hPolicy();

  @override
  String get id => 'constant-feed-24h';

  @override
  DispatchPlan plan(DispatchContext ctx) {
    final n = ctx.batteryIds.length;
    final charge = List<double>.filled(n, 0.0);
    final discharge = List<double>.filled(n, 0.0);

    var surplus = math.max(0.0, ctx.pvAcKwh - ctx.loadKwh);

    for (var i = 0; i < n; i++) {
      if (surplus <= 0) break;
      final headroom = math.max(0.0, ctx.batteryCapacitiesKwh[i] - ctx.batteryStates[i]);
      final rateCap = ctx.batteryMaxChargeKw[i] * ctx.stepHours;
      final ackHeadroom = ctx.batteryChargeEfficiency[i] == 0
          ? 0.0
          : headroom / ctx.batteryChargeEfficiency[i];
      final req = math.min(surplus, math.min(rateCap, ackHeadroom));
      if (req > 0) {
        charge[i] = req;
        surplus -= req;
      }
    }

    final bankRequests = <String, double>{};
    for (final bank in ctx.banks) {
      final targetKwh = bank.targetKwAt(ctx.hourOfDay) * ctx.stepHours;
      if (targetKwh > 0) {
        bankRequests[bank.id] = targetKwh;
      }
    }

    return DispatchPlan(
      batteryChargeRequestsKwh: List<double>.unmodifiable(charge),
      batteryDirectDischargeRequestsKwh: List<double>.unmodifiable(discharge),
      bankDeliveryRequestsKwh: Map.unmodifiable(bankRequests),
    );
  }

  @override
  Map<String, dynamic> toJson() => {'id': id};
}

/// Bank-centric policy that only delivers inside the bank's schedule
/// windows (which already encode hours-of-day). Behaves identically to
/// `ConstantFeed24hPolicy` when the bank schedule is `AlwaysOnSchedule`;
/// the distinction is mainly a UX one — users who pick this policy
/// expect to also configure a `TimeWindowSchedule` on each bank.
class TimeWindowFeedPolicy extends ConstantFeed24hPolicy {
  const TimeWindowFeedPolicy();

  @override
  String get id => 'time-window-feed';
}

/// Wraps another policy and toggles grid-import behaviour. When
/// `allowGridImport` is false, unmet load is reported as
/// `unservedLoadKwh` instead of being silently imported — useful for
/// off-grid / islanded scenarios.
class GridAssistPolicy extends DispatchPolicy {
  const GridAssistPolicy({this.inner = const SelfConsumptionFirstPolicy(), this.allowGridImport = false});

  final DispatchPolicy inner;
  final bool allowGridImport;

  @override
  String get id => 'grid-assist';

  @override
  DispatchPlan plan(DispatchContext ctx) {
    final base = inner.plan(ctx);
    return DispatchPlan(
      batteryChargeRequestsKwh: base.batteryChargeRequestsKwh,
      batteryDirectDischargeRequestsKwh: base.batteryDirectDischargeRequestsKwh,
      bankDeliveryRequestsKwh: base.bankDeliveryRequestsKwh,
      allowGridImport: allowGridImport,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'allowGridImport': allowGridImport,
        'inner': inner.toJson(),
      };
}

/// Decodes any of the built-in policies from `toJson()` output. UI
/// drafts use this when loading a v2 project file.
DispatchPolicy dispatchPolicyFromJson(Map<String, dynamic> json) {
  final id = json['id'] as String?;
  switch (id) {
    case 'self-consumption-first':
      return const SelfConsumptionFirstPolicy();
    case 'battery-reserve':
      return BatteryReservePolicy(
        reserveSocFraction: (json['reserveSocFraction'] as num?)?.toDouble() ?? 0.5,
      );
    case 'constant-feed-24h':
      return const ConstantFeed24hPolicy();
    case 'time-window-feed':
      return const TimeWindowFeedPolicy();
    case 'grid-assist':
      final innerJson = json['inner'];
      return GridAssistPolicy(
        inner: innerJson is Map
            ? dispatchPolicyFromJson(innerJson.cast<String, dynamic>())
            : const SelfConsumptionFirstPolicy(),
        allowGridImport: json['allowGridImport'] as bool? ?? false,
      );
    default:
      throw ArgumentError('Unknown DispatchPolicy id: $id');
  }
}
