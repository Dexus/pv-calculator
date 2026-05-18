import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

/// A small, deterministic config used as the baseline for the
/// multi-year tests. Uses the synthetic irradiance model so the tests
/// don't depend on PVGIS data.
SimulationConfig _baseConfig({
  int years = 1,
  double degradationPct = 0.0,
  bool keepSteps = false,
  int preRunDays = 0,
  PreRunMode preRunMode = PreRunMode.manual,
}) {
  return SimulationConfig(
    arrays: [
      PvArray(
        id: 'roof',
        label: 'Roof',
        peakKw: 5.0,
        azimuthDeg: 180,
        tiltDeg: 30,
        inverterId: 'main',
        degradationPctPerYear: degradationPct,
      ),
    ],
    inverters: const [Inverter(id: 'main', label: 'Main', maxAcKw: 5.0)],
    batteries: const [
      BatteryConfig(
        id: 'b',
        capacityKwh: 5.0,
        maxChargeKw: 2.5,
        maxDischargeKw: 2.5,
        minSocKwh: 0.5,
        initialSocKwh: 2.5,
      ),
    ],
    loadProfile: const LoadProfile(dailyKwh: 10.0),
    days: 365,
    simulationYears: years,
    keepSteps: keepSteps,
    preRunDays: preRunDays,
    preRunMode: preRunMode,
  );
}

void main() {
  group('multi-year simulation', () {
    test('single-year run is unchanged when simulationYears == 1', () {
      final single = _baseConfig(years: 1, keepSteps: true);
      final multi = _baseConfig(years: 1, keepSteps: true);
      final a = const PvSimulator().run(single);
      final b = const PvSimulator().run(multi);
      expect(b.summary.pvAcKwh, closeTo(a.summary.pvAcKwh, 1e-9));
      expect(b.summary.gridImportKwh, closeTo(a.summary.gridImportKwh, 1e-9));
      expect(b.summary.perYearSummaries, isEmpty);
      expect(b.steps.length, a.steps.length);
    });

    test('per-year summary count equals simulationYears', () {
      final cfg = _baseConfig(years: 4);
      final result = const PvSimulator().run(cfg);
      expect(result.summary.perYearSummaries, hasLength(4));
    });

    test('degradation linearity: year y pvAcKwh ≈ year 0 × (1-d)^y', () {
      final cfg = _baseConfig(years: 5, degradationPct: 1.0);
      final result = const PvSimulator().run(cfg);
      final y0 = result.summary.perYearSummaries[0].pvAcKwh;
      for (var y = 1; y < 5; y++) {
        final expected = y0 * _pow(1 - 0.01, y);
        final actual = result.summary.perYearSummaries[y].pvAcKwh;
        // Loose tolerance: dispatch/curtailment is non-linear, but the
        // pure-PV path stays within 0.5 % of the linear scaling.
        expect(actual, closeTo(expected, expected * 0.005),
            reason: 'year $y pvAc should track linear derate of year 0');
      }
    });

    test('SOC continuity: year y end SOC == year y+1 start SOC', () {
      final cfg = _baseConfig(years: 3);
      final result = const PvSimulator().run(cfg);
      final per = result.summary.perYearSummaries;
      for (var y = 0; y < per.length - 1; y++) {
        final endY = per[y].finalBatterySocsKwh[0];
        final startNext = per[y + 1].startSocsUsedKwh[0];
        expect(startNext, closeTo(endY, 1e-9),
            reason: 'year $y end SOC must equal year ${y + 1} start SOC');
      }
    });

    test('pre-run executes once before year 0 only', () {
      // Count preRun progress events across the multi-year sweep — only
      // year 0 should emit them, later years run with preRunDays = 0.
      final cfg = _baseConfig(
        years: 3,
        preRunDays: 7,
        preRunMode: PreRunMode.singleWarmUp,
      );
      var preRunEvents = 0;
      const PvSimulator().run(cfg, onProgress: (p) {
        if (p.phase == SimulationPhase.preRun) preRunEvents++;
      });
      // The legacy linear path emits one preRun event per day. Year 0
      // contributes 7 events; years 1+ contribute 0.
      expect(preRunEvents, 7);
    });

    test('cyclicConvergence + simulationYears > 1 throws', () {
      expect(
        () => SimulationConfig(
          arrays: _baseConfig().arrays,
          inverters: _baseConfig().inverters,
          batteries: _baseConfig().batteries,
          loadProfile: _baseConfig().loadProfile,
          days: 365,
          simulationYears: 3,
          preRunMode: PreRunMode.cyclicConvergence,
        ).validate(),
        throwsArgumentError,
      );
    });

    test('simulationYears > 1 with days != 365 throws', () {
      expect(
        () => SimulationConfig(
          arrays: _baseConfig().arrays,
          inverters: _baseConfig().inverters,
          batteries: _baseConfig().batteries,
          loadProfile: _baseConfig().loadProfile,
          days: 30,
          simulationYears: 2,
        ).validate(),
        throwsArgumentError,
      );
    });

    test('keepSteps:true + years > 1 keeps only the final year steps', () {
      final cfg = _baseConfig(years: 3, keepSteps: true);
      final result = const PvSimulator().run(cfg);
      // 365 days × 24 steps == 8760, exactly one year retained.
      expect(result.steps, hasLength(365 * 24));
    });

    test('keepSteps:false + years > 1 produces summary without steps', () {
      final cfg = _baseConfig(years: 5, keepSteps: false);
      final result = const PvSimulator().run(cfg);
      expect(result.steps, isEmpty);
      expect(result.summary.perYearSummaries, hasLength(5));
      expect(result.summary.pvAcKwh, greaterThan(0));
    });

    test('aggregated top-level summary equals sum of per-year summaries', () {
      final cfg = _baseConfig(years: 4, degradationPct: 0.5);
      final result = const PvSimulator().run(cfg);
      var summedPv = 0.0;
      var summedLoad = 0.0;
      var summedImport = 0.0;
      for (final s in result.summary.perYearSummaries) {
        summedPv += s.pvAcKwh;
        summedLoad += s.loadKwh;
        summedImport += s.gridImportKwh;
      }
      expect(result.summary.pvAcKwh, closeTo(summedPv, 1e-9));
      expect(result.summary.loadKwh, closeTo(summedLoad, 1e-9));
      expect(result.summary.gridImportKwh, closeTo(summedImport, 1e-9));
    });

    test('degradationPctPerYear validation rejects negative and >= 10', () {
      expect(
        () => const PvArray(
          id: 'x',
          label: 'X',
          peakKw: 1.0,
          azimuthDeg: 180,
          tiltDeg: 30,
          inverterId: 'main',
          degradationPctPerYear: -0.1,
        ).validate(),
        throwsArgumentError,
      );
      expect(
        () => const PvArray(
          id: 'x',
          label: 'X',
          peakKw: 1.0,
          azimuthDeg: 180,
          tiltDeg: 30,
          inverterId: 'main',
          degradationPctPerYear: 10.0,
        ).validate(),
        throwsArgumentError,
      );
    });

    test('simulationYears out of range throws', () {
      expect(
        () => _baseConfig(years: 0).validate(),
        throwsArgumentError,
      );
      expect(
        () => _baseConfig(years: 31).validate(),
        throwsArgumentError,
      );
    });
  });
}

double _pow(double base, int exp) {
  var r = 1.0;
  for (var i = 0; i < exp; i++) {
    r *= base;
  }
  return r;
}
