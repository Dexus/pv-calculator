import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../state/config_draft.dart';
import '../../state/project_controller.dart';
import '_field.dart';

/// Phase 4: list of battery-coupled AC output banks (e.g. "Steckersolar").
///
/// Each bank picks a source battery from the project's battery list and
/// declares its count × unit power, SOC shutdown, internal efficiency,
/// and optional time-windowed schedule. Banks are shown inside an
/// [ExpansionTile] so projects without banks (the default) don't see
/// extra noise.
class MicroInverterBanksSection extends StatelessWidget {
  const MicroInverterBanksSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final draft = controller.draft;
    final l = AppLocalizations.of(context);

    return Card(
      child: ExpansionTile(
        title: Text(l.microInverterBanksTitle),
        subtitle: Text(l.microInverterBanksCount(draft.microInverterBanks.length)),
        leading: const Icon(Icons.power_outlined),
        initiallyExpanded: draft.microInverterBanks.isNotEmpty,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    l.microInverterBanksWarnPvDevice,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                FilledButton.tonalIcon(
                  key: const Key('add-bank-button'),
                  onPressed: () {
                    final n = draft.microInverterBanks.length + 1;
                    final defaultBatteryId = draft.batteries.isNotEmpty ? draft.batteries.first.id : '';
                    draft.microInverterBanks.add(MicroInverterBankDraft(
                      id: 'bank-$n',
                      label: l.microInverterBanksDefaultLabel(n),
                      batteryId: defaultBatteryId,
                    ));
                    controller.touch();
                  },
                  icon: const Icon(Icons.add),
                  label: Text(l.commonAdd),
                ),
              ]),
              if (draft.microInverterBanks.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(l.microInverterBanksEmpty),
                ),
              for (var i = 0; i < draft.microInverterBanks.length; i++) ...[
                const Divider(height: 24),
                _BankEditor(
                  key: ValueKey('bank-${draft.microInverterBanks[i].id}-$i'),
                  index: i,
                  bank: draft.microInverterBanks[i],
                  batteryIds: [for (final b in draft.batteries) b.id],
                  onChanged: controller.touch,
                  onRemove: () {
                    draft.microInverterBanks.removeAt(i);
                    controller.touch();
                  },
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

class _BankEditor extends StatelessWidget {
  const _BankEditor({
    super.key,
    required this.index,
    required this.bank,
    required this.batteryIds,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final MicroInverterBankDraft bank;
  final List<String> batteryIds;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasBatteries = batteryIds.isNotEmpty;
    final selectedId = batteryIds.contains(bank.batteryId) ? bank.batteryId : (hasBatteries ? batteryIds.first : null);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(l.microInverterBanksHeading(index + 1), style: Theme.of(context).textTheme.titleSmall)),
        IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline), tooltip: l.commonRemove),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: 180, child: StringField(
          label: l.fieldId, initialValue: bank.id, required: true,
          onChanged: (v) { bank.id = v; onChanged(); },
        )),
        SizedBox(width: 220, child: StringField(
          label: l.fieldLabel, initialValue: bank.label,
          onChanged: (v) { bank.label = v; onChanged(); },
        )),
        SizedBox(width: 220, child: DropdownButtonFormField<String>(
          key: Key('bank-${bank.id}-source'),
          isExpanded: true,
          initialValue: selectedId,
          decoration: InputDecoration(labelText: l.microInverterBankBattery, isDense: true),
          items: [
            for (final id in batteryIds) DropdownMenuItem(value: id, child: Text(id)),
          ],
          onChanged: hasBatteries ? (v) {
            if (v != null) {
              bank.batteryId = v;
              onChanged();
            }
          } : null,
        )),
        SizedBox(width: 140, child: NumberField(
          label: l.microInverterBankCount, initialValue: bank.count.toDouble(),
          min: 0, max: 999, allowDecimal: false,
          onChanged: (v) { if (v != null) { bank.count = v.round(); onChanged(); } },
        )),
        SizedBox(width: 180, child: NumberField(
          label: l.microInverterBankUnitW, suffix: 'W', initialValue: bank.unitRatedPowerW,
          min: 1,
          onChanged: (v) { if (v != null) { bank.unitRatedPowerW = v; onChanged(); } },
        )),
        SizedBox(width: 180, child: NumberField(
          label: l.microInverterBankShutdown, suffix: '0..1', initialValue: bank.minSocShutdown,
          min: 0, max: 1,
          helpText: l.microInverterBankShutdownHelp,
          onChanged: (v) { if (v != null) { bank.minSocShutdown = v; onChanged(); } },
        )),
        SizedBox(width: 180, child: NumberField(
          label: l.microInverterBankEfficiency, suffix: '0..1', initialValue: bank.inverterEfficiency,
          min: 0.01, max: 1,
          onChanged: (v) { if (v != null) { bank.inverterEfficiency = v; onChanged(); } },
        )),
      ]),
      const SizedBox(height: 12),
      _ScheduleEditor(bank: bank, onChanged: onChanged),
    ]);
  }
}

class _ScheduleEditor extends StatelessWidget {
  const _ScheduleEditor({required this.bank, required this.onChanged});

  final MicroInverterBankDraft bank;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasWindows = bank.windows.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(l.microInverterBankSchedule, style: Theme.of(context).textTheme.titleSmall)),
        TextButton.icon(
          key: Key('bank-${bank.id}-add-window'),
          onPressed: () {
            bank.windows.add(TimeWindowDraft());
            onChanged();
          },
          icon: const Icon(Icons.add_alarm),
          label: Text(l.microInverterBankAddWindow),
        ),
      ]),
      if (!hasWindows)
        Text(l.microInverterBankAlwaysOn, style: Theme.of(context).textTheme.bodySmall),
      for (var i = 0; i < bank.windows.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 140, child: NumberField(
              label: l.microInverterBankWindowStart, suffix: 'h',
              initialValue: bank.windows[i].startHour, min: 0, max: 24,
              onChanged: (v) { if (v != null) { bank.windows[i].startHour = v; onChanged(); } },
            )),
            const SizedBox(width: 8),
            SizedBox(width: 140, child: NumberField(
              label: l.microInverterBankWindowEnd, suffix: 'h',
              initialValue: bank.windows[i].endHour, min: 0, max: 24,
              onChanged: (v) { if (v != null) { bank.windows[i].endHour = v; onChanged(); } },
            )),
            const SizedBox(width: 8),
            SizedBox(width: 140, child: NumberField(
              label: l.microInverterBankWindowFactor, suffix: '0..1',
              initialValue: bank.windows[i].factor, min: 0, max: 1,
              onChanged: (v) { if (v != null) { bank.windows[i].factor = v; onChanged(); } },
            )),
            IconButton(
              tooltip: l.commonRemove,
              onPressed: () { bank.windows.removeAt(i); onChanged(); },
              icon: const Icon(Icons.close),
            ),
          ]),
        ),
    ]);
  }
}
