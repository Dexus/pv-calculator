import 'package:component_catalog/component_catalog.dart' as cc;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/catalog/catalog_repository.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/widgets/forms/batteries_section.dart';

import '../_test_localization.dart';

void main() {
  testWidgets(
      'picking a catalog battery appends a BatteryDraft with the entry fields',
      (tester) async {
    final repo = CatalogRepository(
      seedSource: cc.InMemoryCatalogSource(const [
        cc.BatteryCatalogEntry(
          id: 'cat-bat-1',
          manufacturer: 'AcmePower',
          model: 'LFP 12 kWh',
          capacityKwh: 12.0,
          maxChargeKw: 6.0,
          maxDischargeKw: 6.0,
          chemistry: 'LFP',
          roundTripEfficiency: 0.94,
          minSocKwh: 0.6,
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
            body: SingleChildScrollView(child: BatteriesSection()),
          ),
        ),
      ),
    );

    final before = controller.draft.batteries.length;

    await tester.tap(find.byKey(const Key('batteries-pick-catalog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-picker-item-cat-bat-1')));
    await tester.pumpAndSettle();

    expect(controller.draft.batteries.length, before + 1);
    final added = controller.draft.batteries.last;
    expect(added.label, 'AcmePower LFP 12 kWh');
    expect(added.capacityKwh, 12.0);
    expect(added.maxChargeKw, 6.0);
    expect(added.maxDischargeKw, 6.0);
    expect(added.roundTripEfficiency, 0.94);
    expect(added.minSocKwh, 0.6);
  });
}
