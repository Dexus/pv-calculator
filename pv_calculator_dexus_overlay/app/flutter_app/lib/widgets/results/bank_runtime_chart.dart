import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pv_engine/pv_engine.dart';

import '../../l10n/generated/app_localizations.dart';

/// Phase 6: how long can the 24h output sustain itself across the year?
/// Renders one stacked bar per day showing how many hours the bank
/// actually delivered AC versus how many hours it was scheduled but
/// fell short (SOC shutdown, empty source battery, rate cap). Mirrors
/// the irradiance chart's "365 daily bars" layout so the two read the
/// same way side-by-side.
class BankRuntimeChart extends StatelessWidget {
  const BankRuntimeChart({
    super.key,
    required this.daily,
    required this.bankLabel,
    required this.stats,
  });

  /// 365 entries, dayOfYear 1..365. Comes from
  /// `SummaryAggregator.bankDaily`.
  final List<BankDayStats> daily;

  /// Aggregated stats across the same series — used for the headline
  /// "coverage" stat chip.
  final BankRuntimeStats stats;

  /// Caption above the chart, typically `bank.label` or `bank.id`.
  final String bankLabel;

  // Three-segment stack so a step that *partially* delivers AC is
  // visually distinct from a step that delivered the full schedule:
  // green = fully sustained, orange = partial (some AC, below target),
  // red = scheduled but zero. Without the orange middle, a rate-capped
  // bank that ekes out a fraction of the target every hour would look
  // 100 % covered on the chart despite a non-zero `shortfallKwh`.
  static const Color _fullColor = Color(0xFF66BB6A); // green.400
  static const Color _partialColor = Color(0xFFFFA726); // orange.400
  static const Color _shortfallColor = Color(0xFFEF5350); // red.400

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final groups = <BarChartGroupData>[
      for (var d = 0; d < daily.length; d++)
        BarChartGroupData(
          x: d,
          barRods: [
            BarChartRodData(
              toY: daily[d].scheduledHours,
              width: 1.6,
              borderRadius: BorderRadius.zero,
              rodStackItems: [
                BarChartRodStackItem(
                  0,
                  daily[d].fullDeliveryHours,
                  _fullColor.withValues(alpha: 0.9),
                ),
                BarChartRodStackItem(
                  daily[d].fullDeliveryHours,
                  daily[d].activeHours,
                  _partialColor.withValues(alpha: 0.9),
                ),
                BarChartRodStackItem(
                  daily[d].activeHours,
                  daily[d].scheduledHours,
                  _shortfallColor.withValues(alpha: 0.85),
                ),
              ],
            ),
          ],
        ),
    ];

    final coveragePct = (stats.coverageRate * 100).clamp(0.0, 100.0);
    final avgDailyActive = stats.activeHours / 365.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.power, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(bankLabel, style: Theme.of(context).textTheme.titleMedium),
          ),
        ]),
        const SizedBox(height: 4),
        Wrap(spacing: 16, runSpacing: 4, children: [
          _LegendSwatch(color: _fullColor, label: l.bankRuntimeLegendFull),
          _LegendSwatch(color: _partialColor, label: l.bankRuntimeLegendPartial),
          _LegendSwatch(color: _shortfallColor, label: l.bankRuntimeLegendShortfall),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _StatChip(label: l.bankRuntimeStatCoverage(coveragePct.toStringAsFixed(1))),
          _StatChip(label: l.bankRuntimeStatAvgHours(avgDailyActive.toStringAsFixed(1))),
          _StatChip(label: l.bankRuntimeStatDelivered(stats.deliveredKwh.toStringAsFixed(0))),
          _StatChip(label: l.bankRuntimeStatShortfall(stats.shortfallKwh.toStringAsFixed(0))),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: RepaintBoundary(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceBetween,
                groupsSpace: 0,
                maxY: 24,
                minY: 0,
                gridData: const FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 6,
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 6,
                      getTitlesWidget: (value, _) => Text(
                        value.toInt().toString(),
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

  /// Same first-of-month tick scheme as the irradiance chart. Twelve
  /// labels instead of 365 keeps the axis legible.
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
