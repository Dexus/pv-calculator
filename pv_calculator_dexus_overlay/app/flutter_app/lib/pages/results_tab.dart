import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pv_engine/pv_engine.dart';

import '../l10n/generated/app_localizations.dart';
import '../persistence/file_io.dart';
import '../state/config_draft.dart';
import '../state/project_controller.dart';
import '../widgets/forms/batteries_section.dart';
import '../widgets/forms/inverters_section.dart';
import '../widgets/forms/load_section.dart';
import '../widgets/results/monthly_table.dart';

/// Auswertung tab — system definition (inverters + batteries + load
/// profile), Run button, and result KPIs + monthly table. The PV array
/// list lives on the PV-Arrays tab and the site irradiance on the
/// Einstrahlung tab; this tab assembles the rest and runs the engine.
class ResultsTab extends StatelessWidget {
  const ResultsTab({super.key, this.fileIo});

  final FileIo? fileIo;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = context.watch<ProjectController>();
    final draft = controller.draft;
    final issue = draft.validationIssue();
    final hasIrradiance = draft.siteIrradiance.samples != null;
    final hasArrays = draft.arrays.isNotEmpty;
    final canRun = !controller.running && issue == null && hasIrradiance && hasArrays;
    final result = controller.result;
    final io = fileIo ?? const FileIo();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (controller.lastError != null)
          _ErrorCard(title: l.resultsErrorTitle, message: controller.lastError!),
        if (issue != null && issue.section != ConfigSection.arrays)
          _ErrorCard(title: l.editorValidationTitle, message: issue.message),
        if (!hasIrradiance || !hasArrays)
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: ListTile(
              leading: Icon(Icons.info_outline,
                  color: Theme.of(context).colorScheme.onTertiaryContainer),
              title: Text(
                l.resultsRunMissingData,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ),
        const InvertersSection(),
        const SizedBox(height: 12),
        const BatteriesSection(),
        const SizedBox(height: 12),
        const LoadSection(),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            key: const Key('results-run-button'),
            onPressed: canRun ? () => controller.run() : null,
            icon: controller.running
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow),
            label: Text(l.resultsRun),
          ),
        ),
        const SizedBox(height: 24),
        if (result != null) _ResultsBody(
          result: result,
          projectName: controller.projectName,
          onExportCsv: ({required String filename, required String content}) =>
              io.exportCsv(filename: filename, content: content),
        ),
        const SizedBox(height: 16),
        Text(
          l.resultsSyntheticNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ]),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: scheme.errorContainer,
        child: ListTile(
          leading: Icon(Icons.error_outline, color: scheme.onErrorContainer),
          title: Text(title, style: TextStyle(color: scheme.onErrorContainer)),
          subtitle: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
        ),
      ),
    );
  }
}

typedef _CsvExportCallback = Future<void> Function({required String filename, required String content});

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({
    required this.result,
    required this.projectName,
    required this.onExportCsv,
  });

  final SimulationResult result;
  final String projectName;
  final _CsvExportCallback onExportCsv;

  @override
  Widget build(BuildContext context) {
    final s = result.summary;
    final monthly = SummaryAggregator.monthly(result.steps);
    final batteryCount = s.finalBatterySocsKwh.length;
    final l = AppLocalizations.of(context);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.resultsAnnualKpis, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 12, children: [
        _KpiCard(label: l.resultsKpiPvAc, value: '${s.pvAcKwh.toStringAsFixed(0)} kWh'),
        _KpiCard(label: l.resultsKpiLoad, value: '${s.loadKwh.toStringAsFixed(0)} kWh'),
        _KpiCard(label: l.resultsKpiSelfConsumption, value: '${s.selfConsumptionKwh.toStringAsFixed(0)} kWh'),
        _KpiCard(label: l.resultsKpiGridImport, value: '${s.gridImportKwh.toStringAsFixed(0)} kWh'),
        _KpiCard(label: l.resultsKpiGridExport, value: '${s.gridExportKwh.toStringAsFixed(0)} kWh'),
        _KpiCard(label: l.resultsKpiCurtailDc, value: '${s.curtailedDcKwh.toStringAsFixed(0)} kWh'),
        _KpiCard(label: l.resultsKpiCurtailAc, value: '${s.curtailedAcKwh.toStringAsFixed(0)} kWh'),
        _KpiCard(label: l.resultsKpiCurtailExport, value: '${s.curtailedExportKwh.toStringAsFixed(0)} kWh'),
        _KpiCard(label: l.resultsKpiBatteryCharge, value: '${s.batteryChargeKwh.toStringAsFixed(0)} kWh'),
        _KpiCard(label: l.resultsKpiBatteryDischarge, value: '${s.batteryDischargeKwh.toStringAsFixed(0)} kWh'),
        _KpiCard(label: l.resultsKpiAutarky, value: '${(s.autarkyRate * 100).toStringAsFixed(1)} %'),
        _KpiCard(label: l.resultsKpiSelfConsumptionRate, value: '${(s.selfConsumptionRate * 100).toStringAsFixed(1)} %'),
      ]),
      if (batteryCount > 0) ...[
        const SizedBox(height: 24),
        Text(l.resultsBatterySection, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (var i = 0; i < batteryCount; i++)
            _KpiCard(label: l.resultsBatteryLabel(i + 1), value: '${s.finalBatterySocsKwh[i].toStringAsFixed(2)} kWh'),
        ]),
      ],
      const SizedBox(height: 24),
      Text(l.resultsMonthly, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(8), child: MonthlyTable(buckets: monthly))),
      const SizedBox(height: 24),
      Wrap(spacing: 12, runSpacing: 12, children: [
        FilledButton.tonalIcon(
          key: const Key('export-steps-csv'),
          onPressed: () => _exportCsv(
            context,
            filename: '${_safe(projectName)}_schritte.csv',
            content: stepsCsv(result.steps, batteryCount: batteryCount),
          ),
          icon: const Icon(Icons.file_download),
          label: Text(l.resultsCsvSteps),
        ),
        FilledButton.tonalIcon(
          key: const Key('export-monthly-csv'),
          onPressed: () => _exportCsv(
            context,
            filename: '${_safe(projectName)}_monatlich.csv',
            content: monthlyCsv(monthly),
          ),
          icon: const Icon(Icons.file_download),
          label: Text(l.resultsCsvMonthly),
        ),
      ]),
    ]);
  }

  Future<void> _exportCsv(BuildContext context, {required String filename, required String content}) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    try {
      await onExportCsv(filename: filename, content: content);
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(
        kIsWeb ? l.projectListDownloaded(filename) : l.resultsExported(filename),
      )));
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.resultsExportFailed(e.toString()))));
    }
  }

  String _safe(String name) => name.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ]),
        ),
      ),
    );
  }
}
