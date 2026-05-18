import 'package:component_catalog/component_catalog.dart' as cc;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/catalog/catalog_repository.dart';
import 'package:pv_calculator_app/pages/arrays_tab.dart';
import 'package:pv_calculator_app/state/project_controller.dart';

import '../_test_localization.dart';

void main() {
  testWidgets(
      'picking a catalog module and entering a count appends a PvArrayDraft '
      'with peakKw = peakKwPerModule × count',
      (tester) async {
    final repo = CatalogRepository(
      seedSource: cc.InMemoryCatalogSource(const [
        cc.ModuleCatalogEntry(
          id: 'cat-mod-1',
          manufacturer: 'AcmeSolar',
          model: 'X 450',
          peakKwPerModule: 0.45,
          cellTechnology: 'TOPCon',
          temperatureCoefficientPctPerC: -0.30,
          nominalOperatingCellTempC: 44.0,
          degradationPctPerYear: 0.4,
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
        child: germanMaterialApp(home: const ArraysTab()),
      ),
    );

    final before = controller.draft.arrays.length;

    await tester.tap(find.byKey(const Key('arrays-pick-catalog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-picker-item-cat-mod-1')));
    await tester.pumpAndSettle();

    // Module-count dialog is open. Default value is '1' — replace it
    // with '8' to test the multiplication path.
    expect(find.byType(AlertDialog), findsOneWidget);
    final tf = find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(tf, '8');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(controller.draft.arrays.length, before + 1);
    final added = controller.draft.arrays.last;
    expect(added.label, 'AcmeSolar X 450 × 8');
    // 0.45 kWp × 8 = 3.6 kWp.
    expect(added.peakKw, closeTo(3.6, 1e-9));
    expect(added.temperatureCoefficientPctPerC, -0.30);
    expect(added.nominalOperatingCellTempC, 44.0);
    expect(added.degradationPctPerYear, 0.4);
  });
}
