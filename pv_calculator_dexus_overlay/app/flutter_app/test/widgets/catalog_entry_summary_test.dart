import 'package:component_catalog/component_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/l10n/generated/app_localizations.dart';
import 'package:pv_calculator_app/widgets/catalog/catalog_entry_summary.dart';

Future<AppLocalizations> _de() async => AppLocalizations.delegate.load(
      const Locale('de'),
    );

void main() {
  testWidgets('module summary appends € price when set', (tester) async {
    final l = await _de();
    const mod = ModuleCatalogEntry(
      id: 'm', manufacturer: 'A', model: 'B',
      peakKwPerModule: 0.4, cellTechnology: 'Mono PERC',
      unitPriceEur: 80.0,
    );
    expect(summariseCatalogEntry(mod, l), '400 W · Mono PERC · 80 €/Modul');
  });

  testWidgets('module summary omits price when null', (tester) async {
    final l = await _de();
    const mod = ModuleCatalogEntry(
      id: 'm', manufacturer: 'A', model: 'B', peakKwPerModule: 0.4,
    );
    expect(summariseCatalogEntry(mod, l), '400 W');
  });

  testWidgets('charge-controller summary lists efficiency / kW / MPPT / €',
      (tester) async {
    final l = await _de();
    const cc = ChargeControllerCatalogEntry(
      id: 'c', manufacturer: 'A', model: 'B',
      efficiency: 0.98, maxInputKw: 5.8, mpptCount: 1,
      unitPriceEur: 350.0,
    );
    expect(summariseCatalogEntry(cc, l), '98 % · 5.8 kW DC · 1 MPPT · 350 €/Stück');
  });

  testWidgets('charge-controller summary survives missing optional fields',
      (tester) async {
    final l = await _de();
    const cc = ChargeControllerCatalogEntry(
      id: 'c', manufacturer: 'A', model: 'B',
      efficiency: 0.97,
    );
    expect(summariseCatalogEntry(cc, l), '97 %');
  });
}
