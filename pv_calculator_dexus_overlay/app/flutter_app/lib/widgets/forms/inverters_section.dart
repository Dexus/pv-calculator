import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pv_engine/pv_engine.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../state/config_draft.dart';
import '../../state/project_controller.dart';
import '_field.dart';

class InvertersSection extends StatelessWidget {
  const InvertersSection({super.key});

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
            Expanded(child: Text(l.invertersTitle, style: Theme.of(context).textTheme.titleMedium)),
            FilledButton.tonalIcon(
              onPressed: () {
                final n = draft.inverters.length + 1;
                draft.inverters.add(InverterDraft(
                  id: 'inverter-$n',
                  label: l.invertersDefaultLabel(n),
                ));
                controller.touch();
              },
              icon: const Icon(Icons.add),
              label: Text(l.commonAdd),
            ),
          ]),
          if (draft.inverters.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(l.invertersEmpty),
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
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(l.invertersHeading(index + 1), style: Theme.of(context).textTheme.titleSmall)),
        IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline), tooltip: l.commonRemove),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: 180, child: StringField(
          label: l.fieldId, initialValue: inverter.id, required: true,
          onChanged: (v) { inverter.id = v; onChanged(); },
        )),
        SizedBox(width: 220, child: StringField(
          label: l.fieldLabel, initialValue: inverter.label,
          onChanged: (v) { inverter.label = v; onChanged(); },
        )),
        SizedBox(width: 160, child: NumberField(
          label: l.invertersFieldMaxAc, suffix: 'kW', initialValue: inverter.maxAcKw, min: 0.001,
          onChanged: (v) { if (v != null) { inverter.maxAcKw = v; onChanged(); } },
        )),
        SizedBox(width: 160, child: NumberField(
          label: l.invertersFieldEfficiency, suffix: '0..1', initialValue: inverter.efficiency, min: 0.01, max: 1.0,
          onChanged: (v) { if (v != null) { inverter.efficiency = v; onChanged(); } },
        )),
        SizedBox(width: 220, child: NumberField(
          label: l.invertersFieldMaxDc, suffix: 'kW',
          initialValue: inverter.maxDcInputKw, min: 0.001, allowNull: true,
          helpText: l.invertersFieldMaxDcHelp,
          onChanged: (v) { inverter.maxDcInputKw = v; onChanged(); },
        )),
        SizedBox(width: 260, child: _RoleDropdown(
          role: inverter.role,
          onChanged: (v) { inverter.role = v; onChanged(); },
        )),
      ]),
    ]);
  }
}

class _RoleDropdown extends StatelessWidget {
  const _RoleDropdown({required this.role, required this.onChanged});

  final InverterRole role;
  final ValueChanged<InverterRole> onChanged;

  String _helpText(AppLocalizations l) {
    switch (role) {
      case InverterRole.microInverter800W:
        return l.invertersRoleMicroHelp;
      case InverterRole.batteryCoupled:
        return l.invertersRoleBatteryHelp;
      case InverterRole.grid:
        return l.invertersRoleGridHelp;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(children: [
      Expanded(
        child: DropdownButtonFormField<InverterRole>(
          isExpanded: true,
          initialValue: role,
          decoration: InputDecoration(labelText: l.invertersFieldRole, isDense: true),
          items: [
            DropdownMenuItem(value: InverterRole.grid, child: Text(l.invertersRoleGrid, overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: InverterRole.microInverter800W, child: Text(l.invertersRoleMicro, overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: InverterRole.batteryCoupled, child: Text(l.invertersRoleBattery, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
      Tooltip(
        message: _helpText(l),
        triggerMode: TooltipTriggerMode.tap,
        showDuration: const Duration(seconds: 6),
        child: const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Icon(Icons.help_outline, size: 18),
        ),
      ),
    ]);
  }
}
