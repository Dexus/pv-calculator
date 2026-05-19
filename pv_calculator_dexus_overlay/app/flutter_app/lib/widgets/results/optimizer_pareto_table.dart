import 'package:flutter/material.dart';
import 'package:pv_engine/pv_engine.dart';

import '../../l10n/generated/app_localizations.dart';

/// Compact list of the Pareto-optimal candidates. Rows match the chart
/// dots and are ordered by lifetime cost ascending (same order the
/// engine emits). Five columns keep it readable next to the wider
/// `OptimizerResultsTable`.
class OptimizerParetoTable extends StatelessWidget {
  const OptimizerParetoTable({super.key, required this.candidates});

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
          DataColumn(label: Text(l.optimizerColBattery), numeric: true),
          DataColumn(label: Text(l.optimizerColInverter), numeric: true),
          DataColumn(label: Text(l.optimizerColPvScale), numeric: true),
          DataColumn(label: Text(l.optimizerColLifetimeCost), numeric: true),
          DataColumn(label: Text(l.optimizerColAutarky), numeric: true),
        ],
        rows: [
          for (var i = 0; i < candidates.length; i++)
            DataRow(
              key: ValueKey('optimizer-pareto-row-$i'),
              cells: [
                DataCell(Text(candidates[i].batteryKwh.toStringAsFixed(1))),
                DataCell(Text(candidates[i].inverterKw.toStringAsFixed(1))),
                DataCell(Text(candidates[i].pvScale.toStringAsFixed(2))),
                DataCell(Text(
                  candidates[i].lifetimeNetCostEur == null
                      ? '—'
                      : candidates[i].lifetimeNetCostEur!.toStringAsFixed(0),
                )),
                DataCell(Text(
                    '${(candidates[i].summary.autarkyRate * 100).toStringAsFixed(1)} %')),
              ],
            ),
        ],
      ),
    );
  }
}
