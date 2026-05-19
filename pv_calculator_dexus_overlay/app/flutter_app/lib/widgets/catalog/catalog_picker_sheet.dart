import 'package:component_catalog/component_catalog.dart';
import 'package:flutter/material.dart';

import '../../catalog/catalog_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import 'catalog_entry_summary.dart';

/// Modal bottom-sheet picker for catalog entries of kind [T].
///
/// Returns the chosen entry, or `null` when the user dismisses the
/// sheet. The [titleOverride] lets callers tighten the title (e.g.
/// "Wechselrichter wählen" vs. the generic kind label) without adding
/// per-kind ARB keys at every call site.
Future<T?> showCatalogPicker<T extends CatalogEntry>(
  BuildContext context, {
  required CatalogRepository repository,
  required ComponentKind kind,
  bool Function(T entry)? filter,
  String? titleOverride,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _PickerSheet<T>(
      repository: repository,
      kind: kind,
      filter: filter,
      titleOverride: titleOverride,
    ),
  );
}

class _PickerSheet<T extends CatalogEntry> extends StatefulWidget {
  const _PickerSheet({
    required this.repository,
    required this.kind,
    this.filter,
    this.titleOverride,
  });

  final CatalogRepository repository;
  final ComponentKind kind;
  final bool Function(T entry)? filter;
  final String? titleOverride;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T extends CatalogEntry>
    extends State<_PickerSheet<T>> {
  final TextEditingController _searchCtrl = TextEditingController();
  Future<List<T>>? _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<T>> _load() async {
    final List<CatalogEntry> all;
    switch (widget.kind) {
      case ComponentKind.module:
        all = await widget.repository.modules();
      case ComponentKind.inverter:
        all = await widget.repository.inverters();
      case ComponentKind.battery:
        all = await widget.repository.batteries();
      case ComponentKind.chargeController:
        all = await widget.repository.chargeControllers();
    }
    var typed = all.whereType<T>().toList();
    final f = widget.filter;
    if (f != null) typed = typed.where(f).toList();
    return typed;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final query = _searchCtrl.text.trim().toLowerCase();
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.titleOverride ?? l.catalogPickerTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('catalog-picker-search'),
                controller: _searchCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  labelText: l.catalogSearchHint,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<T>>(
                  future: _entriesFuture,
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
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      );
                    }
                    final all = snap.data ?? const [];
                    final filtered = query.isEmpty
                        ? all
                        : all
                            .where((e) => e.displayName
                                .toLowerCase()
                                .contains(query))
                            .toList();
                    if (filtered.isEmpty) {
                      return Center(child: Text(l.catalogEmptyState));
                    }
                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final e = filtered[i];
                        return ListTile(
                          key: Key('catalog-picker-item-${e.id}'),
                          title: Text(e.displayName),
                          subtitle: Text(summariseCatalogEntry(e, l)),
                          onTap: () => Navigator.of(ctx).pop(e),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
