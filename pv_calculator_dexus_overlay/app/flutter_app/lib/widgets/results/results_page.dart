import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pv_engine/pv_engine.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../state/project_controller.dart';
import 'monthly_table.dart';

typedef CsvExportCallback = Future<void> Function({required String filename, required String content});

class ResultsPage extends StatelessWidget {
  const ResultsPage({super.key, this.onExportCsv});

  /// Hook for persistence layer (lands in C7). When null, buttons render but
  /// only echo a SnackBar to confirm the engine produced the right CSV.
  final CsvExportCallback? onExportCsv;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final result = controller.result;
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.resultsTitle(controller.projectName)),
      ),
      // Run failures are surfaced on the editor (the only screen the
      // run button stays on after a failed run), so this page only has
      // to handle the happy and the never-ran states.
      body: result != null
          ? _ResultsBody(result: result, projectName: controller.projectName, onExportCsv: onExportCsv)
          : const _EmptyResultsBody(),
    );
  }
}

class _EmptyResultsBody extends StatelessWidget {
  const _EmptyResultsBody();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bolt_outlined, size: 64, color: scheme.outline),
          const SizedBox(height: 12),
          Text(l.resultsEmpty),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
            label: Text(l.resultsBack),
          ),
        ]),
      ),
    );
  }
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({required this.result, required this.projectName, required this.onExportCsv});

  final SimulationResult result;
  final String projectName;
  final CsvExportCallback? onExportCsv;

  @override
  Widget build(BuildContext context) {
    final s = result.summary;
    final monthly = SummaryAggregator.monthly(result.steps);
    final batteryCount = s.finalBatterySocsKwh.length;
    final l = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
            label: Text(l.resultsBack),
          ),
        ]),
        const SizedBox(height: 16),
        Text(
          l.resultsSyntheticNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _exportCsv(BuildContext context, {required String filename, required String content}) async {
    final callback = onExportCsv;
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    if (callback == null) {
      messenger.showSnackBar(SnackBar(
        content: Text(l.resultsCsvPending(content.length)),
      ));
      return;
    }
    try {
      await callback(filename: filename, content: content);
      messenger.showSnackBar(SnackBar(content: Text(l.resultsExported(filename))));
    } catch (e) {
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
