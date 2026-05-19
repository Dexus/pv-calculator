import 'package:component_catalog/component_catalog.dart' as cc;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../catalog/catalog_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../state/config_draft.dart';
import '../../state/project_controller.dart';
import '../catalog/catalog_picker_sheet.dart';
import '_field.dart';

/// Phase-4b form section: edit the list of MPPT charge controllers
/// (Laderegler) that feed DC-coupled batteries. Mirrors
/// `inverters_section.dart` for consistency — load from the catalog
/// (`ChargeControllerCatalogEntry`) or add a blank entry.
class ChargeControllersSection extends StatelessWidget {
  const ChargeControllersSection({super.key});

  String _defaultDcBusId(ConfigDraft draft) {
    if (draft.topology.enabled && draft.topology.dcBuses.isNotEmpty) {
      return draft.topology.dcBuses.first.id;
    }
    if (draft.inverters.isNotEmpty) {
      // Legacy convention: TopologyGraph.fromLegacy emits one DC bus
      // per inverter, named `dc-<inverterId>`. Pre-populate the first
      // one so the user has a working default.
      return 'dc-${draft.inverters.first.id}';
    }
    return 'dc-main';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final draft = controller.draft;
    final l = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(l.chargeControllersTitle,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            TextButton.icon(
              key: const Key('charge-controllers-pick-catalog'),
              onPressed: () async {
                final repo = context.read<CatalogRepository>();
                final entry =
                    await showCatalogPicker<cc.ChargeControllerCatalogEntry>(
                  context,
                  repository: repo,
                  kind: cc.ComponentKind.chargeController,
                );
                if (entry == null) return;
                final n = draft.chargeControllers.length + 1;
                draft.chargeControllers.add(ChargeControllerDraft(
                  id: 'cc-$n',
                  dcBusId: _defaultDcBusId(draft),
                  efficiency: entry.efficiency,
                  maxInputKw: entry.maxInputKw,
                  label: entry.displayName,
                ));
                controller.touch();
              },
              icon: const Icon(Icons.library_books_outlined),
              label: Text(l.catalogPickButton),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              key: const Key('charge-controllers-add'),
              onPressed: () {
                final n = draft.chargeControllers.length + 1;
                draft.chargeControllers.add(ChargeControllerDraft(
                  id: 'cc-$n',
                  dcBusId: _defaultDcBusId(draft),
                  label: l.chargeControllersDefaultLabel(n),
                ));
                controller.touch();
              },
              icon: const Icon(Icons.add),
              label: Text(l.commonAdd),
            ),
          ]),
          if (draft.chargeControllers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(l.chargeControllersEmpty),
            ),
          for (var i = 0; i < draft.chargeControllers.length; i++) ...[
            const Divider(height: 24),
            _ChargeControllerEditor(
              key: ValueKey(
                  'charge-controller-${draft.chargeControllers[i].id}-$i'),
              index: i,
              controllerDraft: draft.chargeControllers[i],
              onChanged: controller.touch,
              onRemove: () {
                draft.chargeControllers.removeAt(i);
                controller.touch();
              },
            ),
          ],
        ]),
      ),
    );
  }
}

class _ChargeControllerEditor extends StatelessWidget {
  const _ChargeControllerEditor({
    super.key,
    required this.index,
    required this.controllerDraft,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final ChargeControllerDraft controllerDraft;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(l.chargeControllersHeading(index + 1),
              style: Theme.of(context).textTheme.titleSmall),
        ),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline),
          tooltip: l.commonRemove,
        ),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(
          width: 180,
          child: StringField(
            label: l.fieldId,
            initialValue: controllerDraft.id,
            required: true,
            onChanged: (v) {
              controllerDraft.id = v;
              onChanged();
            },
          ),
        ),
        SizedBox(
          width: 220,
          child: StringField(
            label: l.fieldLabel,
            initialValue: controllerDraft.label,
            onChanged: (v) {
              controllerDraft.label = v;
              onChanged();
            },
          ),
        ),
        SizedBox(
          width: 220,
          child: StringField(
            label: l.chargeControllersFieldDcBusId,
            initialValue: controllerDraft.dcBusId,
            required: true,
            helpText: l.chargeControllersFieldDcBusIdHelp,
            onChanged: (v) {
              controllerDraft.dcBusId = v;
              onChanged();
            },
          ),
        ),
        SizedBox(
          width: 160,
          child: NumberField(
            label: l.chargeControllersFieldEfficiency,
            suffix: '0..1',
            initialValue: controllerDraft.efficiency,
            min: 0.01,
            max: 1.0,
            onChanged: (v) {
              if (v != null) {
                controllerDraft.efficiency = v;
                onChanged();
              }
            },
          ),
        ),
        SizedBox(
          width: 220,
          child: NumberField(
            label: l.chargeControllersFieldMaxInputKw,
            suffix: 'kW',
            initialValue: controllerDraft.maxInputKw,
            min: 0.001,
            allowNull: true,
            helpText: l.chargeControllersFieldMaxInputKwHelp,
            onChanged: (v) {
              controllerDraft.maxInputKw = v;
              onChanged();
            },
          ),
        ),
      ]),
    ]);
  }
}
