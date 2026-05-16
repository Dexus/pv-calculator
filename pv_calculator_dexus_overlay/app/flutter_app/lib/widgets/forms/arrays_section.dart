import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/config_draft.dart';
import '../../state/project_controller.dart';
import '_field.dart';

class ArraysSection extends StatelessWidget {
  const ArraysSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final draft = controller.draft;
    final inverterIds = draft.inverters.map((i) => i.id).where((id) => id.isNotEmpty).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('PV-Module', style: Theme.of(context).textTheme.titleMedium)),
            FilledButton.tonalIcon(
              onPressed: () {
                final n = draft.arrays.length + 1;
                draft.arrays.add(PvArrayDraft(
                  id: 'array-$n',
                  label: 'Modulfeld $n',
                  inverterId: inverterIds.isNotEmpty ? inverterIds.first : '',
                ));
                controller.touch();
              },
              icon: const Icon(Icons.add),
              label: const Text('Hinzufügen'),
            ),
          ]),
          if (draft.arrays.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Mindestens ein Modulfeld ist erforderlich.'),
            ),
          for (var i = 0; i < draft.arrays.length; i++) ...[
            const Divider(height: 24),
            _ArrayEditor(
              key: ValueKey('array-${draft.arrays[i].id}-$i'),
              index: i,
              array: draft.arrays[i],
              inverterIds: inverterIds,
              onChanged: controller.touch,
              onRemove: () {
                draft.arrays.removeAt(i);
                controller.touch();
              },
            ),
          ],
        ]),
      ),
    );
  }
}

class _ArrayEditor extends StatelessWidget {
  const _ArrayEditor({
    super.key,
    required this.index,
    required this.array,
    required this.inverterIds,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final PvArrayDraft array;
  final List<String> inverterIds;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Modulfeld ${index + 1}', style: Theme.of(context).textTheme.titleSmall)),
        IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline), tooltip: 'Entfernen'),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: 180, child: StringField(
          label: 'ID', initialValue: array.id, required: true,
          onChanged: (v) { array.id = v; onChanged(); },
        )),
        SizedBox(width: 220, child: StringField(
          label: 'Bezeichnung', initialValue: array.label,
          onChanged: (v) { array.label = v; onChanged(); },
        )),
        SizedBox(width: 160, child: NumberField(
          label: 'Spitzenleistung', suffix: 'kWp', initialValue: array.peakKw, min: 0.001,
          onChanged: (v) { if (v != null) { array.peakKw = v; onChanged(); } },
        )),
        SizedBox(width: 160, child: NumberField(
          label: 'Azimut', suffix: '°', initialValue: array.azimuthDeg, min: 0, max: 360,
          onChanged: (v) { if (v != null) { array.azimuthDeg = v; onChanged(); } },
        )),
        SizedBox(width: 160, child: NumberField(
          label: 'Neigung', suffix: '°', initialValue: array.tiltDeg, min: 0, max: 90,
          onChanged: (v) { if (v != null) { array.tiltDeg = v; onChanged(); } },
        )),
        SizedBox(width: 160, child: NumberField(
          label: 'Verluste', suffix: '0..1', initialValue: array.lossFactor, min: 0, max: 0.999,
          onChanged: (v) { if (v != null) { array.lossFactor = v; onChanged(); } },
        )),
        SizedBox(width: 160, child: NumberField(
          label: 'Verschattung', suffix: '0..1', initialValue: array.shadingFactor, min: 0, max: 0.999,
          onChanged: (v) { if (v != null) { array.shadingFactor = v; onChanged(); } },
        )),
        SizedBox(width: 200, child: NumberField(
          label: 'Temperaturkoeff.', suffix: '%/°C',
          initialValue: array.temperatureCoefficientPctPerC, min: -2, max: 0,
          onChanged: (v) { if (v != null) { array.temperatureCoefficientPctPerC = v; onChanged(); } },
        )),
        SizedBox(width: 160, child: NumberField(
          label: 'NOCT', suffix: '°C',
          initialValue: array.nominalOperatingCellTempC, min: 20, max: 70,
          onChanged: (v) { if (v != null) { array.nominalOperatingCellTempC = v; onChanged(); } },
        )),
        SizedBox(width: 220, child: DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: inverterIds.contains(array.inverterId) ? array.inverterId : null,
          decoration: const InputDecoration(labelText: 'Wechselrichter', isDense: true),
          items: [
            for (final id in inverterIds)
              DropdownMenuItem(value: id, child: Text(id, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) { if (v != null) { array.inverterId = v; onChanged(); } },
          validator: (v) => (v == null || v.isEmpty) ? 'Wechselrichter auswählen' : null,
        )),
      ]),
    ]);
  }
}
