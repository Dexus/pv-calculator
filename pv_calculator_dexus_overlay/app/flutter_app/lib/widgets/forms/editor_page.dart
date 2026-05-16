import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/project_controller.dart';
import 'arrays_section.dart';
import 'batteries_section.dart';
import 'inverters_section.dart';
import 'load_section.dart';
import 'project_section.dart';

class EditorPage extends StatelessWidget {
  const EditorPage({super.key, this.onRunRequested});

  final VoidCallback? onRunRequested;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final error = controller.draft.validationError();

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.projectName),
        actions: [
          if (controller.running)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: FilledButton.icon(
                key: const Key('run-button'),
                onPressed: error != null
                    ? null
                    : () {
                        final ok = controller.run();
                        if (ok) onRunRequested?.call();
                      },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Simulation starten'),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('Konfiguration unvollständig'),
                subtitle: Text(error),
              ),
            ),
          const SizedBox(height: 8),
          const ProjectSection(),
          const SizedBox(height: 16),
          const InvertersSection(),
          const SizedBox(height: 16),
          const ArraysSection(),
          const SizedBox(height: 16),
          const BatteriesSection(),
          const SizedBox(height: 16),
          const LoadSection(),
          const SizedBox(height: 16),
          Text(
            'Hinweis: Diese Simulation nutzt ein synthetisches Demo-Strahlungsmodell und ersetzt keine PVGIS-Validierung.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
