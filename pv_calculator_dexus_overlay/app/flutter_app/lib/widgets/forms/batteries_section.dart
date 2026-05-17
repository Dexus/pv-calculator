import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../state/config_draft.dart';
import '../../state/project_controller.dart';
import '_field.dart';

class BatteriesSection extends StatelessWidget {
  const BatteriesSection({super.key});

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
            Expanded(child: Text(l.batteriesTitle, style: Theme.of(context).textTheme.titleMedium)),
            FilledButton.tonalIcon(
              onPressed: () {
                final n = draft.batteries.length + 1;
                draft.batteries.add(BatteryDraft(
                  id: 'battery-$n',
                  label: l.batteriesDefaultLabel(n),
                ));
                controller.touch();
              },
              icon: const Icon(Icons.add),
              label: Text(l.commonAdd),
            ),
          ]),
          if (draft.batteries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(l.batteriesEmpty),
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
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(l.batteriesHeading(widget.index + 1), style: Theme.of(context).textTheme.titleSmall)),
        IconButton(onPressed: widget.onRemove, icon: const Icon(Icons.delete_outline), tooltip: l.commonRemove),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: 180, child: StringField(
          label: l.fieldId, initialValue: battery.id, required: true,
          onChanged: (v) { battery.id = v; widget.onChanged(); },
        )),
        SizedBox(width: 220, child: StringField(
          label: l.fieldLabel, initialValue: battery.label,
          onChanged: (v) { battery.label = v; widget.onChanged(); },
        )),
        SizedBox(width: 160, child: NumberField(
          label: l.batteriesFieldCapacity, suffix: 'kWh', initialValue: battery.capacityKwh, min: 0,
          onChanged: (v) { if (v != null) { battery.capacityKwh = v; widget.onChanged(); } },
        )),
        SizedBox(width: 160, child: NumberField(
          label: l.batteriesFieldChargePower, suffix: 'kW', initialValue: battery.maxChargeKw, min: 0,
          onChanged: (v) { if (v != null) { battery.maxChargeKw = v; widget.onChanged(); } },
        )),
        SizedBox(width: 160, child: NumberField(
          label: l.batteriesFieldDischargePower, suffix: 'kW', initialValue: battery.maxDischargeKw, min: 0,
          onChanged: (v) { if (v != null) { battery.maxDischargeKw = v; widget.onChanged(); } },
        )),
        SizedBox(width: 200, child: NumberField(
          label: l.batteriesFieldRoundtrip, suffix: '0..1',
          initialValue: battery.roundTripEfficiency, min: 0.01, max: 1.0,
          helpText: l.batteriesFieldRoundtripHelp,
          onChanged: (v) { if (v != null) { battery.roundTripEfficiency = v; widget.onChanged(); } },
        )),
        SizedBox(width: 160, child: NumberField(
          label: l.batteriesFieldMinSoc, suffix: 'kWh', initialValue: battery.minSocKwh,
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
        Text(l.batteriesCustomInitial),
        const SizedBox(width: 12),
        if (_customInitial)
          SizedBox(width: 160, child: NumberField(
            label: l.batteriesFieldStartSoc, suffix: 'kWh', initialValue: battery.initialSocKwh,
            allowNull: true,
            min: battery.minSocKwh, max: battery.capacityKwh,
            onChanged: (v) { battery.initialSocKwh = v; widget.onChanged(); },
          )),
      ]),
    ]);
  }
}
