import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/config_draft.dart';
import '../../state/project_controller.dart';
import '_field.dart';

class BatteriesSection extends StatelessWidget {
  const BatteriesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final draft = controller.draft;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Batteriespeicher', style: Theme.of(context).textTheme.titleMedium)),
            FilledButton.tonalIcon(
              onPressed: () {
                final n = draft.batteries.length + 1;
                draft.batteries.add(BatteryDraft(
                  id: 'battery-$n',
                  label: 'Speicher $n',
                ));
                controller.touch();
              },
              icon: const Icon(Icons.add),
              label: const Text('Hinzufügen'),
            ),
          ]),
          if (draft.batteries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Kein Batteriespeicher konfiguriert (optional).'),
            ),
          for (var i = 0; i < draft.batteries.length; i++) ...[
            const Divider(height: 24),
            _BatteryEditor(
              key: ValueKey('battery-${draft.batteries[i].id}-$i'),
              index: i,
              battery: draft.batteries[i],
              onChanged: controller.touch,
              onRemove: () {
                draft.batteries.removeAt(i);
                controller.touch();
              },
            ),
          ],
        ]),
      ),
    );
  }
}

class _BatteryEditor extends StatefulWidget {
  const _BatteryEditor({
    super.key,
    required this.index,
    required this.battery,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final BatteryDraft battery;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<_BatteryEditor> createState() => _BatteryEditorState();
}

class _BatteryEditorState extends State<_BatteryEditor> {
  late bool _customInitial;

  @override
  void initState() {
    super.initState();
    _customInitial = widget.battery.initialSocKwh != null;
  }

  @override
  Widget build(BuildContext context) {
    final battery = widget.battery;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Speicher ${widget.index + 1}', style: Theme.of(context).textTheme.titleSmall)),
        IconButton(onPressed: widget.onRemove, icon: const Icon(Icons.delete_outline), tooltip: 'Entfernen'),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: 180, child: StringField(
          label: 'ID', initialValue: battery.id, required: true,
          onChanged: (v) { battery.id = v; widget.onChanged(); },
        )),
        SizedBox(width: 220, child: StringField(
          label: 'Bezeichnung', initialValue: battery.label,
          onChanged: (v) { battery.label = v; widget.onChanged(); },
        )),
        SizedBox(width: 160, child: NumberField(
          label: 'Kapazität', suffix: 'kWh', initialValue: battery.capacityKwh, min: 0,
          onChanged: (v) { if (v != null) { battery.capacityKwh = v; widget.onChanged(); } },
        )),
        SizedBox(width: 160, child: NumberField(
          label: 'Max. Ladeleistung', suffix: 'kW', initialValue: battery.maxChargeKw, min: 0,
          onChanged: (v) { if (v != null) { battery.maxChargeKw = v; widget.onChanged(); } },
        )),
        SizedBox(width: 160, child: NumberField(
          label: 'Max. Entladeleistung', suffix: 'kW', initialValue: battery.maxDischargeKw, min: 0,
          onChanged: (v) { if (v != null) { battery.maxDischargeKw = v; widget.onChanged(); } },
        )),
        SizedBox(width: 200, child: NumberField(
          label: 'Roundtrip-Wirkungsgrad', suffix: '0..1',
          initialValue: battery.roundTripEfficiency, min: 0.01, max: 1.0,
          helpText: 'Lade- × Entladewirkungsgrad. Typisch 0,9 für Lithium-Speicher, '
              '≈ 0,75 für Blei-Speicher.',
          onChanged: (v) { if (v != null) { battery.roundTripEfficiency = v; widget.onChanged(); } },
        )),
        SizedBox(width: 160, child: NumberField(
          label: 'Min. SOC', suffix: 'kWh', initialValue: battery.minSocKwh,
          min: 0, max: battery.capacityKwh,
          onChanged: (v) { if (v != null) { battery.minSocKwh = v; widget.onChanged(); } },
        )),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Checkbox(
          value: _customInitial,
          onChanged: (v) {
            setState(() {
              _customInitial = v ?? false;
              if (!_customInitial) {
                battery.initialSocKwh = null;
                widget.onChanged();
              }
            });
          },
        ),
        const Text('Start-SOC manuell setzen'),
        const SizedBox(width: 12),
        if (_customInitial)
          SizedBox(width: 160, child: NumberField(
            label: 'Start-SOC', suffix: 'kWh', initialValue: battery.initialSocKwh,
            allowNull: true,
            min: battery.minSocKwh, max: battery.capacityKwh,
            onChanged: (v) { battery.initialSocKwh = v; widget.onChanged(); },
          )),
      ]),
    ]);
  }
}
