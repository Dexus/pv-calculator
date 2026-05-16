import 'package:flutter/material.dart';
import 'package:pv_engine/pv_engine.dart';

class MonthlyTable extends StatelessWidget {
  const MonthlyTable({super.key, required this.buckets});

  final List<MonthlyBucket> buckets;

  static const _monthNames = [
    'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
    'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Monat')),
          DataColumn(label: Text('PV AC (kWh)'), numeric: true),
          DataColumn(label: Text('Last (kWh)'), numeric: true),
          DataColumn(label: Text('EV (kWh)'), numeric: true),
          DataColumn(label: Text('Bat-Lad. (kWh)'), numeric: true),
          DataColumn(label: Text('Bat-Entl. (kWh)'), numeric: true),
          DataColumn(label: Text('Import (kWh)'), numeric: true),
          DataColumn(label: Text('Export (kWh)'), numeric: true),
        ],
        rows: [
          for (final b in buckets)
            DataRow(cells: [
              DataCell(Text(_monthNames[b.month - 1])),
              DataCell(Text(b.pvAcKwh.toStringAsFixed(0))),
              DataCell(Text(b.loadKwh.toStringAsFixed(0))),
              DataCell(Text(b.selfConsumptionKwh.toStringAsFixed(0))),
              DataCell(Text(b.batteryChargeKwh.toStringAsFixed(0))),
              DataCell(Text(b.batteryDischargeKwh.toStringAsFixed(0))),
              DataCell(Text(b.gridImportKwh.toStringAsFixed(0))),
              DataCell(Text(b.gridExportKwh.toStringAsFixed(0))),
            ]),
        ],
      ),
    );
  }
}
