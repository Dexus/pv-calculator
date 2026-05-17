import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../state/project_controller.dart';
import '_field.dart';

class LoadSection extends StatelessWidget {
  const LoadSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final load = controller.draft.loadProfile;
    final l = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.loadTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 200, child: NumberField(
              label: l.loadFieldDaily,
              suffix: 'kWh/Tag',
              initialValue: load.dailyKwh,
              min: 0,
              onChanged: (v) {
                if (v != null) { load.dailyKwh = v; controller.touch(); }
              },
            )),
          ]),
          const SizedBox(height: 8),
          Text(
            l.loadHourlyHint,
            style: const TextStyle(fontSize: 12),
          ),
        ]),
      ),
    );
  }
}
