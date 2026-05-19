// Directed energy graph linking PV arrays, MPPT inputs, inverters,
// charge controllers, buses, batteries and micro-inverter banks. The
// Phase 4 domain model — extended in Phase 4b with `ChargeController`
// and `BusMode` so the simulator actually routes DC-coupled flows
// (PV → charge controller → DC bus → battery / hybrid inverter).
//
// The graph is *descriptive*: edges carry efficiency and power limits,
// but the simulator continues to enforce those limits via the component
// fields (`Inverter.efficiency`, `Inverter.maxDcInputKw`,
// `Inverter.effectiveMaxAcKw`, `BatteryConfig.maxChargeKw`, etc.). The
// topology answers questions that flat lists cannot:
//   1. Is a battery AC-coupled (charges via the household AC bus, the
//      legacy behaviour) or DC-coupled to a specific DC bus (handled
//      in `_simulateStep`'s DC-side pre-dispatch in Phase 4b)?
//   2. Which AC bus does each inverter / micro-inverter bank feed?
//      Currently a single shared AC bus, but the schema allows multiple
//      in future (e.g. islanding scenarios).
//   3. Does a given DC bus permit PV to bypass a full battery directly
//      to the inverter (`BusMode.hybrid`) or must PV reach AC only via
//      the battery's round-trip (`BusMode.batteryFed`)?
//
// Use `TopologyGraph.fromLegacy(...)` to derive a default graph from
// the existing `arrays + inverters + batteries + banks` lists; the
// adapter keeps every pre-Phase-4 project running without explicit
// topology configuration.

enum BatteryCoupling { ac, dc }

/// Operating mode of a DC bus.
///
/// `hybrid` (default, legacy-equivalent): PV-DC may bypass the battery
/// and flow to a hybrid inverter on the same bus when the battery is
/// full or doesn't request charging — i.e. the inverter sees both PV-DC
/// and battery-DC.
///
/// `batteryFed`: PV-DC cannot reach the bus's inverter directly. Any
/// PV-DC that exceeds the battery's charge request is curtailed; AC
/// output is only available via the battery's discharge round-trip.
enum BusMode { hybrid, batteryFed }

class DcBus {
  const DcBus({required this.id, this.label = '', this.mode = BusMode.hybrid});
  final String id;
  final String label;
  final BusMode mode;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'id': id, 'label': label};
    // Emit only when set, so legacy projects round-trip byte-identically.
    if (mode != BusMode.hybrid) {
      json['mode'] = mode.name;
    }
    return json;
  }

  static DcBus fromJson(Map<String, dynamic> json) {
    final modeName = json['mode'] as String?;
    final mode = modeName == null
        ? BusMode.hybrid
        : BusMode.values.firstWhere(
            (m) => m.name == modeName,
            orElse: () => throw ArgumentError('Unknown BusMode: $modeName'),
          );
    return DcBus(
      id: (json['id'] as String).trim(),
      label: json['label'] as String? ?? '',
      mode: mode,
    );
  }
}

class AcBus {
  const AcBus({required this.id, this.label = ''});
  final String id;
  final String label;

  Map<String, dynamic> toJson() => {'id': id, 'label': label};
  static AcBus fromJson(Map<String, dynamic> json) =>
      AcBus(id: (json['id'] as String).trim(), label: json['label'] as String? ?? '');
}

/// One MPPT input on an inverter. PV arrays attach here, and the input
/// optionally enforces a DC power cap (`maxDcInputKw`).
class MpptNode {
  const MpptNode({required this.id, required this.inverterId, this.label = ''});
  final String id;
  final String inverterId;
  final String label;

  Map<String, dynamic> toJson() => {'id': id, 'inverterId': inverterId, 'label': label};
  static MpptNode fromJson(Map<String, dynamic> json) => MpptNode(
        id: (json['id'] as String).trim(),
        inverterId: (json['inverterId'] as String).trim(),
        label: json['label'] as String? ?? '',
      );
}

/// MPPT charge controller (Laderegler) feeding a DC bus from PV arrays.
///
/// Sits between PV arrays (DC side) and a [DcBus] (battery / hybrid-
/// inverter side). [efficiency] is multiplicative, applied to the DC
/// energy passing through; [maxInputKw] optionally clips the PV-side
/// power before the efficiency conversion (overflow is reported as
/// DC-side curtailment by the simulator).
///
/// PV arrays are routed to a charge controller via a `BusEdge fromId:
/// arrayId, toId: chargeControllerId` entry in [TopologyGraph.edges];
/// the battery / inverter side is implicit via [dcBusId].
class ChargeController {
  const ChargeController({
    required this.id,
    required this.dcBusId,
    this.efficiency = 0.97,
    this.maxInputKw,
    this.standbyW = 0.0,
    this.label = '',
  });

  final String id;
  final String dcBusId;
  final double efficiency;
  final double? maxInputKw;
  final double standbyW;
  final String label;

  void validate() {
    if (id.trim().isEmpty) {
      throw ArgumentError('ChargeController id must not be empty.');
    }
    if (efficiency <= 0 || efficiency > 1) {
      throw ArgumentError('ChargeController $id efficiency must be in (0, 1].');
    }
    final cap = maxInputKw;
    if (cap != null && cap <= 0) {
      throw ArgumentError('ChargeController $id maxInputKw must be positive.');
    }
    if (standbyW < 0) {
      throw ArgumentError('ChargeController $id standbyW must not be negative.');
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dcBusId': dcBusId,
        'efficiency': efficiency,
        'maxInputKw': maxInputKw,
        'standbyW': standbyW,
        'label': label,
      };

  static ChargeController fromJson(Map<String, dynamic> json) => ChargeController(
        id: (json['id'] as String).trim(),
        dcBusId: (json['dcBusId'] as String).trim(),
        efficiency: (json['efficiency'] as num?)?.toDouble() ?? 0.97,
        maxInputKw: (json['maxInputKw'] as num?)?.toDouble(),
        standbyW: (json['standbyW'] as num?)?.toDouble() ?? 0.0,
        label: json['label'] as String? ?? '',
      );
}

/// One directed edge in the topology. `fromId` and `toId` refer to any
/// node id (`arrayId`, `mpptId`, `inverterId`, `dcBusId`, `acBusId`,
/// `batteryId`, `bankId`). `efficiency` is multiplicative; `maxPowerKw`
/// caps the instantaneous flow.
class BusEdge {
  const BusEdge({
    required this.fromId,
    required this.toId,
    this.efficiency = 1.0,
    this.maxPowerKw,
    this.standbyW = 0.0,
  });

  final String fromId;
  final String toId;
  final double efficiency;
  final double? maxPowerKw;
  final double standbyW;

  void validate() {
    if (efficiency <= 0 || efficiency > 1) {
      throw ArgumentError('Topology edge $fromId→$toId efficiency must be in (0, 1].');
    }
    final cap = maxPowerKw;
    if (cap != null && cap < 0) {
      throw ArgumentError('Topology edge $fromId→$toId maxPowerKw must not be negative.');
    }
    if (standbyW < 0) {
      throw ArgumentError('Topology edge $fromId→$toId standbyW must not be negative.');
    }
  }

  Map<String, dynamic> toJson() => {
        'fromId': fromId,
        'toId': toId,
        'efficiency': efficiency,
        'maxPowerKw': maxPowerKw,
        'standbyW': standbyW,
      };

  static BusEdge fromJson(Map<String, dynamic> json) => BusEdge(
        fromId: (json['fromId'] as String).trim(),
        toId: (json['toId'] as String).trim(),
        efficiency: (json['efficiency'] as num?)?.toDouble() ?? 1.0,
        maxPowerKw: (json['maxPowerKw'] as num?)?.toDouble(),
        standbyW: (json['standbyW'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Per-battery coupling: AC-coupled (legacy, charged from the AC bus)
/// or DC-coupled to a specific inverter's DC bus.
///
/// [inverterId] (optional, only meaningful for AC-coupled batteries)
/// names the inverter that sits between this battery and the AC bus.
/// When set, [EnergyRouter] uses that inverter's `effectiveMaxAcKw` as
/// the AC discharge cap shared across all banks fed from this battery,
/// per Architektur §5.3 `min(targetPowerW, battery.maxDischargeW,
/// inverterLimitW)`. When `null` the router falls back to the legacy
/// behaviour of using `BatteryConfig.maxDischargeKw` as the AC cap.
class BatteryCouplingSpec {
  const BatteryCouplingSpec({
    required this.batteryId,
    this.coupling = BatteryCoupling.ac,
    this.dcBusId,
    this.inverterId,
  });

  final String batteryId;
  final BatteryCoupling coupling;
  final String? dcBusId;
  final String? inverterId;

  void validate() {
    if (coupling == BatteryCoupling.dc && (dcBusId == null || dcBusId!.isEmpty)) {
      throw ArgumentError('Topology coupling for battery $batteryId is DC-coupled but no dcBusId is set.');
    }
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'batteryId': batteryId,
      'coupling': coupling.name,
      'dcBusId': dcBusId,
    };
    if (inverterId != null) {
      json['inverterId'] = inverterId;
    }
    return json;
  }

  static BatteryCouplingSpec fromJson(Map<String, dynamic> json) {
    final name = json['coupling'] as String? ?? 'ac';
    final coupling = BatteryCoupling.values.firstWhere(
      (c) => c.name == name,
      orElse: () => throw ArgumentError('Unknown BatteryCoupling: $name'),
    );
    return BatteryCouplingSpec(
      batteryId: (json['batteryId'] as String).trim(),
      coupling: coupling,
      dcBusId: json['dcBusId'] as String?,
      inverterId: json['inverterId'] as String?,
    );
  }
}

/// Full topology graph for one [SimulationConfig].
class TopologyGraph {
  const TopologyGraph({
    this.dcBuses = const [],
    this.acBuses = const [],
    this.mppts = const [],
    this.edges = const [],
    this.batteryCouplings = const [],
    this.chargeControllers = const [],
  });

  final List<DcBus> dcBuses;
  final List<AcBus> acBuses;
  final List<MpptNode> mppts;
  final List<BusEdge> edges;
  final List<BatteryCouplingSpec> batteryCouplings;
  final List<ChargeController> chargeControllers;

  BatteryCouplingSpec couplingFor(String batteryId) {
    for (final spec in batteryCouplings) {
      if (spec.batteryId == batteryId) return spec;
    }
    return BatteryCouplingSpec(batteryId: batteryId);
  }

  /// All charge controllers feeding [dcBusId] (the battery / inverter
  /// side of the bus).
  Iterable<ChargeController> controllersForBus(String dcBusId) sync* {
    for (final cc in chargeControllers) {
      if (cc.dcBusId == dcBusId) yield cc;
    }
  }

  DcBus? dcBusById(String id) {
    for (final b in dcBuses) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Build a default topology from the flat lists in `SimulationConfig`
  /// when no explicit topology is supplied. Layout:
  ///   * one shared AC bus `ac-main`,
  ///   * one MPPT node per inverter (id `mppt-<inverterId>`),
  ///   * one DC bus per inverter (id `dc-<inverterId>`),
  ///   * arrays edge into their inverter's MPPT,
  ///   * inverters edge into `ac-main` with the inverter's AC cap,
  ///   * banks edge into `ac-main`,
  ///   * batteries are AC-coupled by default (legacy behaviour).
  ///
  /// This reproduces the pre-Phase-4 simulation exactly when the legacy
  /// `SelfConsumptionFirst` policy is used and no banks are configured.
  factory TopologyGraph.fromLegacy({
    required Iterable<String> arrayIds,
    required Iterable<String> inverterIds,
    required Iterable<String> batteryIds,
    required Iterable<String> bankIds,
    Iterable<MapEntry<String, String>>? arrayToInverter,
    Iterable<MapEntry<String, double?>>? inverterMaxAc,
    Iterable<MapEntry<String, double?>>? inverterMaxDcInput,
    Iterable<MapEntry<String, double>>? inverterEfficiency,
    Iterable<ChargeController>? chargeControllers,
  }) {
    final dcBuses = <DcBus>[];
    final mppts = <MpptNode>[];
    final edges = <BusEdge>[];
    const acMain = AcBus(id: 'ac-main', label: 'Main AC bus');

    final acByInverter = <String, double?>{
      for (final e in (inverterMaxAc ?? const <MapEntry<String, double?>>[])) e.key: e.value,
    };
    final dcByInverter = <String, double?>{
      for (final e in (inverterMaxDcInput ?? const <MapEntry<String, double?>>[])) e.key: e.value,
    };
    final etaByInverter = <String, double>{
      for (final e in (inverterEfficiency ?? const <MapEntry<String, double>>[])) e.key: e.value,
    };

    for (final inv in inverterIds) {
      mppts.add(MpptNode(id: 'mppt-$inv', inverterId: inv));
      dcBuses.add(DcBus(id: 'dc-$inv'));
      // MPPT → inverter input (DC cap lives on the MPPT edge).
      edges.add(BusEdge(
        fromId: 'mppt-$inv',
        toId: inv,
        efficiency: etaByInverter[inv] ?? 1.0,
        maxPowerKw: dcByInverter[inv],
      ));
      // Inverter → AC bus (AC cap lives on the AC edge).
      edges.add(BusEdge(
        fromId: inv,
        toId: acMain.id,
        efficiency: 1.0,
        maxPowerKw: acByInverter[inv],
      ));
    }

    for (final entry in arrayToInverter ?? const <MapEntry<String, String>>[]) {
      edges.add(BusEdge(fromId: entry.key, toId: 'mppt-${entry.value}'));
    }

    final couplings = [
      for (final id in batteryIds) BatteryCouplingSpec(batteryId: id),
    ];

    // Banks already carry their source battery id; no extra edges needed
    // for the MVP, since the router walks `bank.batteryId` directly.
    // We still record one edge per bank for documentation/visualisation.
    final bankSet = bankIds.toSet();
    for (final bankId in bankSet) {
      edges.add(BusEdge(fromId: bankId, toId: acMain.id));
    }

    return TopologyGraph(
      dcBuses: dcBuses,
      acBuses: [acMain],
      mppts: mppts,
      edges: edges,
      batteryCouplings: couplings,
      chargeControllers: chargeControllers == null
          ? const []
          : List<ChargeController>.unmodifiable(chargeControllers),
    );
  }

  void validate({
    required Set<String> arrayIds,
    required Set<String> inverterIds,
    required Set<String> batteryIds,
    required Set<String> bankIds,
  }) {
    final dcIds = {for (final b in dcBuses) b.id};
    final acIds = {for (final b in acBuses) b.id};
    final mpptIds = {for (final m in mppts) m.id};
    final ccIds = {for (final c in chargeControllers) c.id};

    final dupDc = _firstDuplicate(dcBuses.map((b) => b.id));
    if (dupDc != null) throw ArgumentError('Duplicate topology dcBus id: $dupDc.');
    final dupAc = _firstDuplicate(acBuses.map((b) => b.id));
    if (dupAc != null) throw ArgumentError('Duplicate topology acBus id: $dupAc.');
    final dupMppt = _firstDuplicate(mppts.map((m) => m.id));
    if (dupMppt != null) throw ArgumentError('Duplicate topology mppt id: $dupMppt.');
    final dupCc = _firstDuplicate(chargeControllers.map((c) => c.id));
    if (dupCc != null) throw ArgumentError('Duplicate topology chargeController id: $dupCc.');

    for (final m in mppts) {
      if (!inverterIds.contains(m.inverterId)) {
        throw ArgumentError('Topology MPPT ${m.id} references missing inverter ${m.inverterId}.');
      }
    }

    for (final cc in chargeControllers) {
      cc.validate();
      if (!dcIds.contains(cc.dcBusId)) {
        throw ArgumentError(
            'Topology chargeController ${cc.id} references unknown dcBus ${cc.dcBusId}.');
      }
    }

    final knownIds = {
      ...arrayIds,
      ...inverterIds,
      ...batteryIds,
      ...bankIds,
      ...dcIds,
      ...acIds,
      ...mpptIds,
      ...ccIds,
    };
    for (final e in edges) {
      e.validate();
      if (!knownIds.contains(e.fromId)) {
        throw ArgumentError('Topology edge ${e.fromId}→${e.toId} has unknown source ${e.fromId}.');
      }
      if (!knownIds.contains(e.toId)) {
        throw ArgumentError('Topology edge ${e.fromId}→${e.toId} has unknown target ${e.toId}.');
      }
    }

    final coupledIds = <String>{};
    for (final c in batteryCouplings) {
      c.validate();
      if (!batteryIds.contains(c.batteryId)) {
        throw ArgumentError('Topology coupling references unknown battery ${c.batteryId}.');
      }
      if (!coupledIds.add(c.batteryId)) {
        throw ArgumentError('Duplicate topology coupling for battery ${c.batteryId}.');
      }
      if (c.coupling == BatteryCoupling.dc && !dcIds.contains(c.dcBusId)) {
        throw ArgumentError('Topology coupling for ${c.batteryId} references unknown dcBus ${c.dcBusId}.');
      }
      if (c.inverterId != null && !inverterIds.contains(c.inverterId)) {
        throw ArgumentError('Topology coupling for ${c.batteryId} references unknown inverter ${c.inverterId}.');
      }
    }

    // === Phase 4b cross-references ===
    // Rule 2: DC-coupled battery ⇒ its bus is fed by ≥ 1 chargeController.
    final ccsByBus = <String, int>{};
    for (final cc in chargeControllers) {
      ccsByBus.update(cc.dcBusId, (n) => n + 1, ifAbsent: () => 1);
    }
    for (final c in batteryCouplings) {
      if (c.coupling == BatteryCoupling.dc) {
        final busId = c.dcBusId;
        if (busId != null && (ccsByBus[busId] ?? 0) == 0) {
          throw ArgumentError(
              'DC-coupled battery ${c.batteryId} references dcBus $busId, '
              'but no chargeController feeds that bus — add a chargeController '
              "with dcBusId: '$busId' or change coupling to ac.");
        }
      }
    }

    // Rule 5: no array can be on both a charge-controller path (array
    // → cc) and an inverter-MPPT path (array → mppt) at the same time.
    final ccNodeIds = {for (final c in chargeControllers) c.id};
    final mpptNodeIds = {for (final m in mppts) m.id};
    final arrayToCc = <String>{};
    final arrayToMppt = <String>{};
    for (final e in edges) {
      if (ccNodeIds.contains(e.toId)) arrayToCc.add(e.fromId);
      if (mpptNodeIds.contains(e.toId)) arrayToMppt.add(e.fromId);
    }
    for (final arrayId in arrayToCc) {
      if (arrayToMppt.contains(arrayId)) {
        throw ArgumentError(
            'PV array $arrayId is wired to both a chargeController and an '
            'MPPT — pick exactly one path (DC-coupled or AC-coupled).');
      }
    }

    // Rules 3 + 4: every `BusMode.batteryFed` DC bus must have exactly
    // one DC-coupled battery and exactly one outgoing edge into an
    // inverter, and that inverter must not also have an array→MPPT
    // path (PV must arrive via a chargeController on this bus).
    final dcBatteryCountByBus = <String, int>{};
    for (final c in batteryCouplings) {
      if (c.coupling == BatteryCoupling.dc && c.dcBusId != null) {
        dcBatteryCountByBus.update(c.dcBusId!, (n) => n + 1,
            ifAbsent: () => 1);
      }
    }
    final mpptsByInverter = <String, Set<String>>{};
    for (final m in mppts) {
      mpptsByInverter.putIfAbsent(m.inverterId, () => <String>{}).add(m.id);
    }
    for (final bus in dcBuses) {
      if (bus.mode != BusMode.batteryFed) continue;
      final batteryCount = dcBatteryCountByBus[bus.id] ?? 0;
      if (batteryCount != 1) {
        throw ArgumentError(
            'batteryFed dcBus ${bus.id} must have exactly one DC-coupled '
            'battery (found $batteryCount). Switch to BusMode.hybrid for '
            'multi-battery or no-battery buses.');
      }
      final outgoingInverters = <String>[
        for (final e in edges)
          if (e.fromId == bus.id && inverterIds.contains(e.toId)) e.toId,
      ];
      if (outgoingInverters.length != 1) {
        throw ArgumentError(
            'batteryFed dcBus ${bus.id} must have exactly one outgoing '
            'inverter edge (found ${outgoingInverters.length}).');
      }
      // The inverter on a batteryFed bus must not receive any AC-path
      // PV (which would defeat the "PV only via battery" semantics).
      final invId = outgoingInverters.single;
      final mpptsOfInv = mpptsByInverter[invId] ?? const <String>{};
      for (final e in edges) {
        if (mpptsOfInv.contains(e.toId)) {
          throw ArgumentError(
              'batteryFed dcBus ${bus.id}: inverter $invId still has a PV '
              "array (edge ${e.fromId} → ${e.toId}) on its MPPT path. "
              'Route the array through a chargeController on ${bus.id} '
              'or switch the bus to BusMode.hybrid.');
        }
      }
    }
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'dcBuses': dcBuses.map((b) => b.toJson()).toList(),
      'acBuses': acBuses.map((b) => b.toJson()).toList(),
      'mppts': mppts.map((m) => m.toJson()).toList(),
      'edges': edges.map((e) => e.toJson()).toList(),
      'batteryCouplings': batteryCouplings.map((c) => c.toJson()).toList(),
    };
    // Omit when empty so legacy projects round-trip byte-identically.
    if (chargeControllers.isNotEmpty) {
      json['chargeControllers'] = chargeControllers.map((c) => c.toJson()).toList();
    }
    return json;
  }

  static TopologyGraph fromJson(Map<String, dynamic> json) {
    List<T> listOf<T>(String key, T Function(Map<String, dynamic>) decode) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw.map((e) => decode((e as Map).cast<String, dynamic>())).toList(growable: false);
    }
    return TopologyGraph(
      dcBuses: listOf('dcBuses', DcBus.fromJson),
      acBuses: listOf('acBuses', AcBus.fromJson),
      mppts: listOf('mppts', MpptNode.fromJson),
      edges: listOf('edges', BusEdge.fromJson),
      batteryCouplings: listOf('batteryCouplings', BatteryCouplingSpec.fromJson),
      chargeControllers: listOf('chargeControllers', ChargeController.fromJson),
    );
  }
}

String? _firstDuplicate(Iterable<String> ids) {
  final seen = <String>{};
  for (final id in ids) {
    if (!seen.add(id)) return id;
  }
  return null;
}
