import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/config_draft.dart';
import '../../state/project_controller.dart';
import 'arrays_section.dart';
import 'batteries_section.dart';
import 'inverters_section.dart';
import 'load_section.dart';
import 'project_section.dart';

String _weatherHint(int withPvgis, int totalArrays) {
  const sessionNote = ' PVGIS-Importe gelten nur für diese Sitzung; '
      'beim erneuten Öffnen eines gespeicherten Projekts müssen sie neu importiert werden.';
  if (totalArrays == 0 || withPvgis == 0) {
    return 'Hinweis: Diese Simulation nutzt ein synthetisches Demo-Strahlungsmodell und ersetzt keine PVGIS-Validierung. '
        'Du kannst pro Modulfeld eine PVGIS-Stündliche-Daten-JSON importieren, um reale Einstrahlung zu nutzen.';
  }
  if (withPvgis == totalArrays) {
    return 'Wetterquelle: PVGIS-Daten für alle $totalArrays Modulfelder importiert. '
        'TMY-Mittelwerte über die in der Datei enthaltenen Jahre.$sessionNote';
  }
  return 'Wetterquelle gemischt: $withPvgis von $totalArrays Modulfeldern nutzen importierte PVGIS-Daten, '
      'die übrigen fallen auf das synthetische Demo-Modell zurück.$sessionNote';
}

class EditorPage extends StatelessWidget {
  const EditorPage({super.key, this.onRunRequested});

  final VoidCallback? onRunRequested;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final issue = controller.draft.validationIssue();
    final orphaned = controller.draft.orphanedWeatherArrayIds().toList();
    // Surface a previous failed run() here: the run button only navigates
    // to the results page on success, so without this banner the user
    // would otherwise see no feedback for a simulator-side failure.
    // `lastError` is cleared by `ProjectController.touch()` so the
    // message disappears on the user's next form edit.
    final runError = controller.lastError;

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
                onPressed: issue != null
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
          // Last-run error sits above everything else: it relates to
          // the *whole* draft, not a single section.
          if (runError != null && issue == null)
            _RunErrorCard(
              key: const Key('run-error-banner'),
              message: runError,
            ),
          // Top-level banner only when the message can't be routed to a
          // specific section — keeps unknown / cross-cutting errors
          // visible without duplicating the section-level chip.
          if (issue != null && issue.section == ConfigSection.unknown)
            _ValidationCard(
              key: const Key('validation-banner-unknown'),
              message: issue.message,
            ),
          if (orphaned.isNotEmpty) _OrphanedImportsCard(orphaned: orphaned),
          const SizedBox(height: 8),
          _sectionWithError(ConfigSection.project, issue,
              child: const ProjectSection()),
          const SizedBox(height: 16),
          _sectionWithError(ConfigSection.inverters, issue,
              child: const InvertersSection()),
          const SizedBox(height: 16),
          _sectionWithError(ConfigSection.arrays, issue,
              child: const ArraysSection()),
          const SizedBox(height: 16),
          _sectionWithError(ConfigSection.batteries, issue,
              child: const BatteriesSection()),
          const SizedBox(height: 16),
          _sectionWithError(ConfigSection.load, issue,
              child: const LoadSection()),
          const SizedBox(height: 16),
          Text(
            _weatherHint(controller.draft.arraysWithWeatherCount, controller.draft.arrays.length),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  /// Renders an inline error card immediately above [child] when the
  /// classified issue belongs to [section]. The widget tree's order
  /// keeps the message visually adjacent to the section it refers to.
  Widget _sectionWithError(ConfigSection section, ValidationIssue? issue,
      {required Widget child}) {
    if (issue == null || issue.section != section) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ValidationCard(
          key: Key('validation-banner-${section.name}'),
          message: issue.message,
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _ValidationCard extends StatelessWidget {
  const _ValidationCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.error_outline, color: scheme.onErrorContainer),
        title: Text(
          'Konfiguration unvollständig',
          style: TextStyle(color: scheme.onErrorContainer),
        ),
        subtitle: Text(
          message,
          style: TextStyle(color: scheme.onErrorContainer),
        ),
      ),
    );
  }
}

class _RunErrorCard extends StatelessWidget {
  const _RunErrorCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.error_outline, color: scheme.onErrorContainer),
        title: Text(
          'Simulation fehlgeschlagen',
          style: TextStyle(color: scheme.onErrorContainer),
        ),
        subtitle: Text(
          message,
          style: TextStyle(color: scheme.onErrorContainer),
        ),
      ),
    );
  }
}

class _OrphanedImportsCard extends StatelessWidget {
  const _OrphanedImportsCard({required this.orphaned});

  final List<String> orphaned;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ProjectController>();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('orphaned-pvgis-card'),
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.warning_amber_rounded, color: scheme.onTertiaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'PVGIS-Importe ohne passendes Modulfeld',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: scheme.onTertiaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Die folgenden importierten Wetterreihen verweisen auf gelöschte oder umbenannte Modulfelder '
            'und werden von der Simulation nicht genutzt. Über „Vergessen“ kannst du sie freigeben.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final id in orphaned)
              InputChip(
                key: Key('orphaned-pvgis-chip-$id'),
                label: Text(id),
                avatar: const Icon(Icons.cloud_off_outlined, size: 18),
                onDeleted: () {
                  controller.draft.clearArrayWeather(id);
                  controller.touch();
                },
                deleteIcon: const Icon(Icons.close, size: 16),
                deleteButtonTooltipMessage: 'Vergessen',
              ),
          ]),
        ]),
      ),
    );
  }
}
