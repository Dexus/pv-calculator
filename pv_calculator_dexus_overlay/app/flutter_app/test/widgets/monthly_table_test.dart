import 'package:flutter/material.dart';
import 'package:pv_calculator_app/l10n/generated/app_localizations.dart';
import 'package:pv_calculator_app/widgets/results/monthly_table.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pv_engine/pv_engine.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(body: child),
      );

  MonthlyBucket sample(int m, {double imp = 0, double exp = 0}) =>
      MonthlyBucket(
        month: m,
        pvAcKwh: 0,
        loadKwh: 0,
        selfConsumptionKwh: 0,
        batteryChargeKwh: 0,
        batteryDischargeKwh: 0,
        gridImportKwh: 0,
        gridExportKwh: 0,
        curtailedDcKwh: 0,
        curtailedAcKwh: 0,
        curtailedExportKwh: 0,
        importCostEur: imp,
        exportRevenueEur: exp,
      );

  testWidgets('hides cashflow columns when showCashflow is false',
      (tester) async {
    final rows = [for (var i = 1; i <= 12; i++) sample(i)];
    await tester.pumpWidget(wrap(MonthlyTable(buckets: rows)));
    await tester.pumpAndSettle();

    expect(find.text('Bezugskosten (€)'), findsNothing);
    expect(find.text('Einspeise-Erlös (€)'), findsNothing);
    expect(find.text('Netto (€)'), findsNothing);
  });

  testWidgets('shows cashflow columns when showCashflow is true',
      (tester) async {
    final rows = [for (var i = 1; i <= 12; i++) sample(i, imp: 5.0, exp: 1.0)];
    await tester.pumpWidget(
      wrap(MonthlyTable(buckets: rows, showCashflow: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bezugskosten (€)'), findsOneWidget);
    expect(find.text('Einspeise-Erlös (€)'), findsOneWidget);
    expect(find.text('Netto (€)'), findsOneWidget);
    // 5.00 € appears at least once as the import-cost cell.
    expect(find.text('5.00 €'), findsWidgets);
    // Net = 5 - 1 = 4.00 €.
    expect(find.text('4.00 €'), findsWidgets);
  });
}
