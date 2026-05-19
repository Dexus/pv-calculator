import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/l10n/generated/app_localizations.dart';
import 'package:pv_calculator_app/widgets/results/per_year_monthly_section.dart';
import 'package:pv_engine/pv_engine.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  MonthlyBucket bucket(int month, double pvAc) => MonthlyBucket(
        month: month,
        pvAcKwh: pvAc,
        loadKwh: 0,
        selfConsumptionKwh: 0,
        batteryChargeKwh: 0,
        batteryDischargeKwh: 0,
        gridImportKwh: 0,
        gridExportKwh: 0,
        curtailedDcKwh: 0,
        curtailedAcKwh: 0,
        curtailedExportKwh: 0,
        importCostEur: 0,
        exportRevenueEur: 0,
      );

  List<List<MonthlyBucket>> fixture(int years) => [
        for (var y = 1; y <= years; y++)
          [for (var m = 1; m <= 12; m++) bucket(m, y * 100.0 + m)],
      ];

  testWidgets('renders year 1 by default and the picker lists every year',
      (tester) async {
    await tester.pumpWidget(
      wrap(PerYearMonthlySection(
        perYearMonthly: fixture(3),
        showCashflow: false,
      )),
    );
    await tester.pumpAndSettle();

    // Dropdown defaults to "Jahr 1" — the closed dropdown shows that text.
    expect(find.text('Jahr 1'), findsOneWidget);

    // The displayed `MonthlyTable` should carry the per-year key with
    // the current selection.
    expect(find.byKey(const ValueKey('per-year-monthly-table-1')),
        findsOneWidget);

    // The hidden options also include Jahr 2 / Jahr 3 in the dropdown
    // menu, but they are off-screen until we tap. Tap to open and
    // verify the menu populates years 1..3.
    await tester.tap(find.byKey(const Key('per-year-monthly-year-picker')));
    await tester.pumpAndSettle();
    expect(find.text('Jahr 1'), findsWidgets);
    expect(find.text('Jahr 2'), findsOneWidget);
    expect(find.text('Jahr 3'), findsOneWidget);
  });

  testWidgets('selecting year 2 swaps the rendered MonthlyTable',
      (tester) async {
    await tester.pumpWidget(
      wrap(PerYearMonthlySection(
        perYearMonthly: fixture(3),
        showCashflow: false,
      )),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('per-year-monthly-year-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jahr 2').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('per-year-monthly-table-2')),
        findsOneWidget);
    // Year 2 month 1 pvAc was set to 201.0 in the fixture; the
    // MonthlyTable formats pvAc as `toStringAsFixed(0)`, so the cell
    // reads "201". Year 1 month 1 would have rendered "101".
    expect(find.text('201'), findsWidgets);
    expect(find.text('101'), findsNothing);
  });

  testWidgets('clamps the selection when perYearMonthly shrinks',
      (tester) async {
    // Pump with 3 years, pick year 3, then rebuild with only 2 years
    // (e.g. user re-ran a shorter scenario). The selection must reset
    // so the widget never dereferences past the end of the list.
    var perYear = fixture(3);
    await tester.pumpWidget(
      wrap(PerYearMonthlySection(
        perYearMonthly: perYear,
        showCashflow: false,
      )),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('per-year-monthly-year-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jahr 3').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('per-year-monthly-table-3')),
        findsOneWidget);

    perYear = fixture(2);
    await tester.pumpWidget(
      wrap(PerYearMonthlySection(
        perYearMonthly: perYear,
        showCashflow: false,
      )),
    );
    await tester.pumpAndSettle();
    // After the rebuild the selection has been clamped back to year 1.
    expect(find.byKey(const ValueKey('per-year-monthly-table-1')),
        findsOneWidget);
  });
}
