import 'dart:math' as math;

import 'dispatch_policy.dart';
import 'topology.dart';

/// Compute the DC-side charge request for battery [i] on a DC-coupled
/// bus, sharing a per-bus DC budget with any earlier DC-coupled
/// batteries on the same bus (mutates [dcBudgetByBus] in place). On
/// `hybrid` buses, reserves the remaining household load (load not yet
/// covered by `ctx.pvAcKwh`) so the bus's hybrid inverter still has
/// energy to serve self-consumption first; on `batteryFed` buses there
/// is no AC bypass, so the entire DC pool is available for charging.
///
/// [headroomStored] is the storage-side headroom in kWh (e.g. up to
/// capacity, or up to a policy's reserve ceiling). Returns the charge
/// request in `AC-equivalent kWh going into the battery path` (matching
/// the convention `EnergyRouter.apply` expects).
double _dcChargeRequest({
  required DispatchContext ctx,
  required int i,
  required String dcBus,
  required double headroomStored,
  required Map<String, double> dcBudgetByBus,
}) {
  if (headroomStored <= 0) return 0.0;
  // Initialise the per-bus budget on the first DC-coupled battery on
  // this bus; subsequent batteries decrement what the earlier ones
  // already requested so the load reservation isn't double-counted.
  final budget = dcBudgetByBus.putIfAbsent(dcBus, () {
    final pool = ctx.pvDcByBus[dcBus] ?? 0.0;
    final bus = ctx.topology.dcBusById(dcBus);
    final isHybrid = (bus?.mode ?? BusMode.hybrid) == BusMode.hybrid;
    final remainingLoad =
        isHybrid ? math.max(0.0, ctx.loadKwh - ctx.pvAcKwh) : 0.0;
    return math.max(0.0, pool - remainingLoad);
  });
  if (budget <= 0) return 0.0;
  final ackHeadroom = ctx.batteryChargeEfficiency[i] == 0
      ? 0.0
      : headroomStored / ctx.batteryChargeEfficiency[i];
  final rateCap = ctx.batteryMaxChargeKw[i] * ctx.stepHours;
  final req = math.min(budget, math.min(rateCap, ackHeadroom));
  dcBudgetByBus[dcBus] = budget - req;
  return req;
}

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
    final dcBudgetByBus = <String, double>{};

    for (var i = 0; i < n; i++) {
      final dcBus = ctx.dcBusForBattery[i];
      if (dcBus != null) {
        final headroomStored = math.max(0.0,
            ctx.batteryCapacitiesKwh[i] - ctx.batteryStates[i]);
        charge[i] = _dcChargeRequest(
          ctx: ctx,
          i: i,
          dcBus: dcBus,
          headroomStored: headroomStored,
          dcBudgetByBus: dcBudgetByBus,
        );
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
    final dcBudgetByBus = <String, double>{};

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
        // `reserveCeiling` (headroom is reserveCeiling-soc, not
        // capacity-soc). The shared helper still uses a per-bus
        // budget so multiple DC batteries on one hybrid bus don't
        // each independently subtract the same load reservation.
        charge[i] = _dcChargeRequest(
          ctx: ctx,
          i: i,
          dcBus: dcBus,
          headroomStored: headroom,
          dcBudgetByBus: dcBudgetByBus,
        );
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
    final dcBudgetByBus = <String, double>{};

    for (var i = 0; i < n; i++) {
      final dcBus = ctx.dcBusForBattery[i];
      if (dcBus != null) {
        // DC-coupled battery: use the shared per-bus DC budget rather
        // than the AC surplus, otherwise an `array → cc → batteryFed`
        // setup would request 0 charge and the simulator's DC pre-step
        // would curtail all PV — leaving the bank with an empty
        // battery to draw from.
        final headroomStored = math.max(0.0,
            ctx.batteryCapacitiesKwh[i] - ctx.batteryStates[i]);
        charge[i] = _dcChargeRequest(
          ctx: ctx,
          i: i,
          dcBus: dcBus,
          headroomStored: headroomStored,
          dcBudgetByBus: dcBudgetByBus,
        );
        continue;
      }
      if (surplus <= 0) continue;
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
