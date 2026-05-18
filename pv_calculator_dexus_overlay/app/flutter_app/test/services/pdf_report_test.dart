import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/l10n/generated/app_localizations.dart';
import 'package:pv_calculator_app/l10n/generated/app_localizations_en.dart';
import 'package:pv_calculator_app/services/pdf_report.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_engine/pv_engine.dart';

final AppLocalizations _l = AppLocalizationsEn();

SimulationConfig _config({int days = 7}) {
  return SimulationConfig(
    arrays: const [
      PvArray(
        id: 'roof',
        label: 'South roof',
        peakKw: 4.0,
        azimuthDeg: 180,
        tiltDeg: 30,
        inverterId: 'main',
      ),
    ],
    inverters: const [Inverter(id: 'main', label: 'Main', maxAcKw: 4.0)],
    loadProfile: const LoadProfile(dailyKwh: 8.0),
    days: days,
  );
}

/// Extracts the visible text the PDF would render. The `pdf` package
/// splits text into multiple PDF "text-show" operations — each operand
/// of the form `(literal)` — separated by positioning, font and BT/ET
/// markers. A single phrase like "Per-year breakdown" becomes two
/// adjacent literals `(Per-year)` `(breakdown)` in the byte stream, so
/// a naive `bytes.contains('Per-year breakdown')` fails even when the
/// label *is* in the document.
///
/// This helper joins all literal operands with a single space and
/// unescapes `\(` / `\)` so multi-word labels containing parentheses
/// (e.g. "Monthly (final year only)") can be matched with their
/// natural rendered form. Compression must be disabled on the
/// document (`buildReportPdf(compress: false)`) for the literals to
/// be visible in the raw bytes.
String _pdfVisibleText(List<int> bytes) {
  final raw = latin1.decode(bytes, allowInvalid: true);
  // Match `(...)` PDF literal strings, honouring escaped parens.
  final re = RegExp(r'\(((?:[^()\\]|\\.)*)\)');
  return re
      .allMatches(raw)
      .map((m) => (m.group(1) ?? '')
          .replaceAll(r'\(', '(')
          .replaceAll(r'\)', ')'))
      .join(' ');
}

void main() {
  test('buildReportPdf returns non-empty bytes starting with the PDF magic',
      () async {
    final result = const PvSimulator().run(_config());
    final draft = ConfigDraft.fromConfig(_config());
    final bytes = await buildReportPdf(
      result: result,
      draft: draft,
      l: _l,
      projectName: 'Demo',
      runTimestamp: DateTime.utc(2026, 5, 18, 12, 0),
      engineVersion: '0.9.0',
    );

    expect(bytes.length, greaterThan(1000));
    // PDF magic header: bytes "%PDF" (0x25 0x50 0x44 0x46).
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
  });

  test('PDF renders tariff KPI rows when the run was configured with a tariff',
      () async {
    final cfg = SimulationConfig(
      arrays: _config().arrays,
      inverters: _config().inverters,
      loadProfile: _config().loadProfile,
      days: 1,
      tariff: const TariffConfig(
        importPricePerKwh: 0.30,
        exportPricePerKwh: 0.08,
      ),
    );
    final result = const PvSimulator().run(cfg);
    final draft = ConfigDraft.fromConfig(cfg);
    final bytes = await buildReportPdf(
      result: result,
      draft: draft,
      l: _l,
      projectName: 'WithTariff',
      runTimestamp: DateTime.utc(2026, 5, 18, 12, 0),
      engineVersion: '0.9.0',
      compress: false,
    );
    // Sanity: economics actually fired.
    expect(result.summary.importCostEur, isNotNull);

    // Inspect uncompressed PDF text streams for the tariff section
    // labels — guards against a regression that omits the
    // `if (s.importCostEur != null)` branch in _summaryTable.
    final text = _pdfVisibleText(bytes);
    expect(text, contains('Import cost'));
    expect(text, contains('Export revenue'));
    expect(text, contains('Net electricity cost'));
  });

  test('PDF without tariff omits the tariff KPI rows', () async {
    final result = const PvSimulator().run(_config());
    final draft = ConfigDraft.fromConfig(_config());
    final bytes = await buildReportPdf(
      result: result,
      draft: draft,
      l: _l,
      projectName: 'NoTariff',
      runTimestamp: DateTime.utc(2026, 5, 18, 12, 0),
      engineVersion: '0.9.0',
      compress: false,
    );
    final text = _pdfVisibleText(bytes);
    expect(text, isNot(contains('Import cost')));
    expect(text, isNot(contains('Net electricity cost')));
  });

  test('PDF includes per-year section header for multi-year runs', () async {
    final cfg = SimulationConfig(
      arrays: const [
        PvArray(
          id: 'roof',
          label: 'Roof',
          peakKw: 4.0,
          azimuthDeg: 180,
          tiltDeg: 30,
          inverterId: 'main',
          degradationPctPerYear: 0.5,
        ),
      ],
      inverters: const [Inverter(id: 'main', label: 'Main', maxAcKw: 4.0)],
      loadProfile: const LoadProfile(dailyKwh: 8.0),
      days: 365,
      simulationYears: 3,
      keepSteps: true,
    );
    final result = const PvSimulator().run(cfg);
    final draft = ConfigDraft.fromConfig(cfg);
    final bytes = await buildReportPdf(
      result: result,
      draft: draft,
      l: _l,
      projectName: 'Multi',
      runTimestamp: DateTime.utc(2026, 5, 18, 12, 0),
      engineVersion: '0.9.0',
      compress: false,
    );
    expect(result.summary.perYearSummaries.length, 3);
    final text = _pdfVisibleText(bytes);
    // The "Per-year breakdown" section is only emitted when
    // perYearSummaries.length >= 2; assert the literal section title.
    expect(text, contains('Per-year breakdown'));
    // Multi-year runs label the monthly section to flag that the
    // table covers only the final year.
    expect(text, contains('Monthly (final year only)'));
  });

  test('single-year PDF labels monthly section without the final-year caveat',
      () async {
    final result = const PvSimulator().run(_config());
    final draft = ConfigDraft.fromConfig(_config());
    final bytes = await buildReportPdf(
      result: result,
      draft: draft,
      l: _l,
      projectName: 'Single',
      runTimestamp: DateTime.utc(2026, 5, 18, 12, 0),
      engineVersion: '0.9.0',
      compress: false,
    );
    final text = _pdfVisibleText(bytes);
    expect(text, contains('Monthly'));
    expect(text, isNot(contains('Monthly (final year only)')));
    expect(text, isNot(contains('Per-year breakdown')));
  });

  test('PDF renders the monthly cashflow section when a tariff is configured',
      () async {
    final cfg = SimulationConfig(
      arrays: _config().arrays,
      inverters: _config().inverters,
      loadProfile: _config().loadProfile,
      days: 30,
      tariff: const TariffConfig(
        importPricePerKwh: 0.30,
        exportPricePerKwh: 0.08,
      ),
    );
    final result = const PvSimulator().run(cfg);
    final draft = ConfigDraft.fromConfig(cfg);
    final bytes = await buildReportPdf(
      result: result,
      draft: draft,
      l: _l,
      projectName: 'CashflowMonthly',
      runTimestamp: DateTime.utc(2026, 5, 18, 12, 0),
      engineVersion: '0.11.0',
      compress: false,
    );
    final text = _pdfVisibleText(bytes);
    expect(text, contains('Monthly cashflow'));
  });

  test('PDF without tariff omits the monthly cashflow section', () async {
    final result = const PvSimulator().run(_config());
    final draft = ConfigDraft.fromConfig(_config());
    final bytes = await buildReportPdf(
      result: result,
      draft: draft,
      l: _l,
      projectName: 'NoCashflow',
      runTimestamp: DateTime.utc(2026, 5, 18, 12, 0),
      engineVersion: '0.11.0',
      compress: false,
    );
    final text = _pdfVisibleText(bytes);
    expect(text, isNot(contains('Monthly cashflow')));
  });

  test('PDF prints the engine version and project name', () async {
    final result = const PvSimulator().run(_config());
    final draft = ConfigDraft.fromConfig(_config());
    final bytes = await buildReportPdf(
      result: result,
      draft: draft,
      l: _l,
      projectName: 'AcceptanceProject',
      runTimestamp: DateTime.utc(2026, 5, 18, 12, 0),
      engineVersion: '0.9.0-abc',
      compress: false,
    );
    final text = _pdfVisibleText(bytes);
    expect(text, contains('AcceptanceProject'));
    expect(text, contains('0.9.0-abc'));
  });
}
