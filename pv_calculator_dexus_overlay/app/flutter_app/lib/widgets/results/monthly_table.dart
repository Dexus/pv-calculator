import 'package:flutter/material.dart';
import 'package:pv_engine/pv_engine.dart';

import '../../l10n/generated/app_localizations.dart';

class MonthlyTable extends StatelessWidget {
  const MonthlyTable({
    super.key,
    required this.buckets,
    this.showCashflow = false,
  });

  final List<MonthlyBucket> buckets;

  /// Show the three trailing €-columns (import cost, export revenue,
  /// net cost). Caller passes `summary.importCostEur != null` so the
  /// columns appear exactly when a tariff was configured for the run.
  final bool showCashflow;

  static List<String> _monthNames(AppLocalizations l) => [
        l.monthJan, l.monthFeb, l.monthMar, l.monthApr, l.monthMay, l.monthJun,
        l.monthJul, l.monthAug, l.monthSep, l.monthOct, l.monthNov, l.monthDec,
      ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final monthNames = _monthNames(l);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(l.monthlyColMonth)),
          DataColumn(label: Text(l.monthlyColPvAc), numeric: true),
          DataColumn(label: Text(l.monthlyColLoad), numeric: true),
          DataColumn(label: Text(l.monthlyColSelfConsumption), numeric: true),
          DataColumn(label: Text(l.monthlyColBatteryCharge), numeric: true),
          DataColumn(label: Text(l.monthlyColBatteryDischarge), numeric: true),
          DataColumn(label: Text(l.monthlyColImport), numeric: true),
          DataColumn(label: Text(l.monthlyColExport), numeric: true),
          if (showCashflow) ...[
            DataColumn(label: Text(l.monthlyColImportCost), numeric: true),
            DataColumn(label: Text(l.monthlyColExportRevenue), numeric: true),
            DataColumn(label: Text(l.monthlyColNetCost), numeric: true),
          ],
        ],
        rows: [
          for (final b in buckets)
            DataRow(cells: [
              DataCell(Text(monthNames[b.month - 1])),
              DataCell(Text(b.pvAcKwh.toStringAsFixed(0))),
              DataCell(Text(b.loadKwh.toStringAsFixed(0))),
              DataCell(Text(b.selfConsumptionKwh.toStringAsFixed(0))),
              DataCell(Text(b.batteryChargeKwh.toStringAsFixed(0))),
              DataCell(Text(b.batteryDischargeKwh.toStringAsFixed(0))),
              DataCell(Text(b.gridImportKwh.toStringAsFixed(0))),
              DataCell(Text(b.gridExportKwh.toStringAsFixed(0))),
              if (showCashflow) ...[
                DataCell(Text('${b.importCostEur.toStringAsFixed(2)} €')),
                DataCell(Text('${b.exportRevenueEur.toStringAsFixed(2)} €')),
                DataCell(Text('${b.netCostEur.toStringAsFixed(2)} €')),
              ],
            ]),
        ],
      ),
    );
  }
}
