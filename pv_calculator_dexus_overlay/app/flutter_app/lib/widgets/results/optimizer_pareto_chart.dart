import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pv_engine/pv_engine.dart';

import '../../l10n/generated/app_localizations.dart';

/// Scatter view of the Optimizer sweep over (lifetime net cost × autarky),
/// with the Pareto frontier highlighted and connected by a line. Cloud
/// dots are the full evaluated candidate set; highlight dots come from
/// `OptimizerResult.paretoFrontier` (already sorted by cost ascending,
/// strictly increasing autarky).
///
/// Hidden by the caller when `paretoFrontier` is empty (i.e. no tariff).
class OptimizerParetoChart extends StatelessWidget {
  const OptimizerParetoChart({super.key, required this.result});

  final OptimizerResult result;

  static const Color _cloudColor = Color(0xFF90A4AE); // blueGrey.300
  static const Color _frontierColor = Color(0xFF1E88E5); // blue.600

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final frontier = result.paretoFrontier;
    if (frontier.isEmpty) return const SizedBox.shrink();
    // `result.candidates` is truncated to `OptimizerSpec.topN`, but
    // the frontier comes from the full pre-truncation set — so a
    // frontier point may not appear in `candidates` and would be
    // clipped from the bounds if we built `withCost` from candidates
    // alone. Union both, deduped by identity.
    final withCostSet = <OptimizerCandidate>{};
    for (final c in result.candidates) {
      if (c.lifetimeNetCostEur != null) withCostSet.add(c);
    }
    withCostSet.addAll(frontier);
    final withCost = withCostSet.toList();

    if (withCost.isEmpty) return const SizedBox.shrink();

    final bounds = _bounds(withCost);

    final cloudSpots = <ScatterSpot>[
      for (final c in withCost)
        ScatterSpot(
          c.lifetimeNetCostEur!,
          c.summary.autarkyRate * 100.0,
          dotPainter: FlDotCirclePainter(
            radius: 3,
            color: _cloudColor.withValues(alpha: 0.55),
            strokeWidth: 0,
          ),
        ),
    ];
    final frontierSpots = <ScatterSpot>[
      for (final c in frontier)
        ScatterSpot(
          c.lifetimeNetCostEur!,
          c.summary.autarkyRate * 100.0,
          dotPainter: FlDotCirclePainter(
            radius: 6,
            color: _frontierColor,
            strokeColor: Colors.white,
            strokeWidth: 1.5,
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(spacing: 12, runSpacing: 4, children: [
          _legendDot(context, _cloudColor.withValues(alpha: 0.8),
              l.optimizerParetoLegendCloud),
          _legendDot(context, _frontierColor, l.optimizerParetoLegendFrontier),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 260,
          // Both the LineChart (frontier connector) and the
          // ScatterChart (cloud + highlight dots) sit on top of each
          // other in this Stack. They must reserve identical space
          // for axis titles, otherwise their plot rectangles drift
          // apart for the same min/max bounds and the connecting
          // line no longer lines up with the dots. We render the
          // axis titles only on the ScatterChart, but the LineChart
          // uses the same reserved sizes with invisible content.
          child: Stack(children: [
            LineChart(
              LineChartData(
                minX: bounds.minX,
                maxX: bounds.maxX,
                minY: bounds.minY,
                maxY: bounds.maxY,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    axisNameWidget: SizedBox.shrink(),
                    axisNameSize: 18,
                    sideTitles: SideTitles(showTitles: false, reservedSize: 28),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: SizedBox.shrink(),
                    axisNameSize: 18,
                    sideTitles: SideTitles(showTitles: false, reservedSize: 40),
                  ),
                ),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: false,
                    color: _frontierColor.withValues(alpha: 0.6),
                    barWidth: 1.8,
                    dotData: const FlDotData(show: false),
                    spots: [
                      for (final c in frontier)
                        FlSpot(c.lifetimeNetCostEur!,
                            c.summary.autarkyRate * 100.0),
                    ],
                  ),
                ],
              ),
            ),
            ScatterChart(
              ScatterChartData(
                minX: bounds.minX,
                maxX: bounds.maxX,
                minY: bounds.minY,
                maxY: bounds.maxY,
                scatterSpots: [...cloudSpots, ...frontierSpots],
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    axisNameWidget: Text(l.optimizerParetoAxisCost,
                        style: Theme.of(context).textTheme.bodySmall),
                    axisNameSize: 18,
                    sideTitles: const SideTitles(
                        showTitles: true, reservedSize: 28),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: Text(l.optimizerParetoAxisAutarky,
                        style: Theme.of(context).textTheme.bodySmall),
                    axisNameSize: 18,
                    sideTitles: const SideTitles(
                        showTitles: true, reservedSize: 40),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }

  _Bounds _bounds(List<OptimizerCandidate> withCost) {
    var minCost = double.infinity;
    var maxCost = double.negativeInfinity;
    var minAut = double.infinity;
    var maxAut = double.negativeInfinity;
    for (final c in withCost) {
      final cost = c.lifetimeNetCostEur!;
      final aut = c.summary.autarkyRate * 100.0;
      if (cost < minCost) minCost = cost;
      if (cost > maxCost) maxCost = cost;
      if (aut < minAut) minAut = aut;
      if (aut > maxAut) maxAut = aut;
    }
    if (minCost == maxCost) {
      minCost -= 1;
      maxCost += 1;
    }
    if (minAut == maxAut) {
      minAut -= 1;
      maxAut += 1;
    }
    final padX = (maxCost - minCost) * 0.05;
    final padY = (maxAut - minAut) * 0.05;
    return _Bounds(
      minX: minCost - padX,
      maxX: maxCost + padX,
      minY: (minAut - padY).clamp(0.0, 100.0),
      maxY: (maxAut + padY).clamp(0.0, 100.0),
    );
  }
}

class _Bounds {
  const _Bounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
}
