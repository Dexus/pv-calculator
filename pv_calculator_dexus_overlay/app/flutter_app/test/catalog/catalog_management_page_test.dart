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
}
