import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pv_engine/pv_engine.dart';

import '../l10n/generated/app_localizations.dart';

/// Stacked daily bar chart for one year of horizontal irradiance.
///
/// 365 bars; each shows the day's peak hour — total height is the maximum
/// hourly GHI of that day, and the diffuse segment is DHI at that same
/// hour (so DHI ≤ GHI by construction and the stack reflects one
/// instant rather than two independent maxima). Values are kW/m². Hover/
/// tap tooltips are disabled on web because `fl_chart`'s hit-testing
/// struggles at 365 bars under CanvasKit.
class IrradianceChart extends StatelessWidget {
  const IrradianceChart({super.key, required this.series});

  static const Color _totalColor = Color(0xFFFFCA28); // Colors.amber.shade400
  static const Color _diffuseColor = Color(0xFF42A5F5); // Colors.blue.shade400

  final HorizontalIrradianceSeries series;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    final daily = _dailyPeak(series.samples);
    final dailyTotal = daily.total;
    final dailyDiffuse = daily.diffuse;

    final groups = <BarChartGroupData>[
      for (var d = 0; d < dailyTotal.length; d++)
        BarChartGroupData(
          x: d,
          barRods: [
            BarChartRodData(
              toY: dailyTotal[d] / 1000.0,
              width: 1.6,
              borderRadius: BorderRadius.zero,
              rodStackItems: [
                BarChartRodStackItem(
                  0,
                  dailyDiffuse[d] / 1000.0,
                  _diffuseColor.withValues(alpha: 0.85),
                ),
                BarChartRodStackItem(
                  dailyDiffuse[d] / 1000.0,
                  dailyTotal[d] / 1000.0,
                  _totalColor.withValues(alpha: 0.9),
                ),
              ],
            ),
          ],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('☀️ ', style: TextStyle(fontSize: 18)),
            Text(l.irradianceChartTitle,
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _LegendSwatch(color: _totalColor, label: l.irradianceSeriesTotal),
            const SizedBox(width: 16),
            _LegendSwatch(color: _diffuseColor, label: l.irradianceSeriesDiffuse),
            const Spacer(),
            Text('${series.year}', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _StatChip(
              label: l.irradianceAnnualSum(
                series.annualGlobalKWhPerM2.toStringAsFixed(0),
              ),
            ),
            const Spacer(),
            _StatChip(
              label: l.irradianceAverage(
                series.meanGlobalWPerM2.toStringAsFixed(0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: RepaintBoundary(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceBetween,
                groupsSpace: 0,
                maxY: 1.25,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 0.25,
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 0.25,
                      getTitlesWidget: (value, _) => Text(
                        value.toStringAsFixed(2),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, _) {
                        final day = value.toInt() + 1;
                        final label = _monthAbbrevForDay(l, day);
                        return label == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  label,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(enabled: !kIsWeb),
                barGroups: groups,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// For each day finds the hour with maximum GHI and returns that hour's
  /// GHI and DHI as a paired (total, diffuse) tuple. Both lists are in
  /// W/m² (divide by 1000 in the caller for kW/m²). Pairing diffuse to
  /// the same instant as the GHI peak keeps the stacked bar consistent:
  /// the diffuse segment is always ≤ the total segment.
  static ({List<double> total, List<double> diffuse}) _dailyPeak(
    List<HorizontalIrradianceSample> samples,
  ) {
    final total = List<double>.filled(365, 0);
    final diffuse = List<double>.filled(365, 0);
    for (var d = 0; d < 365; d++) {
      var peakGhi = -1.0;
      var peakDhi = 0.0;
      for (var h = 0; h < 24; h++) {
        final s = samples[d * 24 + h];
        if (s.globalHorizontalWPerM2 > peakGhi) {
          peakGhi = s.globalHorizontalWPerM2;
          peakDhi = s.diffuseHorizontalWPerM2;
        }
      }
      total[d] = peakGhi < 0 ? 0 : peakGhi;
      diffuse[d] = peakDhi;
    }
    return (total: total, diffuse: diffuse);
  }

  /// Returns the localized month abbreviation when `dayOfYear` is the
  /// 1st of a month, else null. Used to render only twelve x-axis ticks
  /// instead of 365.
  static String? _monthAbbrevForDay(AppLocalizations l, int doy) {
    const firsts = {
      1: 1, 32: 2, 60: 3, 91: 4, 121: 5, 152: 6,
      182: 7, 213: 8, 244: 9, 274: 10, 305: 11, 335: 12,
    };
    final month = firsts[doy];
    if (month == null) return null;
    return switch (month) {
      1 => l.monthJan,
      2 => l.monthFeb,
      3 => l.monthMar,
      4 => l.monthApr,
      5 => l.monthMay,
      6 => l.monthJun,
      7 => l.monthJul,
      8 => l.monthAug,
      9 => l.monthSep,
      10 => l.monthOct,
      11 => l.monthNov,
      12 => l.monthDec,
      _ => null,
    };
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
    ]);
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
