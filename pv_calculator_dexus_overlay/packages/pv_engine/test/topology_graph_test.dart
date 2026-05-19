import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

void main() {
  group('TopologyGraph.fromLegacy', () {
    test('builds one MPPT and one DC bus per inverter, plus a shared AC bus', () {
      final topo = TopologyGraph.fromLegacy(
        arrayIds: const ['a1'],
        inverterIds: const ['inv1'],
        batteryIds: const ['b1'],
        bankIds: const [],
        arrayToInverter: const [MapEntry('a1', 'inv1')],
      );
      expect(topo.acBuses.single.id, 'ac-main');
      expect(topo.mppts.single.id, 'mppt-inv1');
      expect(topo.mppts.single.inverterId, 'inv1');
      expect(topo.dcBuses.single.id, 'dc-inv1');
      // edges: array→mppt, mppt→inv, inv→acMain
      expect(topo.edges.any((e) => e.fromId == 'a1' && e.toId == 'mppt-inv1'), isTrue);
      expect(topo.edges.any((e) => e.fromId == 'mppt-inv1' && e.toId == 'inv1'), isTrue);
      expect(topo.edges.any((e) => e.fromId == 'inv1' && e.toId == 'ac-main'), isTrue);
      expect(topo.batteryCouplings.single.batteryId, 'b1');
      expect(topo.batteryCouplings.single.coupling, BatteryCoupling.ac);
    });

    test('carries inverter caps onto MPPT and AC edges', () {
      final topo = TopologyGraph.fromLegacy(
        arrayIds: const [],
        inverterIds: const ['inv1'],
        batteryIds: const [],
        bankIds: const [],
        inverterMaxAc: const [MapEntry('inv1', 5.0)],
        inverterMaxDcInput: const [MapEntry('inv1', 6.0)],
        inverterEfficiency: const [MapEntry('inv1', 0.96)],
      );
      final mpptEdge = topo.edges.firstWhere((e) => e.fromId == 'mppt-inv1');
      expect(mpptEdge.efficiency, closeTo(0.96, 1e-9));
      expect(mpptEdge.maxPowerKw, closeTo(6.0, 1e-9));
      final acEdge = topo.edges.firstWhere((e) => e.toId == 'ac-main');
      expect(acEdge.maxPowerKw, closeTo(5.0, 1e-9));
    });

    test('emits one edge per bank to the AC bus', () {
      final topo = TopologyGraph.fromLegacy(
        arrayIds: const [],
        inverterIds: const [],
        batteryIds: const ['b1'],
        bankIds: const ['bank1', 'bank2'],
      );
      expect(topo.edges.where((e) => e.fromId == 'bank1' && e.toId == 'ac-main').length, 1);
      expect(topo.edges.where((e) => e.fromId == 'bank2' && e.toId == 'ac-main').length, 1);
    });
  });

  group('TopologyGraph.validate', () {
    test('rejects duplicate dc bus ids', () {
      const topo = TopologyGraph(
        dcBuses: [DcBus(id: 'dup'), DcBus(id: 'dup')],
      );
      expect(
        () => topo.validate(arrayIds: {}, inverterIds: {}, batteryIds: {}, bankIds: {}),
        throwsArgumentError,
      );
    });

    test('rejects edges pointing at unknown nodes', () {
      const topo = TopologyGraph(
        edges: [BusEdge(fromId: 'phantom', toId: 'ac-main')],
        acBuses: [AcBus(id: 'ac-main')],
      );
      expect(
        () => topo.validate(arrayIds: {}, inverterIds: {}, batteryIds: {}, bankIds: {}),
        throwsArgumentError,
      );
    });

    test('rejects MPPT referencing unknown inverter', () {
      const topo = TopologyGraph(
        mppts: [MpptNode(id: 'mppt-x', inverterId: 'missing')],
      );
      expect(
        () => topo.validate(arrayIds: {}, inverterIds: {}, batteryIds: {}, bankIds: {}),
        throwsArgumentError,
      );
    });

    test('rejects DC-coupled battery without dcBusId', () {
      const topo = TopologyGraph(
        batteryCouplings: [BatteryCouplingSpec(batteryId: 'b1', coupling: BatteryCoupling.dc)],
      );
      expect(
        () => topo.validate(arrayIds: {}, inverterIds: {}, batteryIds: {'b1'}, bankIds: {}),
        throwsArgumentError,
      );
    });

    test('rejects coupling.inverterId pointing at unknown inverter', () {
      const topo = TopologyGraph(
        batteryCouplings: [BatteryCouplingSpec(batteryId: 'b1', inverterId: 'ghost')],
      );
      expect(
        () => topo.validate(arrayIds: {}, inverterIds: {'real'}, batteryIds: {'b1'}, bankIds: {}),
        throwsArgumentError,
      );
    });
  });

  group('TopologyGraph JSON', () {
    test('round-trips through toJson/fromJson', () {
      final original = TopologyGraph.fromLegacy(
        arrayIds: const ['a1'],
        inverterIds: const ['inv1'],
        batteryIds: const ['b1'],
        bankIds: const ['bank-1'],
        arrayToInverter: const [MapEntry('a1', 'inv1')],
        inverterMaxAc: const [MapEntry('inv1', 5.0)],
        inverterEfficiency: const [MapEntry('inv1', 0.96)],
      );
      final round = TopologyGraph.fromJson(original.toJson());
      expect(round.dcBuses.length, original.dcBuses.length);
      expect(round.acBuses.length, original.acBuses.length);
      expect(round.mppts.length, original.mppts.length);
      expect(round.edges.length, original.edges.length);
      expect(round.batteryCouplings.length, original.batteryCouplings.length);
    });

    test('BatteryCouplingSpec.inverterId survives JSON round-trip', () {
      const spec = BatteryCouplingSpec(batteryId: 'b1', inverterId: 'bat-inv');
      final round = BatteryCouplingSpec.fromJson(spec.toJson().cast<String, dynamic>());
      expect(round.inverterId, 'bat-inv');
      // The opposite direction: missing inverterId stays null and is
      // not serialised, keeping legacy JSON shapes intact.
      const legacy = BatteryCouplingSpec(batteryId: 'b2');
      expect(legacy.toJson().containsKey('inverterId'), isFalse);
      final legacyRound = BatteryCouplingSpec.fromJson(legacy.toJson().cast<String, dynamic>());
      expect(legacyRound.inverterId, isNull);
    });

    test('DcBus.mode is omitted from JSON when hybrid (legacy round-trip stays byte-identical)', () {
      const hybrid = DcBus(id: 'dc-1');
      expect(hybrid.toJson().containsKey('mode'), isFalse);
      const fed = DcBus(id: 'dc-2', mode: BusMode.batteryFed);
      expect(fed.toJson()['mode'], 'batteryFed');
      final round = DcBus.fromJson(fed.toJson().cast<String, dynamic>());
      expect(round.mode, BusMode.batteryFed);
      // Missing key defaults to hybrid.
      final legacyJson = {'id': 'dc-3', 'label': ''};
      expect(DcBus.fromJson(legacyJson).mode, BusMode.hybrid);
    });

    test('ChargeController round-trips through JSON and validates fields', () {
      const cc = ChargeController(
        id: 'cc-1',
        dcBusId: 'dc-1',
        efficiency: 0.96,
        maxInputKw: 4.5,
        label: 'MPPT 100/50',
      );
      final round = ChargeController.fromJson(cc.toJson().cast<String, dynamic>());
      expect(round.id, 'cc-1');
      expect(round.dcBusId, 'dc-1');
      expect(round.efficiency, closeTo(0.96, 1e-9));
      expect(round.maxInputKw, closeTo(4.5, 1e-9));
      expect(round.label, 'MPPT 100/50');
      // Field-level validation.
      expect(
        () => const ChargeController(id: '', dcBusId: 'dc-1').validate(),
        throwsArgumentError,
      );
      expect(
        () => const ChargeController(id: 'cc', dcBusId: 'dc-1', efficiency: 0).validate(),
        throwsArgumentError,
      );
      expect(
        () => const ChargeController(id: 'cc', dcBusId: 'dc-1', efficiency: 1.5).validate(),
        throwsArgumentError,
      );
      expect(
        () => const ChargeController(id: 'cc', dcBusId: 'dc-1', maxInputKw: 0).validate(),
        throwsArgumentError,
      );
    });

    test('TopologyGraph chargeControllers round-trip and dcBus reference is validated', () {
      const topo = TopologyGraph(
        dcBuses: [DcBus(id: 'dc-1')],
        chargeControllers: [ChargeController(id: 'cc-1', dcBusId: 'dc-1', efficiency: 0.97)],
      );
      final round = TopologyGraph.fromJson(topo.toJson());
      expect(round.chargeControllers.single.id, 'cc-1');
      expect(round.chargeControllers.single.dcBusId, 'dc-1');
      expect(round.controllersForBus('dc-1').single.id, 'cc-1');
      expect(round.dcBusById('dc-1'), isNotNull);
      // Reference to an unknown bus is rejected.
      const broken = TopologyGraph(
        dcBuses: [DcBus(id: 'dc-1')],
        chargeControllers: [ChargeController(id: 'cc-1', dcBusId: 'phantom')],
      );
      expect(
        () => broken.validate(arrayIds: {}, inverterIds: {}, batteryIds: {}, bankIds: {}),
        throwsArgumentError,
      );
      // Duplicate cc ids are rejected.
      const dup = TopologyGraph(
        dcBuses: [DcBus(id: 'dc-1')],
        chargeControllers: [
          ChargeController(id: 'cc-1', dcBusId: 'dc-1'),
          ChargeController(id: 'cc-1', dcBusId: 'dc-1'),
        ],
      );
      expect(
        () => dup.validate(arrayIds: {}, inverterIds: {}, batteryIds: {}, bankIds: {}),
        throwsArgumentError,
      );
    });

    test('TopologyGraph without chargeControllers stays byte-identical in JSON', () {
      const topo = TopologyGraph(dcBuses: [DcBus(id: 'dc-1')]);
      expect(topo.toJson().containsKey('chargeControllers'), isFalse);
    });
  });

  group('Phase 4b cross-references', () {
    test('rule 2: DC-coupled battery without a chargeController on its bus is rejected', () {
      const topo = TopologyGraph(
        dcBuses: [DcBus(id: 'dc-1')],
        batteryCouplings: [
          BatteryCouplingSpec(
            batteryId: 'b1', coupling: BatteryCoupling.dc, dcBusId: 'dc-1'),
        ],
      );
      expect(
        () => topo.validate(
            arrayIds: {}, inverterIds: {}, batteryIds: {'b1'}, bankIds: {}),
        throwsArgumentError,
      );
      // Adding any cc to the bus satisfies the rule.
      const ok = TopologyGraph(
        dcBuses: [DcBus(id: 'dc-1')],
        chargeControllers: [ChargeController(id: 'cc-1', dcBusId: 'dc-1')],
        batteryCouplings: [
          BatteryCouplingSpec(
            batteryId: 'b1', coupling: BatteryCoupling.dc, dcBusId: 'dc-1'),
        ],
      );
      ok.validate(
          arrayIds: {}, inverterIds: {}, batteryIds: {'b1'}, bankIds: {});
    });

    test('rule 5: an array cannot be wired to a chargeController and an MPPT at once', () {
      const topo = TopologyGraph(
        dcBuses: [DcBus(id: 'dc-1')],
        mppts: [MpptNode(id: 'mppt-inv', inverterId: 'inv')],
        chargeControllers: [ChargeController(id: 'cc-1', dcBusId: 'dc-1')],
        edges: [
          BusEdge(fromId: 'a1', toId: 'cc-1'),
          BusEdge(fromId: 'a1', toId: 'mppt-inv'),
        ],
      );
      expect(
        () => topo.validate(
            arrayIds: {'a1'},
            inverterIds: {'inv'},
            batteryIds: {},
            bankIds: {}),
        throwsArgumentError,
      );
    });

    test('rule 3: batteryFed bus needs exactly one DC battery', () {
      // Zero batteries: rejected.
      const zero = TopologyGraph(
        dcBuses: [DcBus(id: 'dc-1', mode: BusMode.batteryFed)],
        chargeControllers: [ChargeController(id: 'cc-1', dcBusId: 'dc-1')],
      );
      expect(
        () => zero.validate(
            arrayIds: {}, inverterIds: {}, batteryIds: {}, bankIds: {}),
        throwsArgumentError,
      );
      // Two batteries: rejected.
      const two = TopologyGraph(
        dcBuses: [DcBus(id: 'dc-1', mode: BusMode.batteryFed)],
        chargeControllers: [ChargeController(id: 'cc-1', dcBusId: 'dc-1')],
        batteryCouplings: [
          BatteryCouplingSpec(
            batteryId: 'b1', coupling: BatteryCoupling.dc, dcBusId: 'dc-1'),
          BatteryCouplingSpec(
            batteryId: 'b2', coupling: BatteryCoupling.dc, dcBusId: 'dc-1'),
        ],
      );
      expect(
        () => two.validate(
            arrayIds: {},
            inverterIds: {},
            batteryIds: {'b1', 'b2'},
            bankIds: {}),
        throwsArgumentError,
      );
    });

    test('rule 3: batteryFed bus needs exactly one outgoing inverter edge', () {
      // The bus has 1 battery but no edge to an inverter — rejected.
      const noInverter = TopologyGraph(
        dcBuses: [DcBus(id: 'dc-1', mode: BusMode.batteryFed)],
        chargeControllers: [ChargeController(id: 'cc-1', dcBusId: 'dc-1')],
        batteryCouplings: [
          BatteryCouplingSpec(
            batteryId: 'b1', coupling: BatteryCoupling.dc, dcBusId: 'dc-1'),
        ],
      );
      expect(
        () => noInverter.validate(
            arrayIds: {},
            inverterIds: {'inv'},
            batteryIds: {'b1'},
            bankIds: {}),
        throwsArgumentError,
      );
    });

    test('rule 4: batteryFed bus rejects PV on the inverter\'s MPPT path', () {
      // batteryFed bus + a hybrid inverter that ALSO has an array on
      // its MPPT — that PV would bypass the battery and break the
      // "PV reaches AC only via the battery" semantics.
      const topo = TopologyGraph(
        dcBuses: [DcBus(id: 'dc-1', mode: BusMode.batteryFed)],
        mppts: [MpptNode(id: 'mppt-inv', inverterId: 'inv')],
        chargeControllers: [ChargeController(id: 'cc-1', dcBusId: 'dc-1')],
        edges: [
          BusEdge(fromId: 'a1', toId: 'mppt-inv'),
          BusEdge(fromId: 'dc-1', toId: 'inv'),
        ],
        batteryCouplings: [
          BatteryCouplingSpec(
            batteryId: 'b1', coupling: BatteryCoupling.dc, dcBusId: 'dc-1'),
        ],
      );
      expect(
        () => topo.validate(
            arrayIds: {'a1'},
            inverterIds: {'inv'},
            batteryIds: {'b1'},
            bankIds: {}),
        throwsArgumentError,
      );
    });

    test('valid full-stack DC batteryFed topology passes validation', () {
      const topo = TopologyGraph(
        dcBuses: [DcBus(id: 'dc-1', mode: BusMode.batteryFed)],
        chargeControllers: [ChargeController(id: 'cc-1', dcBusId: 'dc-1')],
        edges: [
          BusEdge(fromId: 'a1', toId: 'cc-1'),
          BusEdge(fromId: 'dc-1', toId: 'inv'),
        ],
        batteryCouplings: [
          BatteryCouplingSpec(
            batteryId: 'b1', coupling: BatteryCoupling.dc, dcBusId: 'dc-1'),
        ],
      );
      topo.validate(
          arrayIds: {'a1'},
          inverterIds: {'inv'},
          batteryIds: {'b1'},
          bankIds: {});
    });
  });
}
