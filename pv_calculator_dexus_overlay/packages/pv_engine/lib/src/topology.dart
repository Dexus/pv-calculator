// Directed energy graph linking PV arrays, MPPT inputs, inverters,
// buses, batteries and micro-inverter banks. Phase 4's domain model.
//
// The graph is *descriptive*: edges carry efficiency and power limits,
// but the simulator continues to enforce those limits via the component
// fields (`Inverter.efficiency`, `Inverter.maxDcInputKw`,
// `Inverter.effectiveMaxAcKw`, `BatteryConfig.maxChargeKw`, etc.). The
// topology mainly answers two new questions that flat lists cannot:
//   1. Is a battery AC-coupled (charges via the household AC bus, the
//      legacy behaviour) or DC-coupled to a specific inverter's DC bus
//      (planned for future phases)?
//   2. Which AC bus does each inverter / micro-inverter bank feed?
//      Currently a single shared AC bus, but the schema allows multiple
//      in future (e.g. islanding scenarios).
//
// Use `TopologyGraph.fromLegacy(...)` to derive a default graph from
// the existing `arrays + inverters + batteries + banks` lists; the
// adapter keeps every pre-Phase-4 project running without explicit
// topology configuration.

enum BatteryCoupling { ac, dc }

class DcBus {
  const DcBus({required this.id, this.label = ''});
  final String id;
  final String label;

  Map<String, dynamic> toJson() => {'id': id, 'label': label};
  static DcBus fromJson(Map<String, dynamic> json) =>
      DcBus(id: (json['id'] as String).trim(), label: json['label'] as String? ?? '');
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
  });

  final List<DcBus> dcBuses;
  final List<AcBus> acBuses;
  final List<MpptNode> mppts;
  final List<BusEdge> edges;
  final List<BatteryCouplingSpec> batteryCouplings;

  BatteryCouplingSpec couplingFor(String batteryId) {
    for (final spec in batteryCouplings) {
      if (spec.batteryId == batteryId) return spec;
    }
    return BatteryCouplingSpec(batteryId: batteryId);
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

    final dupDc = _firstDuplicate(dcBuses.map((b) => b.id));
    if (dupDc != null) throw ArgumentError('Duplicate topology dcBus id: $dupDc.');
    final dupAc = _firstDuplicate(acBuses.map((b) => b.id));
    if (dupAc != null) throw ArgumentError('Duplicate topology acBus id: $dupAc.');
    final dupMppt = _firstDuplicate(mppts.map((m) => m.id));
    if (dupMppt != null) throw ArgumentError('Duplicate topology mppt id: $dupMppt.');

    for (final m in mppts) {
      if (!inverterIds.contains(m.inverterId)) {
        throw ArgumentError('Topology MPPT ${m.id} references missing inverter ${m.inverterId}.');
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
  }

  Map<String, dynamic> toJson() => {
        'dcBuses': dcBuses.map((b) => b.toJson()).toList(),
        'acBuses': acBuses.map((b) => b.toJson()).toList(),
        'mppts': mppts.map((m) => m.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
        'batteryCouplings': batteryCouplings.map((c) => c.toJson()).toList(),
      };

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
