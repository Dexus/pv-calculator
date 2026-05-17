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
  });
}
