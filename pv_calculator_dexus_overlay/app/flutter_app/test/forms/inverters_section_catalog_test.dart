import 'package:component_catalog/component_catalog.dart' as cc;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/catalog/catalog_repository.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/widgets/forms/inverters_section.dart';
import 'package:pv_engine/pv_engine.dart' as pve;

import '../_test_localization.dart';

void main() {
  testWidgets(
      'picking a catalog inverter appends an InverterDraft with the entry fields',
      (tester) async {
    final repo = CatalogRepository(
      seedSource: cc.InMemoryCatalogSource(const [
        cc.InverterCatalogEntry(
          id: 'cat-inv-1',
          manufacturer: 'AcmeCorp',
          model: 'String 6 kW',
          maxAcKw: 6.0,
          maxDcInputKw: 9.0,
          efficiency: 0.975,
          role: cc.CatalogInverterRole.batteryCoupled,
        ),
      ], writable: false),
      userSource: cc.InMemoryCatalogSource(const []),
    );
    final controller = ProjectController();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProjectController>.value(value: controller),
          ChangeNotifierProvider<CatalogRepository>.value(value: repo),
        ],
        child: germanMaterialApp(
          home: const Scaffold(
            body: SingleChildScrollView(child: InvertersSection()),
          ),
        ),
      ),
    );

    final before = controller.draft.inverters.length;

    await tester.tap(find.byKey(const Key('inverters-pick-catalog')));
    await tester.pumpAndSettle();

    // Picker is open with the seed entry; tap it.
    await tester.tap(find.byKey(const Key('catalog-picker-item-cat-inv-1')));
    await tester.pumpAndSettle();

    expect(controller.draft.inverters.length, before + 1);
    final added = controller.draft.inverters.last;
    expect(added.label, 'AcmeCorp String 6 kW');
    expect(added.maxAcKw, 6.0);
    expect(added.maxDcInputKw, 9.0);
    expect(added.efficiency, 0.975);
    expect(added.role, pve.InverterRole.batteryCoupled);
  });
}
