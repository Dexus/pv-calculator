import 'package:component_catalog/component_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/catalog/catalog_repository.dart';
import 'package:pv_calculator_app/l10n/generated/app_localizations.dart';
import 'package:pv_calculator_app/widgets/catalog/catalog_picker_sheet.dart';

void main() {
  Widget host(CatalogRepository repo, void Function(BuildContext) onTap) {
    return ChangeNotifierProvider<CatalogRepository>.value(
      value: repo,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => onTap(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders the seed entries and filters by search', (tester) async {
    final repo = CatalogRepository(
      seedSource: InMemoryCatalogSource(const [
        InverterCatalogEntry(
            id: 'i-1', manufacturer: 'AlphaCorp', model: '5 kW', maxAcKw: 5),
        InverterCatalogEntry(
            id: 'i-2', manufacturer: 'BetaCorp', model: '10 kW', maxAcKw: 10),
      ], writable: false),
      userSource: InMemoryCatalogSource(const []),
    );

    InverterCatalogEntry? picked;
    await tester.pumpWidget(host(repo, (ctx) async {
      picked = await showCatalogPicker<InverterCatalogEntry>(
        ctx,
        repository: repo,
        kind: ComponentKind.inverter,
      );
    }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('catalog-picker-item-i-1')), findsOneWidget);
    expect(find.byKey(const Key('catalog-picker-item-i-2')), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('catalog-picker-search')), 'beta');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog-picker-item-i-1')), findsNothing);
    expect(find.byKey(const Key('catalog-picker-item-i-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('catalog-picker-item-i-2')));
    await tester.pumpAndSettle();
    expect(picked?.id, 'i-2');
  });

  testWidgets('filter callback narrows the visible kind', (tester) async {
    final repo = CatalogRepository(
      seedSource: InMemoryCatalogSource(const [
        InverterCatalogEntry(
            id: 'grid-1',
            manufacturer: 'A',
            model: 'big',
            maxAcKw: 10,
            role: CatalogInverterRole.grid),
        InverterCatalogEntry(
            id: 'micro-1',
            manufacturer: 'A',
            model: 'mini',
            maxAcKw: 0.8,
            role: CatalogInverterRole.microInverter800W),
      ], writable: false),
      userSource: InMemoryCatalogSource(const []),
    );

    await tester.pumpWidget(host(repo, (ctx) async {
      await showCatalogPicker<InverterCatalogEntry>(
        ctx,
        repository: repo,
        kind: ComponentKind.inverter,
        filter: (e) => e.role == CatalogInverterRole.microInverter800W,
      );
    }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('catalog-picker-item-grid-1')), findsNothing);
    expect(find.byKey(const Key('catalog-picker-item-micro-1')), findsOneWidget);
  });
}
