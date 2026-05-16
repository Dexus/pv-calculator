import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/project_controller.dart';
import '_field.dart';

class LoadSection extends StatelessWidget {
  const LoadSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final load = controller.draft.loadProfile;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Lastprofil', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 200, child: NumberField(
              label: 'Tagesverbrauch',
              suffix: 'kWh/Tag',
              initialValue: load.dailyKwh,
              min: 0,
              onChanged: (v) {
                if (v != null) { load.dailyKwh = v; controller.touch(); }
              },
            )),
          ]),
          const SizedBox(height: 8),
          const Text(
            'Stundenform: deutsches Haushalts-Standardprofil (24 Werte). '
            'Eine manuelle Anpassung der Stundenform ist für eine spätere Version vorgesehen.',
            style: TextStyle(fontSize: 12),
          ),
        ]),
      ),
    );
  }
}
