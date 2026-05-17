import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../state/config_draft.dart';
import '../../state/project_controller.dart';
import '_field.dart';

/// Phase 4: pluggable dispatch policy picker. Hidden behind an
/// `ExpansionTile` so projects that stick with the default
/// `SelfConsumptionFirst` don't see extra noise on the Auswertung tab.
class DispatchPolicySection extends StatelessWidget {
  const DispatchPolicySection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final draft = controller.draft.dispatchPolicy;
    final l = AppLocalizations.of(context);

    return Card(
      child: ExpansionTile(
        title: Text(l.dispatchPolicyTitle),
        subtitle: Text(_labelFor(l, draft.kind), maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: const Icon(Icons.alt_route),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 320, child: DropdownButtonFormField<DispatchPolicyKind>(
                key: const Key('dispatch-policy-kind'),
                isExpanded: true,
                initialValue: draft.kind,
                decoration: InputDecoration(labelText: l.dispatchPolicyKindLabel, isDense: true),
                items: [
                  for (final k in DispatchPolicyKind.values)
                    DropdownMenuItem(value: k, child: Text(_labelFor(l, k))),
                ],
                onChanged: (v) {
                  if (v != null) {
                    draft.kind = v;
                    controller.touch();
                  }
                },
              )),
              const SizedBox(height: 12),
              Text(_descriptionFor(l, draft.kind), style: Theme.of(context).textTheme.bodySmall),
              if (draft.kind == DispatchPolicyKind.batteryReserve) ...[
                const SizedBox(height: 16),
                SizedBox(width: 220, child: NumberField(
                  key: const Key('dispatch-policy-reserve-fraction'),
                  label: l.dispatchPolicyReserveSoc,
                  suffix: '0..1',
                  initialValue: draft.reserveSocFraction,
                  min: 0.0, max: 1.0,
                  helpText: l.dispatchPolicyReserveSocHelp,
                  onChanged: (v) {
                    if (v != null) {
                      draft.reserveSocFraction = v;
                      controller.touch();
                    }
                  },
                )),
              ],
              if (draft.kind == DispatchPolicyKind.gridAssist) ...[
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  key: const Key('dispatch-policy-grid-import'),
                  contentPadding: EdgeInsets.zero,
                  value: draft.gridAssistAllowImport,
                  onChanged: (v) {
                    draft.gridAssistAllowImport = v;
                    controller.touch();
                  },
                  title: Text(l.dispatchPolicyGridImportLabel),
                  subtitle: Text(l.dispatchPolicyGridImportHelp),
                ),
              ],
              if (draft.kind == DispatchPolicyKind.timeWindowFeed ||
                  draft.kind == DispatchPolicyKind.constantFeed24h) ...[
                const SizedBox(height: 8),
                Text(l.dispatchPolicyBankHint, style: Theme.of(context).textTheme.bodySmall),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  String _labelFor(AppLocalizations l, DispatchPolicyKind k) {
    switch (k) {
      case DispatchPolicyKind.selfConsumption:
        return l.dispatchPolicySelfConsumption;
      case DispatchPolicyKind.batteryReserve:
        return l.dispatchPolicyReserve;
      case DispatchPolicyKind.constantFeed24h:
        return l.dispatchPolicyConstantFeed;
      case DispatchPolicyKind.timeWindowFeed:
        return l.dispatchPolicyTimeWindow;
      case DispatchPolicyKind.gridAssist:
        return l.dispatchPolicyGridAssist;
    }
  }

  String _descriptionFor(AppLocalizations l, DispatchPolicyKind k) {
    switch (k) {
      case DispatchPolicyKind.selfConsumption:
        return l.dispatchPolicySelfConsumptionDesc;
      case DispatchPolicyKind.batteryReserve:
        return l.dispatchPolicyReserveDesc;
      case DispatchPolicyKind.constantFeed24h:
        return l.dispatchPolicyConstantFeedDesc;
      case DispatchPolicyKind.timeWindowFeed:
        return l.dispatchPolicyTimeWindowDesc;
      case DispatchPolicyKind.gridAssist:
        return l.dispatchPolicyGridAssistDesc;
    }
  }
}
