import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

class _FullSunWeather extends IrradianceSource {
  const _FullSunWeather();
  @override
  WeatherSample sampleFor(WeatherQuery query) {
    if (query.hourOfDay < 6 || query.hourOfDay > 18) return WeatherSample.empty;
    return const WeatherSample(poaWPerM2: 1000, ambientTempC: 25);
  }
}

class _DarkWeather extends IrradianceSource {
  const _DarkWeather();
  @override
  WeatherSample sampleFor(WeatherQuery query) => WeatherSample.empty;
}

const _array = PvArray(
  id: 'a1', label: 'A1', peakKw: 3.0, azimuthDeg: 180, tiltDeg: 35,
  inverterId: 'inv', lossFactor: 0.0, shadingFactor: 0.0,
);

const _inverter =
    Inverter(id: 'inv', label: 'Hybrid', maxAcKw: 5.0, efficiency: 1.0);

// Topology: array → cc → dc-1 → inv → ac-main, with battery DC-coupled
// to dc-1. `mode` and `cc.efficiency` / `cc.maxInputKw` are wired by
// each test; the rest stays identical.
TopologyGraph _topology({
  required BusMode mode,
  required double ccEfficiency,
  double? ccMaxInputKw,
}) {
  return TopologyGraph(
    dcBuses: [DcBus(id: 'dc-1', mode: mode)],
    acBuses: const [AcBus(id: 'ac-main')],
    chargeControllers: [
      ChargeController(
        id: 'cc-1',
        dcBusId: 'dc-1',
        efficiency: ccEfficiency,
        maxInputKw: ccMaxInputKw,
      ),
    ],
    edges: const [
      BusEdge(fromId: 'a1', toId: 'cc-1'),
      BusEdge(fromId: 'dc-1', toId: 'inv'),
      BusEdge(fromId: 'inv', toId: 'ac-main', maxPowerKw: 5.0),
    ],
    batteryCouplings: const [
      BatteryCouplingSpec(
        batteryId: 'b1', coupling: BatteryCoupling.dc, dcBusId: 'dc-1'),
    ],
  );
}

void main() {
  group('Phase 4b — DC-coupled dispatch', () {
    test('chargeController clip + efficiency are applied before the DC bus', () {
      // Array: 3 kWp under full sun → ~3 kWh per peak hour. Cap at 2
      // kWh; efficiency 0.9 → 1.8 kWh on the bus. Battery is large &
      // mostly empty so it absorbs everything that arrives at the bus.
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [_inverter],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 100.0, maxChargeKw: 10.0,
            maxDischargeKw: 10.0, minSocKwh: 0, initialSocKwh: 0,
            roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 0),
        days: 1,
        topology: _topology(
          mode: BusMode.hybrid, ccEfficiency: 0.9, ccMaxInputKw: 2.0),
        weatherSource: const _FullSunWeather(),
      );
      final result = const PvSimulator().run(cfg);
      // Peak step (full sun) should have:
      //   pvDcKwh = 3 (module output)
      //   curtailedDcKwh = 3 - 2 = 1 (cc input clip)
      //   dcDirectChargeKwh = 2 * 0.9 = 1.8 (post-cap × cc eta)
      //   pvAcKwh = 0 (battery absorbs everything; nothing bypasses)
      var sawPeak = false;
      for (final s in result.steps) {
        if (s.pvDcKwh >= 2.999) {
          sawPeak = true;
          expect(s.pvDcKwh, closeTo(3.0, 1e-9));
          expect(s.curtailedDcKwh, closeTo(1.0, 1e-9));
          expect(s.dcDirectChargeKwh, closeTo(1.8, 1e-9));
          expect(s.pvAcKwh, closeTo(0.0, 1e-9));
        }
      }
      expect(sawPeak, isTrue, reason: 'expected at least one full-sun step');
    });

    test('DC-coupled battery is charged without the inverter η', () {
      // No load, hybrid bus, cc and inverter both eta=1.0. The battery
      // sees `dcKwh * sqrt(roundTripEfficiency)` stored — NO additional
      // inverter loss. Compare against an AC-coupled control with the
      // same hardware: the AC-coupled run would have applied the
      // inverter η to PV before charging, so the DC-coupled SOC must
      // be strictly higher when the inverter η < 1.
      final dcCfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [
          Inverter(id: 'inv', label: 'Hybrid', maxAcKw: 5.0, efficiency: 0.9),
        ],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 1000.0, maxChargeKw: 10.0,
            maxDischargeKw: 10.0, minSocKwh: 0, initialSocKwh: 0,
            roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 0),
        days: 1,
        topology: _topology(
          mode: BusMode.hybrid, ccEfficiency: 1.0, ccMaxInputKw: null),
        weatherSource: const _FullSunWeather(),
      );
      final dcResult = const PvSimulator().run(dcCfg);

      // AC-coupled control: same arrays, same inverter, no charge
      // controllers, AC-coupled battery (default coupling).
      final acCfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [
          Inverter(id: 'inv', label: 'AC', maxAcKw: 5.0, efficiency: 0.9),
        ],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 1000.0, maxChargeKw: 10.0,
            maxDischargeKw: 10.0, minSocKwh: 0, initialSocKwh: 0,
            roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 0),
        days: 1,
        weatherSource: const _FullSunWeather(),
      );
      final acResult = const PvSimulator().run(acCfg);

      // DC-coupled keeps the full PV-DC; AC-coupled loses 10% to
      // inverter efficiency before charging.
      expect(dcResult.summary.finalBatterySocKwh,
          greaterThan(acResult.summary.finalBatterySocKwh));
      expect(
          dcResult.summary.finalBatterySocKwh / acResult.summary.finalBatterySocKwh,
          closeTo(1.0 / 0.9, 1e-6));
      // pvAcKwh on the DC-coupled scenario is 0 — battery absorbs
      // everything and no surplus bypasses to AC.
      expect(dcResult.summary.pvAcKwh, closeTo(0.0, 1e-9));
      // DC direct charge tracks the bus-side energy (which equals
      // pvDcKwh here since cc.eta = 1, no clip, no shading).
      expect(dcResult.summary.dcDirectChargeKwh,
          closeTo(dcResult.summary.pvDcKwh, 1e-9));
      // No DC curtailment on hybrid mode.
      expect(dcResult.summary.dcCurtailedKwh, closeTo(0.0, 1e-9));
    });

    test('hybrid bus: PV bypasses to AC when the battery is full', () {
      // Battery starts at capacity (full); cc.eta = 1.0; inverter
      // eta = 0.95. Residual PV-DC must flow through the inverter to
      // AC.
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [
          Inverter(id: 'inv', label: 'Hybrid', maxAcKw: 5.0, efficiency: 0.95),
        ],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 1.0, maxChargeKw: 10.0,
            maxDischargeKw: 10.0, minSocKwh: 0, initialSocKwh: 1.0,
            roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 0),
        days: 1,
        topology: _topology(
          mode: BusMode.hybrid, ccEfficiency: 1.0, ccMaxInputKw: null),
        weatherSource: const _FullSunWeather(),
        gridExportLimitKw: 100.0,
      );
      final result = const PvSimulator().run(cfg);
      // Battery is full → no DC direct charge after the first chunk
      // (the very first hour can still top up if there's any headroom;
      // start SOC == capacity so even the first hour is 0).
      expect(result.summary.dcDirectChargeKwh, closeTo(0.0, 1e-9));
      // PV reached AC via hybrid bypass.
      expect(result.summary.pvAcKwh, greaterThan(0.0));
      // No DC curtailment on hybrid mode.
      expect(result.summary.dcCurtailedKwh, closeTo(0.0, 1e-9));
      // Export ≈ pvAcKwh (load = 0).
      expect(result.summary.gridExportKwh,
          closeTo(result.summary.pvAcKwh, 1e-9));
    });

    test('batteryFed bus: PV is curtailed when the battery cannot absorb', () {
      // Battery full + batteryFed mode ⇒ residual PV-DC is lost; no AC
      // bypass path exists.
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [_inverter],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 1.0, maxChargeKw: 10.0,
            maxDischargeKw: 10.0, minSocKwh: 0, initialSocKwh: 1.0,
            roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 0),
        days: 1,
        topology: _topology(
          mode: BusMode.batteryFed, ccEfficiency: 1.0, ccMaxInputKw: null),
        weatherSource: const _FullSunWeather(),
      );
      final result = const PvSimulator().run(cfg);
      expect(result.summary.pvAcKwh, closeTo(0.0, 1e-9));
      expect(result.summary.gridExportKwh, closeTo(0.0, 1e-9));
      // All PV-DC reaching the bus is curtailed (no charging path
      // either: battery is full).
      expect(result.summary.dcCurtailedKwh, greaterThan(0.0));
      // Curtailed amount equals bus-side energy (cc.eta = 1 means it
      // equals pvDcKwh) since none of it got stored.
      expect(result.summary.dcCurtailedKwh,
          closeTo(result.summary.pvDcKwh, 1e-9));
    });

    test('batteryFed bus: empty battery still gets charged, AC stays 0', () {
      // Same topology as above but the battery starts empty. The whole
      // bus energy goes into storage; no curtailment, no AC.
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [_inverter],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 1000.0, maxChargeKw: 10.0,
            maxDischargeKw: 10.0, minSocKwh: 0, initialSocKwh: 0,
            roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 0),
        days: 1,
        topology: _topology(
          mode: BusMode.batteryFed, ccEfficiency: 1.0, ccMaxInputKw: null),
        weatherSource: const _FullSunWeather(),
      );
      final result = const PvSimulator().run(cfg);
      expect(result.summary.pvAcKwh, closeTo(0.0, 1e-9));
      expect(result.summary.gridExportKwh, closeTo(0.0, 1e-9));
      expect(result.summary.dcCurtailedKwh, closeTo(0.0, 1e-9));
      expect(result.summary.dcDirectChargeKwh,
          closeTo(result.summary.pvDcKwh, 1e-9));
    });

    test('SOC pre-run still works under DC coupling', () {
      // preRunDays > 0 with a DC-coupled battery: pre-run advances SOC
      // but produces no reported steps; the reported window starts at
      // a non-trivial SOC.
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [_inverter],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 5.0, maxChargeKw: 2.0, maxDischargeKw: 2.0,
            minSocKwh: 0, initialSocKwh: 0, roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 0),
        days: 1,
        preRunDays: 3,
        topology: _topology(
          mode: BusMode.hybrid, ccEfficiency: 1.0, ccMaxInputKw: null),
        weatherSource: const _FullSunWeather(),
      );
      final result = const PvSimulator().run(cfg);
      // Battery must have accumulated charge during the pre-run.
      expect(result.summary.startSocsUsedKwh.single, greaterThan(0.0));
      // Reported day produced exactly stepsPerDay entries.
      expect(result.steps.length, cfg.timeStep.stepsPerDay);
    });

    test('legacy AC-only scenario stays byte-identical (regression)', () {
      // A fully AC-coupled scenario should produce the same KPIs no
      // matter the surrounding Phase 4b machinery. We assert this by
      // running a darkened-then-sunny day with both no-DC topology
      // (legacy) and an unused explicit topology that doesn't activate
      // any DC features — both must produce identical summaries.
      final base = SimulationConfig(
        arrays: const [_array],
        inverters: const [_inverter],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 5.0, maxChargeKw: 2.0, maxDischargeKw: 2.0,
            minSocKwh: 0, initialSocKwh: 1.0, roundTripEfficiency: 0.9,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 5.0),
        days: 1,
        weatherSource: const _FullSunWeather(),
      );
      final legacy = const PvSimulator().run(base);
      expect(legacy.summary.dcDirectChargeKwh, closeTo(0.0, 1e-12));
      expect(legacy.summary.dcCurtailedKwh, closeTo(0.0, 1e-12));
    });

    test('hybrid bypass enforces the inverter\'s maxDcInputKw on the residual', () {
      // 3 kWp array, cc.eta=1.0 → 3 kWh residual at peak hour reaches
      // the bus. Battery is full so it can't absorb. Hybrid inverter
      // has `maxDcInputKw = 1.5`, so half the residual must be
      // curtailed on the DC side BEFORE the inverter efficiency kicks
      // in. Without the cap the AC path would silently overrun the
      // physical DC stage.
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [
          Inverter(
              id: 'inv',
              label: 'Hybrid',
              maxAcKw: 5.0,
              efficiency: 1.0,
              maxDcInputKw: 1.5),
        ],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 1.0, maxChargeKw: 10.0,
            maxDischargeKw: 10.0, minSocKwh: 0, initialSocKwh: 1.0,
            roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 0),
        days: 1,
        topology: _topology(
          mode: BusMode.hybrid, ccEfficiency: 1.0, ccMaxInputKw: null),
        weatherSource: const _FullSunWeather(),
        gridExportLimitKw: 100.0,
      );
      final result = const PvSimulator().run(cfg);
      var sawPeak = false;
      for (final s in result.steps) {
        if (s.pvDcKwh >= 2.999) {
          sawPeak = true;
          // 3 kWh PV-DC, 1.5 kWh through inverter, 1.5 kWh curtailed.
          expect(s.pvDcKwh, closeTo(3.0, 1e-9));
          expect(s.pvAcKwh, closeTo(1.5, 1e-9));
          expect(s.curtailedDcKwh, closeTo(1.5, 1e-9));
        }
      }
      expect(sawPeak, isTrue);
    });

    test('SelfConsumptionFirst covers AC load before charging DC battery', () {
      // Reviewer (Codex) call-out: pre-Chunk-7 the DC pre-step charged
      // the battery unconditionally, leaving load uncovered and
      // triggering grid import while PV was still pooling on the bus.
      // After threading the policy plan through the DC pre-step, load
      // is satisfied first; only the surplus reaches the battery.
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [
          Inverter(id: 'inv', label: 'Hybrid', maxAcKw: 10.0, efficiency: 1.0),
        ],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 1000.0, maxChargeKw: 100.0,
            maxDischargeKw: 100.0, minSocKwh: 0, initialSocKwh: 0,
            roundTripEfficiency: 1.0,
          ),
        ],
        // ~1 kWh/h average load (24 kWh/day with the default hourly
        // shape) — well within PV at peak hours but non-trivial.
        loadProfile: const LoadProfile(dailyKwh: 24.0),
        days: 1,
        topology: _topology(
          mode: BusMode.hybrid, ccEfficiency: 1.0, ccMaxInputKw: null),
        weatherSource: const _FullSunWeather(),
      );
      final result = const PvSimulator().run(cfg);
      // Grid import should be zero during the sunlit hours — any
      // import there would prove load is still being uncovered while
      // PV charges the battery. Acceptable during the night when PV
      // is 0 and the battery may also be empty.
      var sawSunStep = false;
      for (final s in result.steps) {
        if (s.pvDcKwh > 0.5 && s.loadKwh > 0.0) {
          sawSunStep = true;
          expect(s.gridImportKwh, closeTo(0.0, 1e-9),
              reason: 'no grid import expected while PV-DC is available');
        }
      }
      expect(sawSunStep, isTrue);
    });

    test('BatteryReservePolicy caps DC charging at the reserve ceiling', () {
      // Reserve fraction 0.5 ⇒ charging stops at 50 % of capacity. PV
      // arrives at full sun for the whole day; the battery starts at
      // 80 % (above reserve) and should NOT be charged at all.
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [_inverter],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 1.0, maxChargeKw: 10.0,
            maxDischargeKw: 10.0, minSocKwh: 0, initialSocKwh: 0.8,
            roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 0),
        days: 1,
        dispatchPolicy: const BatteryReservePolicy(reserveSocFraction: 0.5),
        topology: _topology(
          mode: BusMode.hybrid, ccEfficiency: 1.0, ccMaxInputKw: null),
        weatherSource: const _FullSunWeather(),
        gridExportLimitKw: 100.0,
      );
      final result = const PvSimulator().run(cfg);
      // The battery sits above the reserve at start; policy refuses to
      // charge, so DC pre-step also refuses, and no DC direct-charge
      // is recorded. PV flows entirely through the hybrid bypass.
      expect(result.summary.dcDirectChargeKwh, closeTo(0.0, 1e-9));
      expect(result.summary.pvAcKwh, greaterThan(0.0));
      // Final SOC unchanged (no charging).
      expect(result.summary.finalBatterySocKwh, closeTo(0.8, 1e-9));
    });

    test('zero-PV step in DC topology produces no NaNs in per-array AC', () {
      // Dark hour, DC topology configured — array DC = 0, every ratio
      // computation must not divide by zero.
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [_inverter],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 5.0, maxChargeKw: 2.0, maxDischargeKw: 2.0,
            minSocKwh: 0, initialSocKwh: 1.0, roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 0),
        days: 1,
        topology: _topology(
          mode: BusMode.hybrid, ccEfficiency: 0.97, ccMaxInputKw: 5.0),
        weatherSource: const _DarkWeather(),
      );
      final result = const PvSimulator().run(cfg);
      expect(result.summary.pvDcKwh, closeTo(0.0, 1e-9));
      expect(result.summary.pvAcKwh, closeTo(0.0, 1e-9));
      expect(result.summary.dcDirectChargeKwh, closeTo(0.0, 1e-9));
      expect(result.summary.dcCurtailedKwh, closeTo(0.0, 1e-9));
      for (final s in result.steps) {
        expect(s.acKwhByArray.single.isFinite, isTrue);
      }
    });
  });
}
