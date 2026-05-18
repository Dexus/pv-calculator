import 'package:flutter/material.dart';
import 'package:pv_engine/pv_engine.dart';

import '../../l10n/generated/app_localizations.dart';

/// Top-N candidate table for the Optimizer page. Rows = candidates,
/// columns = the swept parameters + investment + lifetime cost +
/// autarky + annual PV AC. Pure presentation; the controller has
/// already sorted and truncated the list.
///
/// Stable row keys (`Key('optimizer-row-N')`) let widget tests scrape
/// the table without depending on the rendered text.
class OptimizerResultsTable extends StatelessWidget {
  const OptimizerResultsTable({super.key, required this.candidates});

  final List<OptimizerCandidate> candidates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: theme.textTheme.titleSmall,
        columns: [
          DataColumn(label: Text('#'), numeric: true),
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
}
