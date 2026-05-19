import 'dart:math' as math;

import 'dispatch_policy.dart';

/// Default policy: PV covers load first, surplus charges every battery
/// in declared order up to full capacity, batteries discharge in
/// declared order to cover unmet load, anything left exports to grid,
/// and the grid covers whatever load remains.
///
/// Phase 4c: policies emit per-battery **ceilings** (rate cap +
/// headroom-to-capacity); the `EnergyRouter` / `DcBusSolver`
/// downstream cap them against actual surplus / load. This means an
/// AC-coupled battery in a mixed AC + DC topology naturally picks up
/// any hybrid bypass AC produced by the solver, without the policy
/// needing to estimate it ahead of time.
class SelfConsumptionFirstPolicy extends DispatchPolicy {
  const SelfConsumptionFirstPolicy();

  @override
  String get id => 'self-consumption-first';

  @override
  DispatchPlan plan(DispatchContext ctx) {
    final n = ctx.batteryIds.length;
    final charge = List<double>.filled(n, 0.0);
    final discharge = List<double>.filled(n, 0.0);

    for (var i = 0; i < n; i++) {
      final headroomStored = math.max(0.0,
          ctx.batteryCapacitiesKwh[i] - ctx.batteryStates[i]);
      if (headroomStored > 0 && ctx.batteryChargeEfficiency[i] > 0) {
        final rateCap = ctx.batteryMaxChargeKw[i] * ctx.stepHours;
        final ackHeadroom = headroomStored / ctx.batteryChargeEfficiency[i];
        charge[i] = math.min(rateCap, ackHeadroom);
      }
      final usableStored = math.max(0.0,
          ctx.batteryStates[i] - ctx.batteryMinSocsKwh[i]);
      if (usableStored > 0) {
        final acAvailable = usableStored * ctx.batteryDischargeEfficiency[i];
        final rateCap = ctx.batteryMaxDischargeKw[i] * ctx.stepHours;
        discharge[i] = math.min(rateCap, acAvailable);
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

/// Like SelfConsumptionFirst, but charges stop at a reserve fraction
/// of nominal capacity. Discharge below the reserve is still allowed
/// when load exceeds PV — the reserve is a *charging* ceiling, not a
/// discharge floor.
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

    for (var i = 0; i < n; i++) {
      final reserveCeiling =
          reserveSocFraction * ctx.batteryCapacitiesKwh[i];
      final headroom = math.max(0.0, reserveCeiling - ctx.batteryStates[i]);
      if (headroom > 0 && ctx.batteryChargeEfficiency[i] > 0) {
        final rateCap = ctx.batteryMaxChargeKw[i] * ctx.stepHours;
        final ackHeadroom = headroom / ctx.batteryChargeEfficiency[i];
        charge[i] = math.min(rateCap, ackHeadroom);
      }
      final usableStored = math.max(0.0,
          ctx.batteryStates[i] - ctx.batteryMinSocsKwh[i]);
      if (usableStored > 0) {
        final acAvailable = usableStored * ctx.batteryDischargeEfficiency[i];
        final rateCap = ctx.batteryMaxDischargeKw[i] * ctx.stepHours;
        discharge[i] = math.min(rateCap, acAvailable);
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

    for (var i = 0; i < n; i++) {
      final headroomStored = math.max(0.0,
          ctx.batteryCapacitiesKwh[i] - ctx.batteryStates[i]);
      if (headroomStored > 0 && ctx.batteryChargeEfficiency[i] > 0) {
        final rateCap = ctx.batteryMaxChargeKw[i] * ctx.stepHours;
        final ackHeadroom = headroomStored / ctx.batteryChargeEfficiency[i];
        charge[i] = math.min(rateCap, ackHeadroom);
      }
      // discharge[i] = 0: banks handle all output for this policy.
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
/// windows. Inherits everything from [ConstantFeed24hPolicy]; the
/// scheduling itself lives on the bank.
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
