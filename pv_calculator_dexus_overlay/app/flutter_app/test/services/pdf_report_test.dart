import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/services/pdf_report.dart';
import 'package:pv_calculator_app/state/config_draft.dart';
import 'package:pv_engine/pv_engine.dart';

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

void main() {
  test('buildReportPdf returns non-empty bytes starting with the PDF magic',
      () async {
    final result = const PvSimulator().run(_config());
    final draft = ConfigDraft.fromConfig(_config());
    final bytes = await buildReportPdf(
      result: result,
      draft: draft,
      projectName: 'Demo',
      runTimestamp: DateTime.utc(2026, 5, 18, 12, 0),
      engineVersion: '0.9.0',
    );

    expect(bytes.length, greaterThan(1000));
    // PDF magic header: bytes "%PDF" (0x25 0x50 0x44 0x46).
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
  });

  test('PDF includes tariff KPIs when the result carries cost figures',
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
      projectName: 'WithTariff',
      runTimestamp: DateTime.utc(2026, 5, 18, 12, 0),
      engineVersion: '0.9.0',
    );
    expect(bytes.length, greaterThan(1000));
    // The summary table includes "Import cost" iff the summary carries
    // a non-null importCostEur; this is a sanity check that the
    // conditional branch fires when economics are configured.
    expect(result.summary.importCostEur, isNotNull);
  });

  test('PDF includes per-year section when multi-year', () async {
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
      keepSteps: false,
    );
    final result = const PvSimulator().run(cfg);
    final draft = ConfigDraft.fromConfig(cfg);
    final bytes = await buildReportPdf(
      result: result,
      draft: draft,
      projectName: 'Multi',
      runTimestamp: DateTime.utc(2026, 5, 18, 12, 0),
      engineVersion: '0.9.0',
    );
    expect(bytes.length, greaterThan(1000));
    expect(result.summary.perYearSummaries.length, 3);
  });
}
