import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pv_engine/pv_engine.dart';

import '../l10n/generated/app_localizations.dart';
import '../state/config_draft.dart';
import '../state/optimizer_controller.dart';
import '../state/project_controller.dart';
import '../widgets/forms/_field.dart';
import '../widgets/results/optimizer_results_table.dart';

/// Phase-10 Optimizer page. Lets a user sweep over battery capacity,
/// inverter AC, PV scale and a per-array on/off toggle, ranks the
/// resulting candidates by either autarky or net cost over a configurable
/// horizon, and respects a hard budget cap.
///
/// The page is Pro-gated at its entry point in the Results tab; the page
/// itself doesn't re-check `kProFeatures` because Navigator.push from a
/// disabled button is impossible in production. Widget tests construct
/// the page directly with the controller they need.
class OptimizerPage extends StatefulWidget {
  const OptimizerPage({super.key});

  @override
  State<OptimizerPage> createState() => _OptimizerPageState();
}

class _OptimizerPageState extends State<OptimizerPage> {
  // Sweep ranges. The Min/Max/Steps fields are required — `_SweepInputs
  // .toList()` always returns at least one value, so every sweep
  // dimension is realised in the Cartesian product. Pin a dimension by
  // setting `Steps = 1` (collapses to `[Min]`). The engine still
  // accepts empty sweep arrays for non-UI callers; the page just
  // doesn't expose that gesture.
  final _SweepInputs _battery = _SweepInputs(min: 5.0, max: 15.0, steps: 3);
  final _SweepInputs _inverter = _SweepInputs(min: 4.0, max: 8.0, steps: 3);
  final _SweepInputs _pvScale = _SweepInputs(min: 0.8, max: 1.4, steps: 4);

  double _pricePv = 1000;
  double _priceInverter = 300;
  double _priceBattery = 600;
  double? _budget;
  int _horizonYears = 10;
  double _discountRatePct = 0;
  double _priceEscalationPctPerYear = 0;

  OptimizerObjective _objective = OptimizerObjective.maxAutarky;

  /// Set of array IDs the user has flagged as "optional" — the
  /// optimizer enumerates every subset of these per combo.
  final Set<String> _optionalArrayIds = <String>{};

  /// Cached reference to the (app-scoped) controller so `dispose` can
  /// supersede any in-flight run without touching `context` after the
  /// element is unmounted. Captured the first time `build` reads it.
  OptimizerController? _controllerRef;

  @override
  void dispose() {
    // The controller is provided at app scope, so a sweep kicked off
    // here keeps running after the user navigates away. Supersede the
    // generation (and cancel the underlying isolate when supported) so
    // a late result can't clobber the controller's state after the
    // user has loaded a different project.
    _controllerRef?.supersede();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final draft = context.watch<ProjectController>().draft;
    final controller = context.watch<OptimizerController>();
    _controllerRef = controller;
    final tariffActive = draft.tariff.enabled;
    // Derived view of the objective: if the tariff is inactive we
    // can't actually run `minNetCost`, so the dropdown and the run
    // path both treat the effective value as `maxAutarky`. We do NOT
    // mutate `_objective` here (state mutation during build trips
    // framework assertions) — the value is restored as soon as the
    // user re-enables the tariff.
    final effectiveObjective =
        (!tariffActive && _objective == OptimizerObjective.minNetCost)
            ? OptimizerObjective.maxAutarky
            : _objective;
    return Scaffold(
      appBar: AppBar(title: Text(l.optimizerTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(l.optimizerIntro, style: Theme.of(context).textTheme.bodyMedium),
            ),
            _objectiveCard(context, l, tariffActive, effectiveObjective),
            const SizedBox(height: 12),
            _sweepsCard(context, l),
            const SizedBox(height: 12),
            _pricesCard(context, l),
            const SizedBox(height: 12),
            if (draft.arrays.isNotEmpty) ...[
              _optionalArraysCard(context, l, draft),
              const SizedBox(height: 12),
            ],
            _runCard(context, l, controller, draft, effectiveObjective),
            const SizedBox(height: 12),
            _resultsSection(context, l, controller),
          ],
        ),
      ),
    );
  }

  Widget _objectiveCard(BuildContext context, AppLocalizations l, bool tariffActive, OptimizerObjective effectiveObjective) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.optimizerSectionObjective, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<OptimizerObjective>(
              key: const Key('optimizer-objective'),
              isExpanded: true,
              initialValue: effectiveObjective,
              decoration: const InputDecoration(isDense: true),
              items: [
                DropdownMenuItem(
                  value: OptimizerObjective.maxAutarky,
                  child: Text(l.optimizerObjectiveAutarky, overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: OptimizerObjective.minNetCost,
                  enabled: tariffActive,
                  child: Text(l.optimizerObjectiveNetCost, overflow: TextOverflow.ellipsis),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                if (v == OptimizerObjective.minNetCost && !tariffActive) return;
                setState(() => _objective = v);
              },
            ),
            if (!tariffActive) ...[
              const SizedBox(height: 4),
              Text(
                l.optimizerObjectiveNetCostHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sweepsCard(BuildContext context, AppLocalizations l) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.optimizerSectionSweeps, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(l.optimizerSweepHint, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            _sweepRow(context, l, l.optimizerSweepBattery, _battery, 'battery'),
            const SizedBox(height: 8),
            _sweepRow(context, l, l.optimizerSweepInverter, _inverter, 'inverter'),
            const SizedBox(height: 8),
            _sweepRow(context, l, l.optimizerSweepPvScale, _pvScale, 'pv-scale'),
          ],
        ),
      ),
    );
  }

  Widget _sweepRow(BuildContext context, AppLocalizations l, String label, _SweepInputs s, String keyPrefix) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(
          child: NumberField(
            key: Key('optimizer-$keyPrefix-min'),
            label: l.optimizerSweepMin,
            initialValue: s.min,
            min: 0,
            onChanged: (v) => setState(() => s.min = v ?? s.min),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: NumberField(
            key: Key('optimizer-$keyPrefix-max'),
            label: l.optimizerSweepMax,
            initialValue: s.max,
            min: 0,
            onChanged: (v) => setState(() => s.max = v ?? s.max),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: IntField(
            key: Key('optimizer-$keyPrefix-steps'),
            label: l.optimizerSweepSteps,
            initialValue: s.steps,
            min: 1,
            max: 12,
            onChanged: (v) => setState(() => s.steps = v),
          ),
        ),
      ]),
    ]);
  }

  Widget _pricesCard(BuildContext context, AppLocalizations l) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.optimizerSectionPrices, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: NumberField(
                    key: const Key('optimizer-price-pv'),
                    label: l.optimizerPricePv,
                    initialValue: _pricePv,
                    min: 0,
                    onChanged: (v) => setState(() => _pricePv = v ?? _pricePv),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: NumberField(
                    key: const Key('optimizer-price-inverter'),
                    label: l.optimizerPriceInverter,
                    initialValue: _priceInverter,
                    min: 0,
                    onChanged: (v) => setState(() => _priceInverter = v ?? _priceInverter),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: NumberField(
                    key: const Key('optimizer-price-battery'),
                    label: l.optimizerPriceBattery,
                    initialValue: _priceBattery,
                    min: 0,
                    onChanged: (v) => setState(() => _priceBattery = v ?? _priceBattery),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: NumberField(
                    key: const Key('optimizer-budget'),
                    label: l.optimizerBudget,
                    initialValue: _budget,
                    allowNull: true,
                    min: 0,
                    onChanged: (v) => setState(() => _budget = v),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: IntField(
                    key: const Key('optimizer-horizon'),
                    label: l.optimizerHorizon,
                    initialValue: _horizonYears,
                    min: 1,
                    max: 100,
                    onChanged: (v) => setState(() => _horizonYears = v),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: NumberField(
                    key: const Key('optimizer-discount-rate'),
                    label: l.optimizerDiscountRate,
                    initialValue: _discountRatePct,
                    min: -99.0,
                    onChanged: (v) => setState(
                        () => _discountRatePct = v ?? _discountRatePct),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: NumberField(
                    key: const Key('optimizer-price-escalation'),
                    label: l.optimizerPriceEscalation,
                    initialValue: _priceEscalationPctPerYear,
                    min: -99.0,
                    onChanged: (v) => setState(() =>
                        _priceEscalationPctPerYear =
                            v ?? _priceEscalationPctPerYear),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(l.optimizerDiscountHint,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _optionalArraysCard(BuildContext context, AppLocalizations l, ConfigDraft draft) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.optimizerSectionOptionalArrays,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(l.optimizerOptionalArraysHint,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            for (final a in draft.arrays)
              CheckboxListTile(
                key: Key('optimizer-optional-${a.id}'),
                value: _optionalArrayIds.contains(a.id),
                title: Text(a.label.isEmpty ? a.id : a.label),
                subtitle: Text('${a.peakKw.toStringAsFixed(1)} kWp, ${a.azimuthDeg.toStringAsFixed(0)}°/${a.tiltDeg.toStringAsFixed(0)}°'),
                dense: true,
                onChanged: (v) => setState(() {
                  if (v == true) {
                    if (_optionalArrayIds.length >= 4) return;
                    _optionalArrayIds.add(a.id);
                  } else {
                    _optionalArrayIds.remove(a.id);
                  }
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _runCard(BuildContext context, AppLocalizations l, OptimizerController controller, ConfigDraft draft, OptimizerObjective effectiveObjective) {
    final progress = controller.progress;
    final progressValue =
        progress != null && progress.total > 0 ? progress.fraction : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('optimizer-run'),
                    onPressed: controller.running ? null : () => _onRun(controller, draft, effectiveObjective),
                    icon: const Icon(Icons.tune),
                    label: Text(controller.running ? l.optimizerRunning : l.optimizerRunButton),
                  ),
                ),
                if (controller.running) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: controller.canCancel
                        ? l.optimizerCancelButton
                        : l.optimizerCancelUnavailable,
                    child: TextButton.icon(
                      key: const Key('optimizer-cancel'),
                      onPressed:
                          controller.canCancel ? controller.cancel : null,
                      icon: const Icon(Icons.cancel),
                      label: Text(l.optimizerCancelButton),
                    ),
                  ),
                ],
              ],
            ),
            if (controller.running) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progressValue),
              if (progress != null && progress.total > 0) ...[
                const SizedBox(height: 4),
                Text(
                  l.optimizerProgress(progress.done, progress.total),
                  key: const Key('optimizer-progress'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
            if (!controller.running && controller.cancelled) ...[
              const SizedBox(height: 8),
              Text(
                l.optimizerCancelled,
                key: const Key('optimizer-cancelled'),
                style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
              ),
            ],
            if (controller.lastError != null) ...[
              const SizedBox(height: 8),
              Text(
                l.optimizerErrorPrefix(controller.lastError!),
                key: const Key('optimizer-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resultsSection(BuildContext context, AppLocalizations l, OptimizerController controller) {
    final result = controller.lastResult;
    if (result == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.optimizerCounters(
                result.evaluated,
                result.skippedOverBudget,
                result.failedValidation,
              ),
              key: const Key('optimizer-counters'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (result.candidates.isEmpty)
              Text(
                l.optimizerNoCandidates,
                key: const Key('optimizer-no-candidates'),
              )
            else
              OptimizerResultsTable(candidates: result.candidates),
          ],
        ),
      ),
    );
  }

  void _onRun(OptimizerController controller, ConfigDraft draft, OptimizerObjective objective) {
    // Engine `OptimizerSpec.validate()` rejects a non-empty
    // batterySweepKwh / inverterSweepKw when the baseline has no
    // batteries / inverters. Gate the sweep arrays so PV-only projects
    // (allowed by the app's Batteries section) can still optimize PV
    // scale + array mix.
    final hasBattery = draft.batteries.isNotEmpty;
    final hasInverter = draft.inverters.isNotEmpty;
    // Drop any optional-array IDs that no longer exist in the draft.
    // The Set survives array rename/delete in the Arrays tab, but the
    // engine validates the IDs against the baseline; without this
    // filter a stale entry causes the run to throw "unknown array".
    final liveArrayIds = {for (final a in draft.arrays) a.id};
    final optionalIds =
        _optionalArrayIds.where(liveArrayIds.contains).toList(growable: false);
    final spec = OptimizerSpec(
      // Replaced by the controller; passing a placeholder is fine.
      baseline: draft.buildForRun(),
      prices: OptimizerPrices(
        eurPerKwpPv: _pricePv,
        eurPerKwAcInverter: _priceInverter,
        eurPerKwhBattery: _priceBattery,
      ),
      objective: objective,
      batterySweepKwh: hasBattery ? _battery.toList() : const [],
      inverterSweepKw: hasInverter ? _inverter.toList() : const [],
      pvScaleSweep: _pvScale.toList(),
      optionalArrayIds: optionalIds,
      budgetEur: _budget,
      horizonYears: _horizonYears,
      discountRatePct: _discountRatePct,
      priceEscalationPctPerYear: _priceEscalationPctPerYear,
    );
    controller.runFromDraft(draft, spec);
  }
}

/// Mutable holder for a min/max/steps tuple. `toList` realises it as
/// the concrete sweep array the [Optimizer] consumes.
class _SweepInputs {
  _SweepInputs({required this.min, required this.max, required this.steps});

  double min;
  double max;
  int steps;

  /// Generates `steps` evenly-spaced values in `[min, max]`. `steps == 1`
  /// returns `[min]`; an inverted range (`max < min`) collapses to `[min]`.
  List<double> toList() {
    if (steps <= 1) return [min];
    if (max <= min) return [min];
    final dx = (max - min) / (steps - 1);
    return List<double>.generate(steps, (i) => min + dx * i);
  }
}
