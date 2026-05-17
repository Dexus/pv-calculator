import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../state/scenario_comparison_controller.dart';

/// Grouped bar chart for the Scenario-Compare page. One group per scenario,
/// one bar per KPI within the group. Same `fl_chart` primitives as
/// `bank_runtime_chart.dart`, kept deliberately small so the comparison
/// view stays readable when the number of scenarios scales past two.
class ScenarioCompareChart extends StatelessWidget {
  const ScenarioCompareChart({super.key, required this.entries});

  final List<ScenarioCompareEntry> entries;

  static const List<_Kpi> _kpis = [
    _Kpi('PV AC', Color(0xFFFFB300)),
    _Kpi('Eigenverbr.', Color(0xFF66BB6A)),
    _Kpi('Netzbezug', Color(0xFFE53935)),
    _Kpi('Einspeisung', Color(0xFF42A5F5)),
  ];

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < entries.length; i++) {
      final s = entries[i].summary;
      final values = <double>[
        s.pvAcKwh,
        s.selfConsumptionKwh,
        s.gridImportKwh,
        s.gridExportKwh,
      ];
      groups.add(BarChartGroupData(
        x: i,
        barsSpace: 4,
        barRods: [
          for (var k = 0; k < _kpis.length; k++)
            BarChartRodData(
              toY: values[k],
              width: 14,
              color: _kpis[k].color,
              borderRadius: BorderRadius.circular(2),
            ),
        ],
      ));
    }

    final maxY = _maxOfRods(groups);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final k in _kpis)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 12, height: 12, color: k.color),
                const SizedBox(width: 4),
                Text(k.label, style: Theme.of(context).textTheme.bodySmall),
              ]),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 240,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY * 1.1,
              barGroups: groups,
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          entries[idx].scenario.name,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                    reservedSize: 40,
                  ),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 48),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _maxOfRods(List<BarChartGroupData> groups) {
    var max = 0.0;
    for (final g in groups) {
      for (final r in g.barRods) {
        if (r.toY > max) max = r.toY;
      }
    }
    return max == 0 ? 1 : max;
  }
}

class _Kpi {
  const _Kpi(this.label, this.color);
  final String label;
  final Color color;
}
