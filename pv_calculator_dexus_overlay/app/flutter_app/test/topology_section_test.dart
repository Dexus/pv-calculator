import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/widgets/forms/topology_section.dart';
import 'package:pv_engine/pv_engine.dart';

import '_test_localization.dart';

void main() {
  testWidgets('disabled by default; build() does not attach a topology', (tester) async {
    final controller = ProjectController();
    expect(controller.draft.topology.enabled, isFalse);
    expect(controller.draft.build().topology, isNull,
        reason: 'engine should fall back to TopologyGraph.fromLegacy');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: germanMaterialApp(
          home: const Scaffold(
            body: SingleChildScrollView(child: TopologySection()),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('topology-enable')), findsOneWidget);
    // Sub-editors are hidden while the switch is off.
    expect(find.byKey(const Key('topology-add-dc-bus')), findsNothing);
  });

  testWidgets('toggling on seeds from legacy and reveals editors', (tester) async {
    final controller = ProjectController();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: germanMaterialApp(
          home: const Scaffold(
            body: SingleChildScrollView(child: TopologySection()),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    // Flip the master switch on.
    await tester.tap(find.byKey(const Key('topology-enable')));
    await tester.pumpAndSettle();

    expect(controller.draft.topology.enabled, isTrue);
    // Seeded from the demo project: at least one DC bus, one AC bus, one MPPT,
    // and one coupling for the demo battery.
    expect(controller.draft.topology.acBuses, isNotEmpty);
    expect(controller.draft.topology.dcBuses, isNotEmpty);
    expect(controller.draft.topology.mppts, isNotEmpty);
    expect(controller.draft.topology.couplings.first.batteryId,
        controller.draft.batteries.first.id);

    // Sub-editor buttons are now visible.
    expect(find.byKey(const Key('topology-add-dc-bus')), findsOneWidget);
    expect(find.byKey(const Key('topology-add-ac-bus')), findsOneWidget);
    expect(find.byKey(const Key('topology-add-edge')), findsOneWidget);
    expect(find.byKey(const Key('topology-seed-from-legacy')), findsOneWidget);

    // Build now emits the explicit topology instead of null.
    expect(controller.draft.build().topology, isNotNull);
  });

  testWidgets('DC-coupled battery without a DC bus shows a validation issue', (tester) async {
    final controller = ProjectController();
    final topo = controller.draft.topology
      ..enabled = true
      ..seedFromConfig(controller.draft);
    // Force the first battery to DC-coupled, then remove all DC buses so
    // the engine validator triggers a "references unknown dcBus" error.
    topo.couplings.first.acCoupled = false;
    topo.couplings.first.dcBusId = null;
    topo.dcBuses.clear();

    final issue = controller.draft.validationIssue();
    expect(issue, isNotNull);
    expect(issue!.section, ConfigSection.topology,
        reason: 'engine error message should be routed to the topology section');
    expect(issue.message.toLowerCase(), contains('dcbus'));
  });

  testWidgets('coupling.inverterId round-trips through JSON', (tester) async {
    final controller = ProjectController();
    final topo = controller.draft.topology
      ..enabled = true
      ..seedFromConfig(controller.draft);
    final invId = controller.draft.inverters.first.id;
    topo.couplings.first.inverterId = invId;

    final json = controller.draft.build().toJson();
    expect(json['topology'], isNotNull);

    final reloaded = ConfigDraft.fromConfig(SimulationConfig.fromJson(json));
    expect(reloaded.topology.enabled, isTrue);
    expect(reloaded.topology.couplings.first.inverterId, invId);
  });

  testWidgets('switching coupling AC→DC clears the stale inverterId', (tester) async {
    final controller = ProjectController();
    final batteryId = controller.draft.batteries.first.id;
    final invId = controller.draft.inverters.first.id;
    final topo = controller.draft.topology
      ..enabled = true
      ..seedFromConfig(controller.draft);
    topo.couplings.first.inverterId = invId;
    // Provide a DC bus so the segmented switch can land on DC without
    // immediately failing validation.
    topo.dcBuses.add(DcBusDraft(id: 'dc-main'));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: germanMaterialApp(
          home: const Scaffold(
            body: SingleChildScrollView(child: TopologySection()),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    // Pre-condition: AC + inverterId set.
    final coupling = topo.couplings.firstWhere((c) => c.batteryId == batteryId);
    expect(coupling.acCoupled, isTrue);
    expect(coupling.inverterId, invId);

    // Tap the DC segment for this battery. ensureVisible scrolls it
    // into view first; the seeded topology section is long enough to
    // push the coupling row off the bottom of the test viewport.
    final dcButton = find.text('DC').first;
    await tester.ensureVisible(dcButton);
    await tester.pumpAndSettle();
    await tester.tap(dcButton);
    await tester.pumpAndSettle();

    expect(coupling.acCoupled, isFalse);
    expect(coupling.inverterId, isNull,
        reason: 'AC→DC switch must clear the now-hidden inverterId so it '
            "doesn't silently feed the engine's AC cap path");
  });
}
