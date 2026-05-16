import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pv_engine/pv_engine.dart';

import '../../state/config_draft.dart';
import '../../state/project_controller.dart';
import '_field.dart';

class InvertersSection extends StatelessWidget {
  const InvertersSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final draft = controller.draft;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Wechselrichter', style: Theme.of(context).textTheme.titleMedium)),
            FilledButton.tonalIcon(
              onPressed: () {
                final n = draft.inverters.length + 1;
                draft.inverters.add(InverterDraft(
                  id: 'inverter-$n',
                  label: 'Wechselrichter $n',
                ));
                controller.touch();
              },
              icon: const Icon(Icons.add),
              label: const Text('Hinzufügen'),
            ),
          ]),
          if (draft.inverters.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Mindestens ein Wechselrichter ist erforderlich.'),
            ),
          for (var i = 0; i < draft.inverters.length; i++) ...[
            const Divider(height: 24),
            _InverterEditor(
              key: ValueKey('inverter-${draft.inverters[i].id}-$i'),
              index: i,
              inverter: draft.inverters[i],
              onChanged: controller.touch,
              onRemove: () {
                draft.inverters.removeAt(i);
                controller.touch();
              },
            ),
          ],
        ]),
      ),
    );
  }
}

class _InverterEditor extends StatelessWidget {
  const _InverterEditor({
    super.key,
    required this.index,
    required this.inverter,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final InverterDraft inverter;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Wechselrichter ${index + 1}', style: Theme.of(context).textTheme.titleSmall)),
        IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline), tooltip: 'Entfernen'),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: 180, child: StringField(
          label: 'ID', initialValue: inverter.id, required: true,
          onChanged: (v) { inverter.id = v; onChanged(); },
        )),
        SizedBox(width: 220, child: StringField(
          label: 'Bezeichnung', initialValue: inverter.label,
          onChanged: (v) { inverter.label = v; onChanged(); },
        )),
        SizedBox(width: 160, child: NumberField(
          label: 'Max. AC-Leistung', suffix: 'kW', initialValue: inverter.maxAcKw, min: 0.001,
          onChanged: (v) { if (v != null) { inverter.maxAcKw = v; onChanged(); } },
        )),
        SizedBox(width: 160, child: NumberField(
          label: 'Wirkungsgrad', suffix: '0..1', initialValue: inverter.efficiency, min: 0.01, max: 1.0,
          onChanged: (v) { if (v != null) { inverter.efficiency = v; onChanged(); } },
        )),
        SizedBox(width: 200, child: NumberField(
          label: 'Max. DC-Eingang', suffix: 'kW (optional)',
          initialValue: inverter.maxDcInputKw, min: 0.001, allowNull: true,
          onChanged: (v) { inverter.maxDcInputKw = v; onChanged(); },
        )),
        SizedBox(width: 240, child: DropdownButtonFormField<InverterRole>(
          isExpanded: true,
          initialValue: inverter.role,
          decoration: const InputDecoration(labelText: 'Rolle', isDense: true),
          items: const [
            DropdownMenuItem(value: InverterRole.grid, child: Text('Netz', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: InverterRole.microInverter800W, child: Text('800-W-Micro', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: InverterRole.batteryCoupled, child: Text('Batteriegekoppelt', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) { if (v != null) { inverter.role = v; onChanged(); } },
        )),
      ]),
    ]);
  }
}
