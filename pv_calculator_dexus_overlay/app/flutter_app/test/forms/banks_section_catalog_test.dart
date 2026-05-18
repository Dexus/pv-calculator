import 'package:component_catalog/component_catalog.dart' as cc;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/catalog/catalog_repository.dart';
import 'package:pv_calculator_app/state/project_controller.dart';
import 'package:pv_calculator_app/widgets/forms/micro_inverter_banks_section.dart';

import '../_test_localization.dart';

void main() {
  testWidgets(
      'banks picker filters to microInverter800W and maps maxAcKw → unitRatedPowerW',
      (tester) async {
    final repo = CatalogRepository(
      seedSource: cc.InMemoryCatalogSource(const [
        cc.InverterCatalogEntry(
          id: 'grid-1',
          manufacturer: 'AcmeCorp',
          model: 'String 5 kW',
          maxAcKw: 5.0,
          role: cc.CatalogInverterRole.grid,
        ),
        cc.InverterCatalogEntry(
          id: 'micro-1',
          manufacturer: 'AcmeCorp',
          model: 'Micro 0.8 kW',
          maxAcKw: 0.8,
          efficiency: 0.95,
          role: cc.CatalogInverterRole.microInverter800W,
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
            body: SingleChildScrollView(child: MicroInverterBanksSection()),
          ),
        ),
      ),
    );

    // Open the ExpansionTile so the catalog button is reachable.
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    final before = controller.draft.microInverterBanks.length;

    await tester.tap(find.byKey(const Key('banks-pick-catalog')));
    await tester.pumpAndSettle();

    // Filter restricts to micro role: the grid entry must not appear.
    expect(find.byKey(const Key('catalog-picker-item-grid-1')), findsNothing);
    expect(find.byKey(const Key('catalog-picker-item-micro-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('catalog-picker-item-micro-1')));
    await tester.pumpAndSettle();

    expect(controller.draft.microInverterBanks.length, before + 1);
    final added = controller.draft.microInverterBanks.last;
    expect(added.label, 'AcmeCorp Micro 0.8 kW');
    // Catalog maxAcKw=0.8 → 800 W per unit.
    expect(added.unitRatedPowerW, 800.0);
    expect(added.inverterEfficiency, 0.95);
  });
}
