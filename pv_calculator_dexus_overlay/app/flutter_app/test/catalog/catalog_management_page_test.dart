import 'package:component_catalog/component_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pv_calculator_app/catalog/catalog_repository.dart';
import 'package:pv_calculator_app/pages/catalog_management_page.dart';
import 'package:pv_calculator_app/persistence/catalog_file_io.dart';

import '../_test_localization.dart';

const _seedModule = ModuleCatalogEntry(
    id: 'seed-mod',
    manufacturer: 'Acme Seed',
    model: '400 Mono',
    peakKwPerModule: 0.4);

class _FakeFileIo extends CatalogFileIo {
  _FakeFileIo({this.preview});
  final CatalogImportPreview? preview;
  int previewCalls = 0;
  int exportCalls = 0;

  @override
  Future<CatalogImportPreview?> previewImport(CatalogRepository repo) async {
    previewCalls++;
    return preview;
  }

  @override
  Future<String?> exportUserCatalog(
    CatalogRepository repo, {
    String suggestedName = 'components_user.json',
    Rect? sharePositionOrigin,
  }) async {
    exportCalls++;
    return null;
  }
}

Widget _host(CatalogRepository repo, {CatalogFileIo? fileIo}) {
  return ChangeNotifierProvider<CatalogRepository>.value(
    value: repo,
    child: germanMaterialApp(
      home: CatalogManagementPage(fileIo: fileIo ?? const CatalogFileIo()),
    ),
  );
}

void main() {
  testWidgets('shows seed and user sections; user-empty hint visible',
      (tester) async {
    final repo = CatalogRepository(
      seedSource: InMemoryCatalogSource(const [_seedModule], writable: false),
      userSource: InMemoryCatalogSource(const []),
    );
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();

    expect(find.text('Eigene Einträge'), findsOneWidget);
    expect(find.text('Mitgelieferter Seed (schreibgeschützt)'), findsOneWidget);
    expect(find.text('Noch keine eigenen Einträge.'), findsOneWidget);
    expect(find.byKey(const Key('catalog-manager-seed-seed-mod')),
        findsOneWidget);
    // No edit/delete on seed tiles
    expect(find.byKey(const Key('catalog-manager-user-edit-seed-mod')),
        findsNothing);
  });

  testWidgets('FAB opens editor and a new user module appears in the list',
      (tester) async {
    final repo = CatalogRepository(
      seedSource: InMemoryCatalogSource(const [], writable: false),
      userSource: InMemoryCatalogSource(const []),
    );
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('catalog-manager-add-module')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('catalog-editor-manufacturer')), 'Trina');
    await tester.enterText(
        find.byKey(const Key('catalog-editor-model')), 'TSM 450');
    await tester.enterText(
        find.byKey(const Key('catalog-editor-peak-kw')), '0.45');

    await tester.tap(find.byKey(const Key('catalog-editor-save')));
    await tester.pumpAndSettle();

    final users = await repo.userEntries();
    expect(users, hasLength(1));
    expect(users.single, isA<ModuleCatalogEntry>());
    expect((users.single as ModuleCatalogEntry).peakKwPerModule, 0.45);
    // The auto-slug should have populated the id
    expect(users.single.id, 'trina-tsm-450');

    // Back on the manager — the new user row is now visible.
    expect(find.byKey(const Key('catalog-manager-user-trina-tsm-450')),
        findsOneWidget);
    expect(find.text('Noch keine eigenen Einträge.'), findsNothing);
  });

  testWidgets('delete confirmation flow removes a user entry',
      (tester) async {
    const userMod = ModuleCatalogEntry(
        id: 'u',
        manufacturer: 'Mine',
        model: 'X',
        peakKwPerModule: 0.4);
    final repo = CatalogRepository(
      seedSource: InMemoryCatalogSource(const [], writable: false),
      userSource: InMemoryCatalogSource(const [userMod]),
    );
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const Key('catalog-manager-user-delete-u')));
    await tester.pumpAndSettle();

    expect(find.text('Eintrag löschen?'), findsOneWidget);
    await tester
        .tap(find.byKey(const Key('catalog-manager-delete-confirm')));
    await tester.pumpAndSettle();

    expect(await repo.userEntries(), isEmpty);
  });

  testWidgets('seed duplicate prefills editor with the seed values',
      (tester) async {
    final repo = CatalogRepository(
      seedSource: InMemoryCatalogSource(const [_seedModule], writable: false),
      userSource: InMemoryCatalogSource(const []),
    );
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(
        const Key('catalog-manager-seed-duplicate-seed-mod')));
    await tester.pumpAndSettle();

    // Manufacturer field starts with "Eigene Kopie — Acme Seed"
    final manufacturerField = find.byKey(const Key('catalog-editor-manufacturer'));
    final tf = tester.widget<TextFormField>(manufacturerField);
    expect(tf.controller!.text, startsWith('Eigene Kopie — Acme Seed'));
    // prefill-only mode keeps the id field editable; an edit would lock
    // it and skip the collision dialog (bug from review).
    final idField = tester.widget<TextFormField>(
        find.byKey(const Key('catalog-editor-id')));
    expect(idField.enabled, isTrue,
        reason: 'duplicated seed must stay a create flow, not an edit');

    await tester.tap(find.byKey(const Key('catalog-editor-save')));
    await tester.pumpAndSettle();

    final users = await repo.userEntries();
    expect(users, hasLength(1));
    expect(users.single.manufacturer, startsWith('Eigene Kopie — '));
  });

  testWidgets('duplicate-seed save fires collision dialog when id exists',
      (tester) async {
    final repo = CatalogRepository(
      seedSource: InMemoryCatalogSource(const [_seedModule], writable: false),
      userSource: InMemoryCatalogSource(const []),
    );
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const Key('catalog-manager-seed-duplicate-seed-mod')));
    await tester.pumpAndSettle();

    // Force the auto-generated id to collide with a pre-planted user
    // entry. After this edit the editor's create-path collision check
    // must surface the dialog rather than silently overwriting.
    await tester.enterText(
        find.byKey(const Key('catalog-editor-id')), 'planted');
    await repo.addUserEntry(const ModuleCatalogEntry(
      id: 'planted',
      manufacturer: 'Existing',
      model: 'X',
      peakKwPerModule: 0.4,
    ));

    await tester.tap(find.byKey(const Key('catalog-editor-save')));
    await tester.pumpAndSettle();

    expect(find.text('ID existiert bereits'), findsOneWidget,
        reason: 'collision dialog must appear in prefill-create mode');

    // Cancel: the existing entry stays untouched.
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    final planted = (await repo.userEntries())
        .firstWhere((e) => e.id == 'planted') as ModuleCatalogEntry;
    expect(planted.manufacturer, 'Existing');
  });

  testWidgets('import confirm dialog and snackbar fire on accept',
      (tester) async {
    const newEntry = ModuleCatalogEntry(
        id: 'imp-1', manufacturer: 'I', model: 'X', peakKwPerModule: 0.4);
    final repo = CatalogRepository(
      seedSource: InMemoryCatalogSource(const [], writable: false),
      userSource: InMemoryCatalogSource(const []),
    );
    final fileIo = _FakeFileIo(
      preview: const CatalogImportPreview(
        entries: [newEntry],
        newCount: 1,
        overwriteCount: 0,
      ),
    );
    await tester.pumpWidget(_host(repo, fileIo: fileIo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('catalog-manager-import')));
    await tester.pumpAndSettle();
    expect(find.text('Import bestätigen'), findsOneWidget);

    await tester
        .tap(find.byKey(const Key('catalog-manager-import-confirm')));
    await tester.pumpAndSettle();

    expect(await repo.userEntries(), hasLength(1));
    expect(find.textContaining('Importiert:'), findsOneWidget);
  });

  testWidgets('export-empty short-circuits to a snackbar', (tester) async {
    final repo = CatalogRepository(
      seedSource: InMemoryCatalogSource(const [_seedModule], writable: false),
      userSource: InMemoryCatalogSource(const []),
    );
    final fileIo = _FakeFileIo();
    await tester.pumpWidget(_host(repo, fileIo: fileIo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('catalog-manager-export')));
    await tester.pumpAndSettle();

    expect(find.text('Keine eigenen Einträge zum Exportieren.'),
        findsOneWidget);
    expect(fileIo.exportCalls, 0,
        reason: 'must skip file-io entirely on empty export');
  });

  testWidgets('editor persists optional unit price on a user module',
      (tester) async {
    final repo = CatalogRepository(
      seedSource: InMemoryCatalogSource(const [], writable: false),
      userSource: InMemoryCatalogSource(const []),
    );
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('catalog-manager-add-module')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('catalog-editor-manufacturer')), 'Trina');
    await tester.enterText(
        find.byKey(const Key('catalog-editor-model')), 'TSM 450');
    await tester.enterText(
        find.byKey(const Key('catalog-editor-peak-kw')), '0.45');
    // Unit price sits below the kind-specific fields in a ListView; the
    // ListView lazy-builds children, so drag the form-list to bring it
    // into view. `drag` works even when the target widget hasn't been
    // built yet (unlike `scrollUntilVisible`, which needs a single
    // unambiguous target Scrollable).
    await tester.drag(
        find.byKey(const Key('catalog-editor-peak-kw')),
        const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('catalog-editor-unit-price')), '120');

    await tester.tap(find.byKey(const Key('catalog-editor-save')));
    await tester.pumpAndSettle();

    final users = await repo.userEntries();
    expect(users, hasLength(1));
    expect((users.single as ModuleCatalogEntry).unitPriceEur, 120.0);
  });

  testWidgets('empty unit price round-trips as null', (tester) async {
    final repo = CatalogRepository(
      seedSource: InMemoryCatalogSource(const [], writable: false),
      userSource: InMemoryCatalogSource(const []),
    );
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('catalog-manager-add-module')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('catalog-editor-manufacturer')), 'Trina');
    await tester.enterText(
        find.byKey(const Key('catalog-editor-model')), 'TSM 450');
    await tester.enterText(
        find.byKey(const Key('catalog-editor-peak-kw')), '0.45');
    // Unit price field left empty.

    await tester.tap(find.byKey(const Key('catalog-editor-save')));
    await tester.pumpAndSettle();

    final users = await repo.userEntries();
    expect(users, hasLength(1));
    expect((users.single as ModuleCatalogEntry).unitPriceEur, isNull);
  });

  testWidgets('charge-controller FAB opens editor and saves new entry',
      (tester) async {
    final repo = CatalogRepository(
      seedSource: InMemoryCatalogSource(const [], writable: false),
      userSource: InMemoryCatalogSource(const []),
    );
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();

    // Switch to the charge-controller tab.
    await tester.tap(find.text('Laderegler'));
    await tester.pumpAndSettle();

    await tester.tap(
        find.byKey(const Key('catalog-manager-add-chargeController')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('catalog-editor-manufacturer')), 'Victron');
    await tester.enterText(
        find.byKey(const Key('catalog-editor-model')), 'SmartSolar 150/100');
    await tester.enterText(
        find.byKey(const Key('catalog-editor-cc-efficiency')), '0.98');
    await tester.enterText(
        find.byKey(const Key('catalog-editor-cc-max-input-kw')), '5.8');
    // Lower fields sit in a lazy ListView; drag the form up so they
    // get built before we try to type into them. `warnIfMissed: false`
    // because the drag's anchor field may scroll out of view mid-drag.
    await tester.drag(
        find.byKey(const Key('catalog-editor-cc-efficiency')),
        const Offset(0, -500),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('catalog-editor-cc-mppt-count')), '1');
    await tester.enterText(
        find.byKey(const Key('catalog-editor-unit-price')), '350');

    await tester.tap(find.byKey(const Key('catalog-editor-save')));
    await tester.pumpAndSettle();

    final users = await repo.userEntries();
    expect(users, hasLength(1));
    final saved = users.single as ChargeControllerCatalogEntry;
    expect(saved.efficiency, closeTo(0.98, 1e-9));
    expect(saved.maxInputKw, closeTo(5.8, 1e-9));
    expect(saved.mpptCount, 1);
    expect(saved.unitPriceEur, 350.0);
  });

  testWidgets('MPPT count rejects decimals with an inline validator error',
      (tester) async {
    final repo = CatalogRepository(
      seedSource: InMemoryCatalogSource(const [], writable: false),
      userSource: InMemoryCatalogSource(const []),
    );
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Laderegler'));
    await tester.pumpAndSettle();
    await tester.tap(
        find.byKey(const Key('catalog-manager-add-chargeController')));
    await tester.pumpAndSettle();

    // Type the bare minimum to make the form "save-able" except for
    // the bad MPPT value, then try to save. The validator must reject
    // `1.5` with the inline "ganze Zahl" message rather than silently
    // coercing the input into `15` (data corruption) or letting it
    // through to a save-time `int.parse` FormatException.
    //
    // Each `enterText` auto-scrolls the form down to its target, so we
    // mirror the prior passing test's order — efficiency / max-input
    // first, then a final drag to reveal the lower fields, then MPPT.
    await tester.enterText(
        find.byKey(const Key('catalog-editor-manufacturer')), 'Acme');
    await tester.enterText(
        find.byKey(const Key('catalog-editor-model')), 'Test');
    await tester.enterText(
        find.byKey(const Key('catalog-editor-cc-efficiency')), '0.98');
    await tester.enterText(
        find.byKey(const Key('catalog-editor-cc-max-input-kw')), '5.8');
    await tester.drag(
        find.byKey(const Key('catalog-editor-cc-efficiency')),
        const Offset(0, -500),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('catalog-editor-cc-mppt-count')), '1.5');
    await tester.tap(find.byKey(const Key('catalog-editor-save')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(
        find.byKey(const Key('catalog-editor-cc-mppt-count')));
    expect(field.controller!.text, '1.5',
        reason: 'input must not be silently coerced to "15"');
    expect(find.text('Bitte eine ganze Zahl eingeben'), findsOneWidget,
        reason: 'validator must surface a "whole number" error inline');
    // Save must have been blocked: no entry persisted.
    expect(await repo.userEntries(), isEmpty);
  });

  testWidgets('unit price rejects negative input with an inline error',
      (tester) async {
    final repo = CatalogRepository(
      seedSource: InMemoryCatalogSource(const [], writable: false),
      userSource: InMemoryCatalogSource(const []),
    );
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('catalog-manager-add-module')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('catalog-editor-manufacturer')), 'Acme');
    await tester.enterText(
        find.byKey(const Key('catalog-editor-model')), 'Test');
    await tester.enterText(
        find.byKey(const Key('catalog-editor-peak-kw')), '0.4');
    // Drag the form up so the unit-price field is built and reachable.
    await tester.drag(
        find.byKey(const Key('catalog-editor-peak-kw')),
        const Offset(0, -400),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('catalog-editor-unit-price')), '-350');
    await tester.tap(find.byKey(const Key('catalog-editor-save')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(
        find.byKey(const Key('catalog-editor-unit-price')));
    expect(field.controller!.text, '-350',
        reason: 'input must not be silently flipped positive');
    expect(find.text('Mindestens 0'), findsOneWidget,
        reason: 'validator must surface a "min 0" error inline');
    expect(await repo.userEntries(), isEmpty);
  });

  testWidgets('seed-duplicate for charge controller carries fields + price',
      (tester) async {
    const seed = ChargeControllerCatalogEntry(
      id: 'seed-cc',
      manufacturer: 'Acme',
      model: 'MPPT 100/50',
      efficiency: 0.97,
      maxInputKw: 2.9,
      mpptCount: 1,
      unitPriceEur: 180.0,
    );
    final repo = CatalogRepository(
      seedSource: InMemoryCatalogSource(const [seed], writable: false),
      userSource: InMemoryCatalogSource(const []),
    );
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Laderegler'));
    await tester.pumpAndSettle();

    await tester.tap(
        find.byKey(const Key('catalog-manager-seed-duplicate-seed-cc')));
    await tester.pumpAndSettle();

    // Just press save — the editor already holds the seed's prefilled
    // numeric values, and an auto-prefixed "Eigene Kopie — Acme" makes
    // the id unique vs. seed-cc.
    await tester.tap(find.byKey(const Key('catalog-editor-save')));
    await tester.pumpAndSettle();

    final users = await repo.userEntries();
    expect(users, hasLength(1));
    final saved = users.single as ChargeControllerCatalogEntry;
    expect(saved.efficiency, closeTo(0.97, 1e-9));
    expect(saved.maxInputKw, closeTo(2.9, 1e-9));
    expect(saved.mpptCount, 1);
    expect(saved.unitPriceEur, 180.0,
        reason: 'duplicate-seed must carry the price into the user copy');
  });
}
