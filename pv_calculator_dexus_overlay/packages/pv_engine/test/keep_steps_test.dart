import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

/// Phase 9 — C4: with `SimulationConfig.keepSteps: false` the simulator
/// skips retaining per-step records but still produces an identical
/// SimulationSummary. Memory wins for scenario sweeps; correctness must
/// be unchanged.
void main() {
  SimulationConfig configWith({required bool keepSteps, int days = 14}) =>
      SimulationConfig(
        arrays: const [
          PvArray(id: 'a', label: 'A', peakKw: 5, azimuthDeg: 180, tiltDeg: 35, inverterId: 'inv'),
          PvArray(id: 'b', label: 'B', peakKw: 3, azimuthDeg: 270, tiltDeg: 30, inverterId: 'inv'),
        ],
        inverters: const [Inverter(id: 'inv', label: 'Inv', maxAcKw: 6)],
        batteries: const [
          BatteryConfig(id: 'bat', capacityKwh: 8, maxChargeKw: 3, maxDischargeKw: 3),
        ],
        loadProfile: const LoadProfile(dailyKwh: 12),
        startDayOfYear: 80,
        days: days,
        keepSteps: keepSteps,
        gridExportLimitKw: 4,
      );

  test('keepSteps: false produces an empty steps list', () {
    final r = const PvSimulator().run(configWith(keepSteps: false));
    expect(r.steps, isEmpty);
  });

  test('summary is identical with and without keepSteps', () {
    final kept = const PvSimulator().run(configWith(keepSteps: true)).summary;
    final dropped = const PvSimulator().run(configWith(keepSteps: false)).summary;

    expect(dropped.pvDcKwh, closeTo(kept.pvDcKwh, 1e-12));
    expect(dropped.pvAcKwh, closeTo(kept.pvAcKwh, 1e-12));
    expect(dropped.loadKwh, closeTo(kept.loadKwh, 1e-12));
    expect(dropped.selfConsumptionKwh, closeTo(kept.selfConsumptionKwh, 1e-12));
    expect(dropped.batteryChargeKwh, closeTo(kept.batteryChargeKwh, 1e-12));
    expect(dropped.batteryDischargeKwh, closeTo(kept.batteryDischargeKwh, 1e-12));
    expect(dropped.gridImportKwh, closeTo(kept.gridImportKwh, 1e-12));
    expect(dropped.gridExportKwh, closeTo(kept.gridExportKwh, 1e-12));
    expect(dropped.curtailedDcKwh, closeTo(kept.curtailedDcKwh, 1e-12));
    expect(dropped.curtailedAcKwh, closeTo(kept.curtailedAcKwh, 1e-12));
    expect(dropped.curtailedExportKwh, closeTo(kept.curtailedExportKwh, 1e-12));
    expect(dropped.microInverterDeliveredKwh, closeTo(kept.microInverterDeliveredKwh, 1e-12));
    expect(dropped.microInverterShortfallKwh, closeTo(kept.microInverterShortfallKwh, 1e-12));
    expect(dropped.unservedLoadKwh, closeTo(kept.unservedLoadKwh, 1e-12));
    expect(dropped.finalBatterySocKwh, closeTo(kept.finalBatterySocKwh, 1e-12));
  });

  test('keepSteps round-trips through JSON when non-default', () {
    final cfg = configWith(keepSteps: false);
    final json = cfg.toJson();
    expect(json['keepSteps'], false);
    final restored = SimulationConfig.fromJson(json);
    expect(restored.keepSteps, false);
  });

  test('default keepSteps is true and the JSON omits the field', () {
    final cfg = configWith(keepSteps: true);
    expect(cfg.toJson().containsKey('keepSteps'), isFalse);
    // Pre-Phase-9 JSON files have no `keepSteps` key — they must load
    // with the default (true) so they keep producing per-step series.
    final legacyJson = Map<String, dynamic>.from(cfg.toJson());
    legacyJson.remove('keepSteps');
    expect(SimulationConfig.fromJson(legacyJson).keepSteps, isTrue);
  });

  test('cyclic convergence respects keepSteps', () {
    final cfg = SimulationConfig(
      arrays: const [
        PvArray(id: 'a', label: 'A', peakKw: 5, azimuthDeg: 180, tiltDeg: 35, inverterId: 'inv'),
      ],
      inverters: const [Inverter(id: 'inv', label: 'Inv', maxAcKw: 5)],
      batteries: const [
        BatteryConfig(id: 'b', capacityKwh: 8, maxChargeKw: 3, maxDischargeKw: 3),
      ],
      loadProfile: const LoadProfile(dailyKwh: 8),
      preRunMode: PreRunMode.cyclicConvergence,
      maxConvergenceIterations: 3,
      keepSteps: false,
    );
    final r = const PvSimulator().run(cfg);
    expect(r.steps, isEmpty);
    expect(r.summary.pvAcKwh, greaterThan(0));
  });
}
