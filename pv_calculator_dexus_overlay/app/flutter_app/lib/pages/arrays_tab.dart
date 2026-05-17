import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../state/config_draft.dart';
import '../state/project_controller.dart';
import '../widgets/forms/_field.dart';

/// PV-Arrays tab — per-array editor. Reads the cached horizontal
/// irradiance from the Einstrahlung tab; nothing here triggers a
/// network call. The compass toggle on each row marks that array as
/// the target for the [AzimuthCompass] overlay that lives on the
/// Einstrahlung tab.
class ArraysTab extends StatelessWidget {
  const ArraysTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = context.watch<ProjectController>();
    final draft = controller.draft;
    final inverterIds =
        draft.inverters.map((i) => i.id).where((id) => id.isNotEmpty).toList();
    final selected = controller.selectedArrayIndex;
    final issue = draft.validationIssue();
    final issueForSection = issue?.section == ConfigSection.arrays ? issue : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l.arraysTabHint, style: Theme.of(context).textTheme.bodySmall),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          if (issueForSection != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.onErrorContainer),
                title: Text(
                  issueForSection.message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          Row(children: [
            Expanded(child: Text(l.arraysTitle, style: Theme.of(context).textTheme.titleMedium)),
            FilledButton.tonalIcon(
              onPressed: () {
                final n = draft.arrays.length + 1;
                draft.arrays.add(PvArrayDraft(
                  id: 'array-$n',
                  label: l.arraysDefaultLabel(n),
                  inverterId: inverterIds.isNotEmpty ? inverterIds.first : '',
                ));
                controller.touch();
              },
              icon: const Icon(Icons.add),
              label: Text(l.commonAdd),
            ),
          ]),
          if (draft.arrays.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(l.arraysEmpty),
            ),
          for (var i = 0; i < draft.arrays.length; i++) ...[
            const SizedBox(height: 12),
            _ArrayCard(
              key: ValueKey('array-${draft.arrays[i].id}-$i'),
              index: i,
              array: draft.arrays[i],
              inverterIds: inverterIds,
              isCompassTarget: selected == i,
              onToggleCompass: () => controller.selectArrayForCompass(selected == i ? null : i),
              onChanged: controller.touch,
              onRemove: () {
                if (selected == i) controller.selectArrayForCompass(null);
                draft.arrays.removeAt(i);
                controller.touch();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ArrayCard extends StatelessWidget {
  const _ArrayCard({
    super.key,
    required this.index,
    required this.array,
    required this.inverterIds,
    required this.isCompassTarget,
    required this.onToggleCompass,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final PvArrayDraft array;
  final List<String> inverterIds;
  final bool isCompassTarget;
  final VoidCallback onToggleCompass;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isCompassTarget ? scheme.primary : scheme.outlineVariant,
          width: isCompassTarget ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(l.arraysHeading(index + 1), style: Theme.of(context).textTheme.titleSmall)),
            IconButton(
              tooltip: l.arraysSelectForCompass,
              icon: Icon(
                isCompassTarget ? Icons.explore : Icons.explore_outlined,
                color: isCompassTarget ? scheme.primary : null,
              ),
              onPressed: onToggleCompass,
            ),
            IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline), tooltip: l.commonRemove),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 180, child: StringField(
              label: l.fieldId, initialValue: array.id, required: true,
              onChanged: (v) { array.id = v; onChanged(); },
            )),
            SizedBox(width: 220, child: StringField(
              label: l.fieldLabel, initialValue: array.label,
              onChanged: (v) { array.label = v; onChanged(); },
            )),
            SizedBox(width: 160, child: NumberField(
              label: l.arraysFieldPeak, suffix: 'kWp', initialValue: array.peakKw, min: 0.001,
              onChanged: (v) { if (v != null) { array.peakKw = v; onChanged(); } },
            )),
            SizedBox(width: 160, child: NumberField(
              key: ValueKey('array-${array.id}-azimuth'),
              label: l.arraysFieldAzimuth, suffix: '°',
              initialValue: array.azimuthDeg, min: 0, max: 360,
              onChanged: (v) { if (v != null) { array.azimuthDeg = v; onChanged(); } },
            )),
            SizedBox(width: 160, child: NumberField(
              label: l.arraysFieldTilt, suffix: '°', initialValue: array.tiltDeg, min: 0, max: 90,
              onChanged: (v) { if (v != null) { array.tiltDeg = v; onChanged(); } },
            )),
            SizedBox(width: 160, child: NumberField(
              label: l.arraysFieldLosses, suffix: '0..1', initialValue: array.lossFactor, min: 0, max: 0.999,
              onChanged: (v) { if (v != null) { array.lossFactor = v; onChanged(); } },
            )),
            SizedBox(width: 160, child: NumberField(
              label: l.arraysFieldShading, suffix: '0..1', initialValue: array.shadingFactor, min: 0, max: 0.999,
              onChanged: (v) { if (v != null) { array.shadingFactor = v; onChanged(); } },
            )),
            SizedBox(width: 220, child: NumberField(
              label: l.arraysFieldTempCoef, suffix: '%/°C',
              initialValue: array.temperatureCoefficientPctPerC, min: -2, max: 0,
              helpText: l.arraysFieldTempCoefHelp,
              onChanged: (v) { if (v != null) { array.temperatureCoefficientPctPerC = v; onChanged(); } },
            )),
            SizedBox(width: 180, child: NumberField(
              label: l.arraysFieldNoct, suffix: '°C',
              initialValue: array.nominalOperatingCellTempC, min: 20, max: 70,
              helpText: l.arraysFieldNoctHelp,
              onChanged: (v) { if (v != null) { array.nominalOperatingCellTempC = v; onChanged(); } },
            )),
            SizedBox(width: 220, child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: inverterIds.contains(array.inverterId) ? array.inverterId : null,
              decoration: InputDecoration(labelText: l.arraysFieldInverter, isDense: true),
              items: [
                for (final id in inverterIds)
                  DropdownMenuItem(value: id, child: Text(id, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) { if (v != null) { array.inverterId = v; onChanged(); } },
              validator: (v) => (v == null || v.isEmpty) ? l.arraysFieldInverterRequired : null,
            )),
          ]),
        ]),
      ),
    );
  }
}
