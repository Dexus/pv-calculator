import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pv_engine/pv_engine.dart';

import '../config.dart';
import '../l10n/generated/app_localizations.dart';
import '../persistence/file_io.dart';
import '../state/config_draft.dart';
import '../state/project_controller.dart';
import '../widgets/forms/_field.dart';
import '../widgets/forms/batteries_section.dart';
import '../widgets/forms/dispatch_policy_section.dart';
import '../widgets/forms/inverters_section.dart';
import '../widgets/forms/load_section.dart';
import '../widgets/forms/micro_inverter_banks_section.dart';
import '../widgets/forms/topology_section.dart';
import '../widgets/results/bank_runtime_chart.dart';
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
        _SimParamsSection(),
        const SizedBox(height: 12),
        const InvertersSection(),
        const SizedBox(height: 12),
        const BatteriesSection(),
        const SizedBox(height: 12),
        const TopologySection(),
        const SizedBox(height: 12),
        const MicroInverterBanksSection(),
        const SizedBox(height: 12),
        const DispatchPolicySection(),
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
          bankLabels: [
            for (final b in draft.microInverterBanks) b.label.isEmpty ? b.id : b.label,
          ],
          timeStep: draft.timeStep,
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

/// Expandable tile exposing the simulation-level parameters that have no
/// dedicated tab of their own: days, timestep, pre-run days, grid export
/// limit. Previously these lived in the deleted ProjectSection card.
class _SimParamsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = context.watch<ProjectController>();
    final draft = controller.draft;
    final showWarmUp = draft.preRunMode == PreRunMode.singleWarmUp;
    final showConvergence = draft.preRunMode == PreRunMode.cyclicConvergence;
    final cyclicSelectable = kProFeatures ||
        draft.preRunMode == PreRunMode.cyclicConvergence;
    return Card(
      child: ExpansionTile(
        title: Text(l.projectSectionTitle),
        leading: const Icon(Icons.tune),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(width: 180, child: NumberField(
                label: l.projectSimulationDays,
                initialValue: draft.days.toDouble(),
                min: 1, max: 366,
                onChanged: (v) { if (v != null) { draft.days = v.round(); controller.touch(); } },
              )),
              SizedBox(width: 180, child: NumberField(
                label: l.projectStartDay,
                initialValue: draft.startDayOfYear.toDouble(),
                min: 1, max: 365,
                onChanged: (v) { if (v != null) { draft.startDayOfYear = v.round(); controller.touch(); } },
              )),
              SizedBox(width: 220, child: DropdownButtonFormField<PreRunMode>(
                key: const Key('pre-run-mode-dropdown'),
                isExpanded: true,
                initialValue: draft.preRunMode,
                decoration: InputDecoration(labelText: l.projectPreRunMode, isDense: true),
                items: [
                  DropdownMenuItem(
                    value: PreRunMode.manual,
                    child: Text(l.projectPreRunModeManual),
                  ),
                  DropdownMenuItem(
                    value: PreRunMode.singleWarmUp,
                    child: Text(l.projectPreRunModeSingle),
                  ),
                  DropdownMenuItem(
                    value: PreRunMode.cyclicConvergence,
                    enabled: cyclicSelectable,
                    child: Text(cyclicSelectable
                        ? l.projectPreRunModeCyclic
                        : l.projectPreRunModeCyclicPro),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  draft.preRunMode = v;
                  // Cyclic convergence enforces full-year, zero warm-up at
                  // the engine; mirror that here so users don't get a
                  // confusing validation error after the fact.
                  if (v == PreRunMode.cyclicConvergence) {
                    draft.days = 365;
                    draft.preRunDays = 0;
                  }
                  controller.touch();
                },
              )),
              if (showWarmUp)
                SizedBox(width: 180, child: NumberField(
                  label: l.projectPreRunDays,
                  helpText: l.projectPreRunHelp,
                  initialValue: draft.preRunDays.toDouble(),
                  min: 0, max: 365,
                  onChanged: (v) { if (v != null) { draft.preRunDays = v.round(); controller.touch(); } },
                )),
              if (showConvergence) ...[
                SizedBox(width: 200, child: NumberField(
                  key: const Key('convergence-tolerance-field'),
                  label: l.projectConvergenceTolerance,
                  suffix: '%',
                  helpText: l.projectConvergenceToleranceHelp,
                  // Stored as a fraction (0..1); the UI works in % to
                  // match the PRD §6.2 "0,5 %" example.
                  initialValue: draft.convergenceToleranceFraction * 100,
                  min: 0.001, max: 100,
                  onChanged: (v) {
                    if (v != null) {
                      draft.convergenceToleranceFraction = v / 100;
                      controller.touch();
                    }
                  },
                )),
                SizedBox(width: 200, child: NumberField(
                  key: const Key('max-convergence-iterations-field'),
                  label: l.projectMaxConvergenceIterations,
                  initialValue: draft.maxConvergenceIterations.toDouble(),
                  min: 1, max: 100,
                  onChanged: (v) {
                    if (v != null) {
                      draft.maxConvergenceIterations = v.round();
                      controller.touch();
                    }
                  },
                )),
              ],
              SizedBox(width: 200, child: NumberField(
                label: l.projectExportLimit,
                suffix: 'kW',
                initialValue: draft.gridExportLimitKw,
                min: 0,
                onChanged: (v) { draft.gridExportLimitKw = v; controller.touch(); },
              )),
              SizedBox(width: 200, child: DropdownButtonFormField<TimeStep>(
                isExpanded: true,
                initialValue: draft.timeStep,
                decoration: InputDecoration(labelText: l.projectTimeStep, isDense: true),
                items: [
                  DropdownMenuItem(value: TimeStep.hourly, child: Text(l.projectTimeStepHourly)),
                  DropdownMenuItem(value: TimeStep.quarterHourly, child: Text(l.projectTimeStepQuarter)),
                ],
                onChanged: (v) { if (v != null) { draft.timeStep = v; controller.touch(); } },
              )),
            ]),
          ),
        ],
      ),
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
    required this.bankLabels,
    required this.timeStep,
    required this.onExportCsv,
  });

  final SimulationResult result;
  final String projectName;
  final List<String> bankLabels;
  final TimeStep timeStep;
  final _CsvExportCallback onExportCsv;

  @override
  Widget build(BuildContext context) {
    final s = result.summary;
    final monthly = SummaryAggregator.monthly(result.steps);
    final batteryCount = s.finalBatterySocsKwh.length;
    final bankCount = result.steps.isEmpty
        ? 0
        : result.steps.first.microInverterDeliveriesKwh.length;
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
        if (s.microInverterDeliveredKwh > 0 || s.microInverterShortfallKwh > 0) ...[
          _KpiCard(label: l.resultsKpiMicroDelivered, value: '${s.microInverterDeliveredKwh.toStringAsFixed(0)} kWh'),
          _KpiCard(label: l.resultsKpiMicroShortfall, value: '${s.microInverterShortfallKwh.toStringAsFixed(0)} kWh'),
        ],
        if (s.unservedLoadKwh > 0)
          _KpiCard(label: l.resultsKpiUnservedLoad, value: '${s.unservedLoadKwh.toStringAsFixed(0)} kWh'),
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
      // Pre-Run report per PRD §6.2 line 260 "Ergebnisreport muss
      // anzeigen, ob Pre-Run aktiv war und welchen Start-SOC das
      // Ergebnisjahr bekommen hat" — shown whenever pre-run actually
      // ran, or for cyclic mode so non-convergence is always surfaced.
      if (s.preRunActive || s.preRunMode == PreRunMode.cyclicConvergence) ...[
        const SizedBox(height: 24),
        Text(l.resultsPreRunSection, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _KpiCard(
            key: const Key('pre-run-mode-card'),
            label: l.resultsPreRunMode,
            value: _preRunModeLabel(l, s.preRunMode),
          ),
          _KpiCard(
            key: const Key('pre-run-iterations-card'),
            label: l.resultsPreRunIterations,
            value: s.convergenceIterations.toString(),
          ),
          _KpiCard(
            key: const Key('pre-run-converged-card'),
            label: l.resultsPreRunConverged,
            value: s.converged ? l.resultsPreRunConvergedYes : l.resultsPreRunConvergedNo,
          ),
          for (var i = 0; i < s.startSocsUsedKwh.length; i++)
            _KpiCard(
              label: l.resultsPreRunStartSoc(i + 1),
              value: '${s.startSocsUsedKwh[i].toStringAsFixed(2)} kWh',
            ),
        ]),
      ],
      if (bankCount > 0) ...[
        const SizedBox(height: 24),
        Text(l.bankRuntimeSectionTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _BankRuntimeSection(
          steps: result.steps,
          bankLabels: bankLabels,
          timeStep: timeStep,
        ),
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
            content: stepsCsv(result.steps, batteryCount: batteryCount, bankCount: bankCount),
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

String _preRunModeLabel(AppLocalizations l, PreRunMode mode) {
  switch (mode) {
    case PreRunMode.manual:
      return l.projectPreRunModeManual;
    case PreRunMode.singleWarmUp:
      return l.projectPreRunModeSingle;
    case PreRunMode.cyclicConvergence:
      return l.projectPreRunModeCyclic;
  }
}

class _BankRuntimeSection extends StatelessWidget {
  const _BankRuntimeSection({
    required this.steps,
    required this.bankLabels,
    required this.timeStep,
  });

  final List<SimulationStep> steps;
  final List<String> bankLabels;
  final TimeStep timeStep;

  @override
  Widget build(BuildContext context) {
    final runtime = SummaryAggregator.bankRuntime(
      steps,
      bankCount: bankLabels.length,
      timeStep: timeStep,
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < bankLabels.length; i++) ...[
        if (i > 0) const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: BankRuntimeChart(
              bankLabel: bankLabels[i],
              daily: SummaryAggregator.bankDaily(
                steps,
                bankIndex: i,
                timeStep: timeStep,
              ),
              stats: runtime[i],
            ),
          ),
        ),
      ],
    ]);
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({super.key, required this.label, required this.value});
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
