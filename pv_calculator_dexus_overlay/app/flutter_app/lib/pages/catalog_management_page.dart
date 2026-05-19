import 'package:component_catalog/component_catalog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../catalog/catalog_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../persistence/catalog_file_io.dart';
import '../widgets/catalog/catalog_entry_editor.dart';
import '../widgets/catalog/catalog_entry_summary.dart';

class CatalogManagementPage extends StatefulWidget {
  const CatalogManagementPage({super.key, this.fileIo = const CatalogFileIo()});

  /// Injected for tests so they can avoid the real `file_selector` glue.
  final CatalogFileIo fileIo;

  @override
  State<CatalogManagementPage> createState() => _CatalogManagementPageState();
}

class _CatalogManagementPageState extends State<CatalogManagementPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _kinds = <ComponentKind>[
    ComponentKind.module,
    ComponentKind.inverter,
    ComponentKind.battery,
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _kinds.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.catalogManagerTitle),
        actions: [
          IconButton(
            key: const Key('catalog-manager-import'),
            tooltip: l.catalogManagerImportTooltip,
            icon: const Icon(Icons.upload_file),
            onPressed: _onImport,
          ),
          IconButton(
            key: const Key('catalog-manager-export'),
            tooltip: l.catalogManagerExportTooltip,
            icon: const Icon(Icons.download),
            onPressed: _onExport,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l.catalogManagerTabModules),
            Tab(text: l.catalogManagerTabInverters),
            Tab(text: l.catalogManagerTabBatteries),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final kind in _kinds)
            _CatalogKindList(
              key: ValueKey('catalog-manager-list-${kind.name}'),
              kind: kind,
              onAdd: () => _openEditor(kind: kind),
              onEdit: (e) => _openEditor(kind: kind, initial: e),
              onDelete: _confirmDelete,
              onDuplicateSeed: (e) => _openEditor(
                kind: kind,
                initial: _seedAsUserCopy(e, l.catalogManagerDuplicatePrefix),
                prefillOnly: true,
              ),
            ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (ctx, _) {
          final kind = _kinds[_tabs.index];
          final label = switch (kind) {
            ComponentKind.module => l.catalogManagerAddModuleFab,
            ComponentKind.inverter => l.catalogManagerAddInverterFab,
            ComponentKind.battery => l.catalogManagerAddBatteryFab,
            // Charge-controller catalog UI lands in Phase-4b chunk 6;
            // until then `_kinds` doesn't include this kind, so this
            // branch is unreachable at runtime — kept only to satisfy
            // the exhaustiveness check.
            ComponentKind.chargeController => '',
          };
          return FloatingActionButton.extended(
            key: Key('catalog-manager-add-${kind.name}'),
            onPressed: () => _openEditor(kind: kind),
            icon: const Icon(Icons.add),
            label: Text(label),
          );
        },
      ),
    );
  }

  Future<void> _openEditor({
    required ComponentKind kind,
    CatalogEntry? initial,
    bool prefillOnly = false,
  }) async {
    final repo = context.read<CatalogRepository>();
    await Navigator.of(context).push<CatalogEntry>(
      MaterialPageRoute(
        builder: (_) => CatalogEntryEditor(
          repository: repo,
          kind: kind,
          initial: initial,
          prefillOnly: prefillOnly,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(CatalogEntry entry) async {
    final l = AppLocalizations.of(context);
    final repo = context.read<CatalogRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.catalogManagerDeleteConfirmTitle),
        content: Text(l.catalogManagerDeleteConfirmBody(entry.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const Key('catalog-manager-delete-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await repo.deleteUserEntry(entry.id);
  }

  Future<void> _onImport() async {
    final repo = context.read<CatalogRepository>();
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final CatalogImportPreview? preview;
    try {
      preview = await widget.fileIo.previewImport(repo);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(l.catalogManagerImportFailed('$e'))));
      return;
    }
    if (preview == null) return;
    if (!mounted) return;
    final accept = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.catalogManagerImportConfirmTitle),
        content: Text(l.catalogManagerImportConfirmBody(
            preview!.newCount, preview.overwriteCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const Key('catalog-manager-import-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.catalogManagerImportConfirmAccept),
          ),
        ],
      ),
    );
    if (accept != true) return;
    final CatalogImportCounts counts;
    try {
      counts = await repo.importUserEntries(preview.entries);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(l.catalogManagerImportFailed('$e'))));
      return;
    }
    messenger.showSnackBar(SnackBar(
      content: Text(l.catalogManagerImportSuccess(counts.added, counts.updated)),
    ));
  }

  Future<void> _onExport() async {
    final repo = context.read<CatalogRepository>();
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final users = await repo.userEntries();
    if (users.isEmpty) {
      messenger.showSnackBar(
          SnackBar(content: Text(l.catalogManagerExportEmpty)));
      return;
    }
    final String? filename;
    try {
      filename = await widget.fileIo.exportUserCatalog(repo);
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(l.catalogManagerExportFailed('$e'))));
      return;
    }
    if (filename == null) {
      messenger.showSnackBar(
          SnackBar(content: Text(l.catalogManagerExportCancelled)));
      return;
    }
    messenger.showSnackBar(
        SnackBar(content: Text(l.catalogManagerExportSuccess(filename))));
  }

  CatalogEntry _seedAsUserCopy(CatalogEntry seed, String prefix) {
    final newId = addCollisionSuffix(
        slugifyForCatalogId('${seed.manufacturer} ${seed.model}'));
    final manufacturer = '$prefix${seed.manufacturer}';
    return switch (seed) {
      ModuleCatalogEntry m => ModuleCatalogEntry(
          id: newId,
          manufacturer: manufacturer,
          model: m.model,
          peakKwPerModule: m.peakKwPerModule,
          cellTechnology: m.cellTechnology,
          temperatureCoefficientPctPerC: m.temperatureCoefficientPctPerC,
          nominalOperatingCellTempC: m.nominalOperatingCellTempC,
          degradationPctPerYear: m.degradationPctPerYear,
          sourceUrl: m.sourceUrl,
          notes: m.notes,
        ),
      InverterCatalogEntry i => InverterCatalogEntry(
          id: newId,
          manufacturer: manufacturer,
          model: i.model,
          maxAcKw: i.maxAcKw,
          maxDcInputKw: i.maxDcInputKw,
          efficiency: i.efficiency,
          role: i.role,
          sourceUrl: i.sourceUrl,
          notes: i.notes,
        ),
      BatteryCatalogEntry b => BatteryCatalogEntry(
          id: newId,
          manufacturer: manufacturer,
          model: b.model,
          capacityKwh: b.capacityKwh,
          maxChargeKw: b.maxChargeKw,
          maxDischargeKw: b.maxDischargeKw,
          chemistry: b.chemistry,
          roundTripEfficiency: b.roundTripEfficiency,
          minSocKwh: b.minSocKwh,
          sourceUrl: b.sourceUrl,
          notes: b.notes,
        ),
      ChargeControllerCatalogEntry c => ChargeControllerCatalogEntry(
          id: newId,
          manufacturer: manufacturer,
          model: c.model,
          efficiency: c.efficiency,
          maxInputKw: c.maxInputKw,
          maxOutputKw: c.maxOutputKw,
          standbyW: c.standbyW,
          mpptCount: c.mpptCount,
          sourceUrl: c.sourceUrl,
          notes: c.notes,
        ),
    };
  }
}

class _CatalogKindList extends StatelessWidget {
  const _CatalogKindList({
    super.key,
    required this.kind,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicateSeed,
  });

  final ComponentKind kind;
  final VoidCallback onAdd;
  final void Function(CatalogEntry) onEdit;
  final void Function(CatalogEntry) onDelete;
  final void Function(CatalogEntry) onDuplicateSeed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final repo = context.watch<CatalogRepository>();
    return FutureBuilder<List<List<CatalogEntry>>>(
      future: Future.wait([
        repo.userEntries(),
        repo.seedEntries(),
      ]),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${l.catalogLoadError}\n\n${snap.error}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error),
              ),
            ),
          );
        }
        final users = snap.data![0].where((e) => e.kind == kind).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        final seeds = snap.data![1].where((e) => e.kind == kind).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));

        return ListView(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 96),
          children: [
            _sectionHeader(context, l.catalogManagerUserSection),
            if (users.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.catalogManagerEmptyUser,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            for (final entry in users)
              _UserTile(
                entry: entry,
                onEdit: () => onEdit(entry),
                onDelete: () => onDelete(entry),
              ),
            const SizedBox(height: 16),
            _sectionHeader(context, l.catalogManagerSeedSection),
            for (final entry in seeds)
              _SeedTile(
                entry: entry,
                onDuplicate: () => onDuplicateSeed(entry),
              ),
          ],
        );
      },
    );
  }

  Widget _sectionHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final CatalogEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListTile(
      key: Key('catalog-manager-user-${entry.id}'),
      title: Text(entry.displayName),
      subtitle: Text(summariseCatalogEntry(entry, l)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('catalog-manager-user-edit-${entry.id}'),
            tooltip: l.catalogManagerEditTooltip,
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
          IconButton(
            key: Key('catalog-manager-user-delete-${entry.id}'),
            tooltip: l.catalogManagerDeleteTooltip,
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _SeedTile extends StatelessWidget {
  const _SeedTile({required this.entry, required this.onDuplicate});

  final CatalogEntry entry;
  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      key: Key('catalog-manager-seed-${entry.id}'),
      title: Text(entry.displayName,
          style: TextStyle(color: scheme.onSurfaceVariant)),
      subtitle: Text(summariseCatalogEntry(entry, l),
          style: TextStyle(color: scheme.onSurfaceVariant)),
      trailing: IconButton(
        key: Key('catalog-manager-seed-duplicate-${entry.id}'),
        tooltip: l.catalogManagerDuplicateTooltip,
        icon: const Icon(Icons.copy_outlined),
        onPressed: onDuplicate,
      ),
    );
  }
}
