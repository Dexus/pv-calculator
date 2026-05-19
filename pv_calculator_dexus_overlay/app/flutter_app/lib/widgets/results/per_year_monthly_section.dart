import 'package:flutter/material.dart';
import 'package:pv_engine/pv_engine.dart';

import '../../l10n/generated/app_localizations.dart';
import 'monthly_table.dart';

/// Per-year monthly breakdown for multi-year runs. A dropdown picks
/// which year's 12 [MonthlyBucket]s render in the existing
/// [MonthlyTable]. Visible only when `summary.perYearMonthly` is
/// populated (engine 0.17.0+; `simulationYears > 1`).
class PerYearMonthlySection extends StatefulWidget {
  const PerYearMonthlySection({
    super.key,
    required this.perYearMonthly,
    required this.showCashflow,
  });

  final List<List<MonthlyBucket>> perYearMonthly;
  final bool showCashflow;

  @override
  State<PerYearMonthlySection> createState() => _PerYearMonthlySectionState();
}

class _PerYearMonthlySectionState extends State<PerYearMonthlySection> {
  int _selectedYear = 1;

  @override
  void didUpdateWidget(covariant PerYearMonthlySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new run may shorten the list; clamp the selection so the
    // dropdown never points past the end of `perYearMonthly`.
    if (_selectedYear > widget.perYearMonthly.length) {
      _selectedYear = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final years = widget.perYearMonthly.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                Text(l.perYearMonthlyYearPickerLabel),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  key: const Key('per-year-monthly-year-picker'),
                  value: _selectedYear,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedYear = v);
                  },
                  items: [
                    for (var y = 1; y <= years; y++)
                      DropdownMenuItem<int>(
                        value: y,
                        child: Text(l.perYearMonthlyYearLabel(y)),
                      ),
                  ],
                ),
              ]),
            ),
            MonthlyTable(
              key: ValueKey('per-year-monthly-table-$_selectedYear'),
              buckets: widget.perYearMonthly[_selectedYear - 1],
              showCashflow: widget.showCashflow,
            ),
          ],
        ),
      ),
    );
  }
}
