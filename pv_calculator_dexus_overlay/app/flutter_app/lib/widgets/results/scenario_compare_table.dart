import 'package:flutter/material.dart';

import '../../state/scenario_comparison_controller.dart';

/// Side-by-side KPI table for the Scenario-Compare page. Rows = scenarios,
/// columns = the KPI surface used elsewhere in the app (`pvAcKwh`,
/// `selfConsumptionRate`, `autarkyRate`, `gridImportKwh`, `gridExportKwh`,
/// `microInverterDeliveredKwh`, `curtailedAcKwh`). Pure presentation —
/// the controller has already resolved the summaries.
class ScenarioCompareTable extends StatelessWidget {
  const ScenarioCompareTable({super.key, required this.entries});

  final List<ScenarioCompareEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: theme.textTheme.titleSmall,
        columns: const [
          DataColumn(label: Text('Szenario')),
          DataColumn(label: Text('PV AC (kWh)'), numeric: true),
          DataColumn(label: Text('Eigenverbrauch %'), numeric: true),
          DataColumn(label: Text('Autarkie %'), numeric: true),
          DataColumn(label: Text('Netzbezug (kWh)'), numeric: true),
          DataColumn(label: Text('Einspeisung (kWh)'), numeric: true),
          DataColumn(label: Text('Mikro-WR (kWh)'), numeric: true),
          DataColumn(label: Text('Abregelung AC (kWh)'), numeric: true),
          DataColumn(label: Text('Quelle')),
        ],
        rows: [
          for (final e in entries)
            DataRow(cells: [
              DataCell(Text(e.scenario.name)),
              DataCell(Text(e.summary.pvAcKwh.toStringAsFixed(0))),
              DataCell(Text('${(e.summary.selfConsumptionRate * 100).toStringAsFixed(1)} %')),
              DataCell(Text('${(e.summary.autarkyRate * 100).toStringAsFixed(1)} %')),
              DataCell(Text(e.summary.gridImportKwh.toStringAsFixed(0))),
              DataCell(Text(e.summary.gridExportKwh.toStringAsFixed(0))),
              DataCell(Text(e.summary.microInverterDeliveredKwh.toStringAsFixed(0))),
              DataCell(Text(e.summary.curtailedAcKwh.toStringAsFixed(0))),
              DataCell(Text(e.fromCache ? 'Cache' : 'Neu')),
            ]),
        ],
      ),
    );
  }
}
