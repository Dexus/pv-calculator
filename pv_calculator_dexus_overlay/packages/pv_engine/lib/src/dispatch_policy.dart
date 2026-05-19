import 'micro_inverter_bank.dart';
import 'topology.dart';

/// Per-step input passed to a [DispatchPolicy] when it builds a
/// [DispatchPlan]. All energies are AC kWh on the household bus side
/// unless noted otherwise.
class DispatchContext {
  const DispatchContext({
    required this.hourOfDay,
    required this.dayOfYear,
    required this.stepHours,
    required this.pvAcKwh,
    required this.loadKwh,
    required this.batteryStates,
    required this.batteryCapacitiesKwh,
    required this.batteryMinSocsKwh,
    required this.batteryMaxChargeKw,
    required this.batteryMaxDischargeKw,
    required this.batteryChargeEfficiency,
    required this.batteryDischargeEfficiency,
    required this.batteryIds,
    required this.banks,
    required this.topology,
    required this.gridExportLimitKw,
    this.pvDcByBus = const {},
    this.dcBusForBattery = const {},
    this.dcBusesWithAcPath = const {},
    this.estimatedBypassAcKwh = 0.0,
    this.dcReservedForLoadByBus = const {},
  });

  final double hourOfDay;
  final int dayOfYear;
  final double stepHours;

  /// Total AC PV energy already produced on the AC bus this step.
  final double pvAcKwh;
  final double loadKwh;

  /// Per-battery state at the start of the step. Indexes align with
  /// `batteryIds`, `batteryCapacitiesKwh`, etc.
  final List<double> batteryStates;
  final List<double> batteryCapacitiesKwh;
  final List<double> batteryMinSocsKwh;
  final List<double> batteryMaxChargeKw;
  final List<double> batteryMaxDischargeKw;
  final List<double> batteryChargeEfficiency;
  final List<double> batteryDischargeEfficiency;
  final List<String> batteryIds;
  final List<MicroInverterBank> banks;
  final TopologyGraph topology;
  final double? gridExportLimitKw;

  /// Phase-4b: per-DC-bus PV energy already pooled on the bus side
  /// of the charge controllers this step (after cc clip + efficiency,
  /// before any battery charging). Empty unless the simulator detects
  /// at least one `array → chargeController` path; policies may use
  /// this to issue DC-side charge requests for DC-coupled batteries.
  final Map<String, double> pvDcByBus;

  /// Phase-4b: maps each DC-coupled battery's index in
  /// [batteryIds] to its DC bus id. Empty for AC-only topologies.
  /// Policies use this to detect that a battery's charge target
  /// must be sourced from [pvDcByBus] rather than from AC surplus.
  final Map<int, String> dcBusForBattery;

  /// Phase-4b: ids of DC buses that have a `dcBus → inverter` edge
  /// (i.e. an actual AC path for hybrid bypass). Policies use this
  /// to decide whether reserving DC for AC load makes sense — a
  /// charge-only hybrid bus (no inverter edge) cannot serve load
  /// directly, so reserving DC there would just curtail.
  final Set<String> dcBusesWithAcPath;

  /// Phase-4b: best-estimate AC that the simulator's DC pre-step
  /// will deliver via hybrid bypass after this policy returns
  /// (before any DC-coupled batteries claim part of the bus pool).
  /// Policies use it to inflate the AC surplus when deciding AC-
  /// coupled battery charging — without it, an AC-coupled battery
  /// in a mixed AC+DC scenario would see `pvAcKwh = 0` from the
  /// AC-path alone and refuse to charge from what is actually
  /// surplus PV that ends up exporting. DO NOT use this for DC
  /// reservation: it is exactly the energy being decided here.
  final double estimatedBypassAcKwh;

  /// Phase-4b: bus-side DC kWh to reserve out of [pvDcByBus] for
  /// covering household load via the bus's hybrid inverter. The
  /// simulator precomputes this per bus as
  ///   `min(remainingLoadAc, bus_inv.remainingAcKwh) / bus_inv.eta`
  /// so the reservation: (a) is expressed in the same DC kWh units
  /// as `pvDcByBus`, (b) never exceeds what the inverter can
  /// actually serve this step, and (c) is zero for charge-only
  /// hybrid buses (no `dcBus → inverter` edge) and for batteryFed
  /// buses (no AC bypass path). Policies subtract this from
  /// `pvDcByBus[B]` when sizing DC-coupled battery charge requests.
  final Map<String, double> dcReservedForLoadByBus;
}

/// Output of a [DispatchPolicy]. Carries **request** energies; the
/// router applies hard limits (rates, SOC bounds, AC caps) and may
/// scale these down. Values are AC kWh unless noted; bank discharge is
/// expressed at the **bank's AC output side** and the router converts
/// back to DC withdrawal from the source battery via the bank's
/// `inverterEfficiency`.
class DispatchPlan {
  const DispatchPlan({
    this.batteryChargeRequestsKwh = const [],
    this.batteryDirectDischargeRequestsKwh = const [],
    this.bankDeliveryRequestsKwh = const {},
    this.allowGridImport = true,
  });

  /// One entry per battery (same order as `DispatchContext.batteryIds`).
  /// `0.0` means "do not charge this battery from PV surplus this step".
  final List<double> batteryChargeRequestsKwh;

  /// One entry per battery — direct (non-bank) discharge towards
  /// household load.  Banks are accounted separately via
  /// [bankDeliveryRequestsKwh].
  final List<double> batteryDirectDischargeRequestsKwh;

  /// `bankId → requested AC delivery kWh` for this step. Banks omitted
  /// from the map deliver 0. The router caps each value against the
  /// bank's rate, the source battery's available SOC and the bank's
  /// shutdown SOC; the gap is reported as shortfall.
  final Map<String, double> bankDeliveryRequestsKwh;

  /// If true, the household may import from the grid to cover load not
  /// served by PV or batteries. If false, any unmet load is reported as
  /// `unservedLoadKwh` rather than `gridImportKwh`.
  final bool allowGridImport;
}

/// Per-step pluggable dispatch strategy.
///
/// Implementations are **pure value objects**: they may inspect the
/// context but must not retain state across steps. SOC carry-over is
/// the simulator's responsibility, not the policy's.
abstract class DispatchPolicy {
  const DispatchPolicy();

  /// Stable identifier persisted in JSON. Use kebab-case.
  String get id;

  DispatchPlan plan(DispatchContext ctx);

  Map<String, dynamic> toJson();
}
