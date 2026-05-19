import 'package:flutter/material.dart';
import 'package:pv_engine/pv_engine.dart';

import '../../l10n/generated/app_localizations.dart';

/// Top-N candidate table for the Optimizer page. Rows = candidates,
/// columns = the swept parameters + investment + lifetime cost +
/// autarky + annual PV AC. Pure presentation; the controller has
/// already sorted and truncated the list.
///
/// When [paretoFrontier] is non-empty, a leading `Pareto` column is
/// rendered. Rows whose [OptimizerCandidate] instance is identity-equal
/// to a member of the frontier are marked with a star icon; all others
/// get an em dash. Membership uses `identical()` because
/// `OptimizerResult.paretoFrontier` reuses the same Dart objects that
/// appear in `candidates` (see `Optimizer.run` / `Optimizer._computePareto`).
///
/// Stable row keys (`Key('optimizer-row-N')`) and marker keys
/// (`Key('optimizer-pareto-marker-N')`) let widget tests scrape the
/// table without depending on the rendered text.
class OptimizerResultsTable extends StatelessWidget {
  const OptimizerResultsTable({
    super.key,
    required this.candidates,
    this.paretoFrontier = const <OptimizerCandidate>[],
  });

  final List<OptimizerCandidate> candidates;
  final List<OptimizerCandidate> paretoFrontier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final showPareto = paretoFrontier.isNotEmpty;
    // Identity-hash lookup keeps the per-row check O(1). All candidate
    // objects originate from the same sweep, so identity is sufficient.
    final paretoIds = showPareto
        ? {for (final c in paretoFrontier) identityHashCode(c)}
        : const <int>{};
    bool isPareto(OptimizerCandidate c) =>
        paretoIds.contains(identityHashCode(c));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: theme.textTheme.titleSmall,
        columns: [
          DataColumn(label: Text('#'), numeric: true),
          if (showPareto) DataColumn(label: Text(l.optimizerColPareto)),
          DataColumn(label: Text(l.optimizerColBattery), numeric: true),
          DataColumn(label: Text(l.optimizerColInverter), numeric: true),
          DataColumn(label: Text(l.optimizerColPvScale), numeric: true),
          DataColumn(label: Text(l.optimizerColDisabled)),
          DataColumn(label: Text(l.optimizerColInvestment), numeric: true),
          DataColumn(label: Text(l.optimizerColLifetimeCost), numeric: true),
          DataColumn(label: Text(l.optimizerColAutarky), numeric: true),
          DataColumn(label: Text(l.optimizerColPvAcKwh), numeric: true),
        ],
        rows: [
          for (var i = 0; i < candidates.length; i++)
            DataRow(
              key: ValueKey('optimizer-row-$i'),
              cells: [
                DataCell(Text('${i + 1}')),
                if (showPareto)
                  DataCell(_paretoMarker(
                    context,
                    isOnFrontier: isPareto(candidates[i]),
                    index: i,
                  )),
                DataCell(Text(candidates[i].batteryKwh.toStringAsFixed(1))),
                DataCell(Text(candidates[i].inverterKw.toStringAsFixed(1))),
                DataCell(Text(candidates[i].pvScale.toStringAsFixed(2))),
                DataCell(Text(
                  candidates[i].disabledArrayIds.isEmpty
                      ? '—'
                      : (candidates[i].disabledArrayIds.toList()..sort()).join(', '),
                )),
                DataCell(Text(candidates[i].investmentEur.toStringAsFixed(0))),
                DataCell(Text(
                  candidates[i].lifetimeNetCostEur == null
                      ? '—'
                      : candidates[i].lifetimeNetCostEur!.toStringAsFixed(0),
                )),
                DataCell(Text('${(candidates[i].summary.autarkyRate * 100).toStringAsFixed(1)} %')),
                DataCell(Text(candidates[i].summary.pvAcKwh.toStringAsFixed(0))),
              ],
            ),
        ],
      ),
    );
  }

  Widget _paretoMarker(
    BuildContext context, {
    required bool isOnFrontier,
    required int index,
  }) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final key = ValueKey('optimizer-pareto-marker-$index');
    if (isOnFrontier) {
      return Tooltip(
        message: l.optimizerColParetoTooltipOn,
        child: Icon(
          Icons.star,
          key: key,
          color: theme.colorScheme.primary,
          semanticLabel: l.optimizerColParetoTooltipOn,
          size: 18,
        ),
      );
    }
    return Tooltip(
      message: l.optimizerColParetoTooltipOff,
      child: Text('—', key: key, semanticsLabel: l.optimizerColParetoTooltipOff),
    );
  }
}
