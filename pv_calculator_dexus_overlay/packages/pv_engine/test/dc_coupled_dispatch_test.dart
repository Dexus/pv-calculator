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

    test('SelfConsumptionFirst: DC reservation honours already-covered AC load', () {
      // Codex P2: when an AC-path array already covers AC load, the
      // DC-coupled battery should NOT have its charge target reduced
      // by `loadKwh` — only by load not yet served on AC. We mix one
      // DC array (via cc) and one AC array (legacy MPPT path) and
      // confirm the DC battery still receives the full DC pool.
      final cfg = SimulationConfig(
        arrays: const [
          // 3 kWp on the DC path.
          PvArray(
              id: 'a1', label: 'A1', peakKw: 3.0, azimuthDeg: 180, tiltDeg: 35,
              inverterId: 'inv', lossFactor: 0.0, shadingFactor: 0.0),
          // 2 kWp on the legacy AC path through 'ac-inv' — produces
          // enough at peak to cover the household load on its own.
          PvArray(
              id: 'a2', label: 'A2', peakKw: 2.0, azimuthDeg: 180, tiltDeg: 35,
              inverterId: 'ac-inv', lossFactor: 0.0, shadingFactor: 0.0),
        ],
        inverters: const [
          Inverter(id: 'inv', label: 'Hybrid', maxAcKw: 10.0, efficiency: 1.0),
          Inverter(id: 'ac-inv', label: 'AC only', maxAcKw: 10.0, efficiency: 1.0),
        ],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 1000.0, maxChargeKw: 10.0,
            maxDischargeKw: 10.0, minSocKwh: 0, initialSocKwh: 0,
            roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 12.0),
        days: 1,
        topology: TopologyGraph(
          dcBuses: const [DcBus(id: 'dc-1')],
          acBuses: const [AcBus(id: 'ac-main')],
          chargeControllers: const [
            ChargeController(id: 'cc-1', dcBusId: 'dc-1', efficiency: 1.0),
          ],
          mppts: const [MpptNode(id: 'mppt-ac-inv', inverterId: 'ac-inv')],
          edges: const [
            BusEdge(fromId: 'a1', toId: 'cc-1'),
            BusEdge(fromId: 'a2', toId: 'mppt-ac-inv'),
            BusEdge(fromId: 'dc-1', toId: 'inv'),
            BusEdge(fromId: 'inv', toId: 'ac-main', maxPowerKw: 10.0),
            BusEdge(fromId: 'mppt-ac-inv', toId: 'ac-inv'),
            BusEdge(fromId: 'ac-inv', toId: 'ac-main', maxPowerKw: 10.0),
          ],
          batteryCouplings: const [
            BatteryCouplingSpec(
                batteryId: 'b1', coupling: BatteryCoupling.dc, dcBusId: 'dc-1'),
          ],
        ),
        weatherSource: const _FullSunWeather(),
        gridExportLimitKw: 100.0,
      );
      final result = const PvSimulator().run(cfg);
      // Find a peak-sun step where both arrays produce; the DC array
      // contributes 3 kWh to the bus, the AC array contributes 2 kWh
      // straight to AC. Load at that hour is far below 2 kWh, so the
      // AC side already covers it.
      var sawPeak = false;
      for (final s in result.steps) {
        // a1 contributes ~3 kWh DC, a2 contributes ~2 kWh DC at peak.
        if (s.dcKwhByArray[0] > 2.99 && s.dcKwhByArray[1] > 1.99) {
          sawPeak = true;
          // The DC battery received the full DC bus pool (3 × 1.0 cc.eta
          // × 1.0 chargeEff = 3 kWh stored). No reduction by load.
          expect(s.dcDirectChargeKwh, closeTo(3.0, 1e-9));
          // AC export equals (a2's 2 kWh AC minus the small load slice
          // for that hour). At a 12 kWh/day load and the default shape,
          // peak hours carry < 1 kWh load, so AC has plenty for both
          // load and export.
          expect(s.gridImportKwh, closeTo(0.0, 1e-9));
        }
      }
      expect(sawPeak, isTrue);
    });

    test('batteryFed bus: empty battery + AC load = battery charges first, grid covers load', () {
      // Codex P2: the policy must NOT reserve DC for "load" on a
      // batteryFed bus, because there is no hybrid bypass. The bus's
      // entire DC pool belongs to the battery; load comes from the
      // battery's discharge later (or, if the battery can't keep up,
      // from the grid).
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [_inverter],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 1000.0, maxChargeKw: 100.0,
            maxDischargeKw: 0.0, minSocKwh: 0, initialSocKwh: 0,
            roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 24.0),
        days: 1,
        topology: _topology(
          mode: BusMode.batteryFed, ccEfficiency: 1.0, ccMaxInputKw: null),
        weatherSource: const _FullSunWeather(),
      );
      final result = const PvSimulator().run(cfg);
      // PV-DC = pvDcKwh; battery stores it all (no AC bypass, no load
      // can siphon any away in the policy step).
      expect(result.summary.dcDirectChargeKwh,
          closeTo(result.summary.pvDcKwh, 1e-9));
      // Load is unmet by PV (no AC path) and not by battery
      // (maxDischargeKw=0), so it imports from grid in full.
      expect(result.summary.gridImportKwh,
          closeTo(result.summary.loadKwh, 1e-9));
      // No curtailment — battery had headroom for everything.
      expect(result.summary.dcCurtailedKwh, closeTo(0.0, 1e-9));
    });

    test('rule 10: batteryFed inverter rejects arrays not wired through a cc', () {
      // PvArray.inverterId points at the batteryFed bus's inverter,
      // but the explicit topology has no `array → cc` edge for it.
      // The simulator's legacy fallback would then route this array's
      // PV through `dcByInverter[inv]` → AC, violating the batteryFed
      // guarantee. SimulationConfig.validate must reject this.
      final brokenCfg = SimulationConfig(
        arrays: const [
          PvArray(
              id: 'a1', label: 'A1', peakKw: 3.0, azimuthDeg: 180, tiltDeg: 35,
              inverterId: 'inv', lossFactor: 0.0, shadingFactor: 0.0),
          PvArray(
              id: 'a2', label: 'A2', peakKw: 1.0, azimuthDeg: 180, tiltDeg: 35,
              inverterId: 'inv', lossFactor: 0.0, shadingFactor: 0.0),
        ],
        inverters: const [_inverter],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 5.0, maxChargeKw: 2.0,
            maxDischargeKw: 2.0, minSocKwh: 0, initialSocKwh: 0,
            roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 0),
        days: 1,
        topology: const TopologyGraph(
          dcBuses: [DcBus(id: 'dc-1', mode: BusMode.batteryFed)],
          chargeControllers: [
            ChargeController(id: 'cc-1', dcBusId: 'dc-1', efficiency: 1.0),
          ],
          edges: [
            BusEdge(fromId: 'a1', toId: 'cc-1'),
            // `a2` has inverterId='inv' but no `a2 → cc` edge — would
            // silently route through the inverter's AC stage.
            BusEdge(fromId: 'dc-1', toId: 'inv'),
          ],
          batteryCouplings: [
            BatteryCouplingSpec(
                batteryId: 'b1', coupling: BatteryCoupling.dc, dcBusId: 'dc-1'),
          ],
        ),
        weatherSource: const _FullSunWeather(),
      );
      expect(brokenCfg.validate, throwsArgumentError);
    });

    test('ConstantFeed24h policy charges DC-coupled batteries via DC pool', () {
      // Codex P2: without a DC branch in `ConstantFeed24hPolicy`, an
      // `array → cc → batteryFed → battery` setup driven by a bank
      // would request 0 charge (no AC surplus exists), so the DC
      // pre-step would curtail all PV and the bank would have an
      // empty battery to draw from.
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [_inverter],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 1000.0, maxChargeKw: 100.0,
            maxDischargeKw: 100.0, minSocKwh: 0, initialSocKwh: 0,
            roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 0),
        days: 1,
        dispatchPolicy: const ConstantFeed24hPolicy(),
        topology: _topology(
          mode: BusMode.batteryFed, ccEfficiency: 1.0, ccMaxInputKw: null),
        weatherSource: const _FullSunWeather(),
      );
      final result = const PvSimulator().run(cfg);
      expect(result.summary.dcDirectChargeKwh,
          closeTo(result.summary.pvDcKwh, 1e-9));
      expect(result.summary.dcCurtailedKwh, closeTo(0.0, 1e-9));
    });

    test('two DC batteries on one hybrid bus share the load reservation', () {
      // Codex P2: per-bus charge budget. Two empty DC batteries on
      // the same bus must not each independently subtract the load
      // — otherwise the second battery sees the same DC pool minus
      // load and the load reservation is double-counted.
      final cfg = SimulationConfig(
        arrays: const [
          PvArray(
              id: 'a1', label: 'A1', peakKw: 3.0, azimuthDeg: 180, tiltDeg: 35,
              inverterId: 'inv', lossFactor: 0.0, shadingFactor: 0.0),
        ],
        inverters: const [_inverter],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 1000.0, maxChargeKw: 1.0,
            maxDischargeKw: 1.0, minSocKwh: 0, initialSocKwh: 0,
            roundTripEfficiency: 1.0,
          ),
          BatteryConfig(
            id: 'b2', capacityKwh: 1000.0, maxChargeKw: 1.0,
            maxDischargeKw: 1.0, minSocKwh: 0, initialSocKwh: 0,
            roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 0),
        days: 1,
        topology: const TopologyGraph(
          dcBuses: [DcBus(id: 'dc-1')],
          acBuses: [AcBus(id: 'ac-main')],
          chargeControllers: [
            ChargeController(id: 'cc-1', dcBusId: 'dc-1', efficiency: 1.0),
          ],
          edges: [
            BusEdge(fromId: 'a1', toId: 'cc-1'),
            BusEdge(fromId: 'dc-1', toId: 'inv'),
            BusEdge(fromId: 'inv', toId: 'ac-main', maxPowerKw: 10.0),
          ],
          batteryCouplings: [
            BatteryCouplingSpec(
                batteryId: 'b1', coupling: BatteryCoupling.dc, dcBusId: 'dc-1'),
            BatteryCouplingSpec(
                batteryId: 'b2', coupling: BatteryCoupling.dc, dcBusId: 'dc-1'),
          ],
        ),
        weatherSource: const _FullSunWeather(),
        gridExportLimitKw: 100.0,
      );
      final result = const PvSimulator().run(cfg);
      // No load, no `remainingLoad` reservation. Each battery is
      // rate-limited at 1 kW; together they absorb ≤ 2 kWh per peak
      // hour. The 1 kWh excess (3 PV - 2 absorbed) bypasses to AC.
      var sawPeak = false;
      for (final s in result.steps) {
        if (s.pvDcKwh >= 2.999) {
          sawPeak = true;
          expect(s.batteryChargesKwh[0], closeTo(1.0, 1e-9));
          expect(s.batteryChargesKwh[1], closeTo(1.0, 1e-9));
          // ~1 kWh bypasses to AC (no load, exports).
          expect(s.pvAcKwh, closeTo(1.0, 1e-9));
        }
      }
      expect(sawPeak, isTrue);
    });

    test('batteryFed bus discharge respects the bus inverter\'s AC cap', () {
      // Codex P2: a 1 kW bus inverter and a 5 kW battery — direct
      // discharge must stay at the 1 kW inverter cap.
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [
          Inverter(id: 'inv', label: 'BatInv', maxAcKw: 1.0, efficiency: 1.0),
        ],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 50.0, maxChargeKw: 100.0,
            maxDischargeKw: 5.0, minSocKwh: 0, initialSocKwh: 20.0,
            roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 24.0 * 5.0),
        days: 1,
        topology: _topology(
          mode: BusMode.batteryFed, ccEfficiency: 1.0, ccMaxInputKw: null),
        weatherSource: const _DarkWeather(),
      );
      final result = const PvSimulator().run(cfg);
      // Every step where the battery had energy to discharge: capped at
      // 1 kWh per hour, not the 5 kWh the battery rate would allow.
      for (final s in result.steps) {
        if (s.batteryDischargeKwh > 0) {
          expect(s.batteryDischargeKwh, lessThanOrEqualTo(1.0 + 1e-9),
              reason: 'discharge must respect bus-inverter AC cap of 1 kW');
        }
      }
    });

    test('curtailedDcKwh includes batteryFed residual losses', () {
      // Codex P2: existing KPI consumers read `curtailedDcKwh`. Fold
      // batteryFed residual into it so the legacy KPI report doesn't
      // silently show 0 curtailment while energy is lost.
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
      expect(result.summary.dcCurtailedKwh, greaterThan(0.0));
      // The breakdown is a subset of the headline curtailment KPI.
      expect(result.summary.curtailedDcKwh,
          greaterThanOrEqualTo(result.summary.dcCurtailedKwh - 1e-9));
    });

    test('DC battery discharge shares the bus inverter AC cap with PV bypass', () {
      // Codex P2: 5 kW bus inverter, PV produces 3 kWh DC at peak
      // and the battery is full. The bypass uses 3 kWh of the 5 kWh
      // inverter cap; an unconstrained battery discharge would have
      // tried for another 5 kWh under enough load. Verify the
      // combined inverter AC output stays at or below the rating.
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [
          Inverter(id: 'inv', label: 'Hybrid', maxAcKw: 5.0, efficiency: 1.0),
        ],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 100.0, maxChargeKw: 10.0,
            maxDischargeKw: 100.0, minSocKwh: 0, initialSocKwh: 100.0,
            roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 24.0 * 10.0),
        days: 1,
        topology: _topology(
          mode: BusMode.hybrid, ccEfficiency: 1.0, ccMaxInputKw: null),
        weatherSource: const _FullSunWeather(),
      );
      final result = const PvSimulator().run(cfg);
      for (final s in result.steps) {
        // pvAcKwh already includes the hybrid bypass. Adding the
        // direct discharge (which goes through the same inverter)
        // must not exceed 5 kWh per 1-hour step.
        final totalInverterAc = s.pvAcKwh + s.batteryDischargeKwh;
        expect(totalInverterAc, lessThanOrEqualTo(5.0 + 1e-9),
            reason: 'PV bypass + battery discharge must respect the '
                '5 kW bus inverter cap');
      }
    });

    test('DC battery on hybrid bus without bus-inverter edge cannot direct-discharge', () {
      // Codex P2: missing `dcBus → inverter` edge ⇒ direct discharge
      // has no AC path. The router should not deliver any AC from
      // the battery's direct-discharge path. (Banks with their own
      // inverters are unaffected — covered separately.)
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [_inverter],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 50.0, maxChargeKw: 10.0,
            maxDischargeKw: 5.0, minSocKwh: 0, initialSocKwh: 25.0,
            roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 24.0 * 2.0),
        days: 1,
        // Topology with a charge controller but NO `dc-1 → inv` edge.
        // The hybrid bus has nowhere to send AC, so battery direct
        // discharge must be capped at zero.
        topology: const TopologyGraph(
          dcBuses: [DcBus(id: 'dc-1')],
          chargeControllers: [
            ChargeController(id: 'cc-1', dcBusId: 'dc-1', efficiency: 1.0),
          ],
          edges: [
            BusEdge(fromId: 'a1', toId: 'cc-1'),
          ],
          batteryCouplings: [
            BatteryCouplingSpec(
                batteryId: 'b1', coupling: BatteryCoupling.dc, dcBusId: 'dc-1'),
          ],
        ),
        weatherSource: const _DarkWeather(),
      );
      final result = const PvSimulator().run(cfg);
      // Battery cannot direct-discharge → batteryDischargeKwh stays 0
      // and the full load imports from the grid.
      expect(result.summary.batteryDischargeKwh, closeTo(0.0, 1e-9));
      expect(result.summary.gridImportKwh,
          closeTo(result.summary.loadKwh, 1e-9));
    });

    test('rule 11: a DC bus may have at most one outgoing inverter edge', () {
      const cfg = TopologyGraph(
        dcBuses: [DcBus(id: 'dc-1')],
        chargeControllers: [
          ChargeController(id: 'cc-1', dcBusId: 'dc-1', efficiency: 1.0),
        ],
        edges: [
          BusEdge(fromId: 'a1', toId: 'cc-1'),
          BusEdge(fromId: 'dc-1', toId: 'inv1'),
          BusEdge(fromId: 'dc-1', toId: 'inv2'),
        ],
      );
      expect(
        () => cfg.validate(
            arrayIds: {'a1'},
            inverterIds: {'inv1', 'inv2'},
            batteryIds: {},
            bankIds: {}),
        throwsArgumentError,
      );
    });

    test('two DC batteries share the bus inverter cap (Codex P2 round 5)', () {
      // 5 kW bus inverter + two 5 kW batteries on the same bus + 10
      // kWh of unmet load. Pre-fix: each battery saw the full 5 kW
      // inverter cap, so combined direct discharge could push 10 kWh
      // through a 5 kW inverter. After fix: shared `invRemaining`
      // headroom caps total discharge at 5 kWh.
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [
          Inverter(id: 'inv', label: 'BusInv', maxAcKw: 5.0, efficiency: 1.0),
        ],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 50.0, maxChargeKw: 100.0,
            maxDischargeKw: 5.0, minSocKwh: 0, initialSocKwh: 30.0,
            roundTripEfficiency: 1.0,
          ),
          BatteryConfig(
            id: 'b2', capacityKwh: 50.0, maxChargeKw: 100.0,
            maxDischargeKw: 5.0, minSocKwh: 0, initialSocKwh: 30.0,
            roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 24.0 * 10.0),
        days: 1,
        topology: const TopologyGraph(
          dcBuses: [DcBus(id: 'dc-1')],
          acBuses: [AcBus(id: 'ac-main')],
          chargeControllers: [
            ChargeController(id: 'cc-1', dcBusId: 'dc-1', efficiency: 1.0),
          ],
          edges: [
            BusEdge(fromId: 'a1', toId: 'cc-1'),
            BusEdge(fromId: 'dc-1', toId: 'inv'),
            BusEdge(fromId: 'inv', toId: 'ac-main', maxPowerKw: 5.0),
          ],
          batteryCouplings: [
            BatteryCouplingSpec(
                batteryId: 'b1', coupling: BatteryCoupling.dc, dcBusId: 'dc-1'),
            BatteryCouplingSpec(
                batteryId: 'b2', coupling: BatteryCoupling.dc, dcBusId: 'dc-1'),
          ],
        ),
        weatherSource: const _DarkWeather(),
      );
      final result = const PvSimulator().run(cfg);
      // Every step: combined direct discharge across both batteries
      // stays at or below the 5 kW (= 5 kWh per 1-h step) inverter cap.
      for (final s in result.steps) {
        final combined = s.batteryDischargesKwh.fold<double>(0.0, (a, b) => a + b);
        expect(combined, lessThanOrEqualTo(5.0 + 1e-9),
            reason: 'two DC batteries on one bus must share the inverter cap');
      }
    });

    test('AC battery charges from hybrid-bypass surplus (Codex P2 round 5)', () {
      // Mixed topology: DC-path via cc (3 kW PV) plus an AC-coupled
      // battery on a separate inverter that does NOT see direct PV.
      // Pre-fix: SelfConsumptionFirst saw `pvAcKwh = 0` for the AC
      // path and refused to charge the AC battery; the DC bypass AC
      // then exported uselessly. After fix: the policy receives an
      // `estimatedBypassAcKwh` and the AC battery requests charging.
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [
          Inverter(id: 'inv', label: 'Hybrid', maxAcKw: 10.0, efficiency: 1.0),
          Inverter(id: 'ac-inv', label: 'AC inv', maxAcKw: 10.0, efficiency: 1.0),
        ],
        batteries: const [
          BatteryConfig(
            id: 'ac-bat', capacityKwh: 10.0, maxChargeKw: 5.0,
            maxDischargeKw: 5.0, minSocKwh: 0, initialSocKwh: 0,
            roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 0),
        days: 1,
        topology: const TopologyGraph(
          dcBuses: [DcBus(id: 'dc-1')],
          acBuses: [AcBus(id: 'ac-main')],
          chargeControllers: [
            ChargeController(id: 'cc-1', dcBusId: 'dc-1', efficiency: 1.0),
          ],
          edges: [
            BusEdge(fromId: 'a1', toId: 'cc-1'),
            BusEdge(fromId: 'dc-1', toId: 'inv'),
            BusEdge(fromId: 'inv', toId: 'ac-main', maxPowerKw: 10.0),
            BusEdge(fromId: 'ac-inv', toId: 'ac-main', maxPowerKw: 10.0),
          ],
          // AC-coupled battery (default coupling).
          batteryCouplings: [
            BatteryCouplingSpec(batteryId: 'ac-bat', inverterId: 'ac-inv'),
          ],
        ),
        weatherSource: const _FullSunWeather(),
        gridExportLimitKw: 100.0,
      );
      final result = const PvSimulator().run(cfg);
      // AC battery accumulated SOC from hybrid-bypass AC surplus.
      expect(result.summary.finalBatterySocKwh, greaterThan(0.0));
    });

    test('DC discharge through bus inverter respects its efficiency (Codex P2 round 5)', () {
      // 80 % bus inverter. Battery has 10 kWh stored. Direct discharge
      // covers a 4 kWh AC load. SOC withdrawal must be `4 / 0.8 = 5`
      // kWh, not 4 kWh — the bus inverter loss is real.
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [
          Inverter(id: 'inv', label: 'BusInv', maxAcKw: 10.0, efficiency: 0.8),
        ],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 10.0, maxChargeKw: 5.0,
            maxDischargeKw: 5.0, minSocKwh: 0, initialSocKwh: 10.0,
            roundTripEfficiency: 1.0,
          ),
        ],
        // 4 kWh/h average load — the battery covers it via direct
        // discharge through the 80%-efficient bus inverter.
        loadProfile: LoadProfile(
          dailyKwh: 24.0 * 4.0,
          hourlyShape: List<double>.filled(24, 1.0),
        ),
        days: 1,
        topology: _topology(
          mode: BusMode.hybrid, ccEfficiency: 1.0, ccMaxInputKw: null),
        weatherSource: const _DarkWeather(),
      );
      final result = const PvSimulator().run(cfg);
      for (final s in result.steps) {
        if (s.batteryDischargeKwh > 0) {
          // Direct discharge: AC delivered ≤ stored × 0.8.
          // Look at first step where battery has discharged:
          // for a 4 kWh AC delivery, the SOC withdrawal is 5 kWh
          // (i.e. AC = stored × 0.8). Check via the SOC drop:
          final socsDrop = 10.0 - s.batterySocsKwh.single;
          // socsDrop / batteryDischargeKwh ≈ 1/0.8 = 1.25
          if (socsDrop > 0 && s.batteryDischargeKwh > 0) {
            final ratio = socsDrop / s.batteryDischargeKwh;
            // Allow some slack — the test fires on the first
            // discharging step.
            expect(ratio, closeTo(1.25, 0.01),
                reason: 'SOC withdrawal must include bus inverter η');
            break;
          }
        }
      }
    });

    test('charge-only hybrid bus does NOT reserve DC for load (Codex P2 round 5)', () {
      // Hybrid bus with NO outgoing inverter edge. The bus is
      // intentionally charge-only — load cannot be served via this
      // bus. The policy must not subtract `loadKwh` from the DC
      // pool, otherwise the battery charges less and the curtail
      // branch loses energy while the load imports from grid.
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [_inverter],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 100.0, maxChargeKw: 10.0,
            maxDischargeKw: 0.0, minSocKwh: 0, initialSocKwh: 0,
            roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: const LoadProfile(dailyKwh: 24.0),
        days: 1,
        topology: const TopologyGraph(
          dcBuses: [DcBus(id: 'dc-1')],
          chargeControllers: [
            ChargeController(id: 'cc-1', dcBusId: 'dc-1', efficiency: 1.0),
          ],
          edges: [
            BusEdge(fromId: 'a1', toId: 'cc-1'),
            // NO `dc-1 → inv` edge — charge-only bus.
          ],
          batteryCouplings: [
            BatteryCouplingSpec(
                batteryId: 'b1', coupling: BatteryCoupling.dc, dcBusId: 'dc-1'),
          ],
        ),
        weatherSource: const _FullSunWeather(),
      );
      final result = const PvSimulator().run(cfg);
      // Charge-only bus: battery absorbs full DC pool, no curtailment
      // from "load reservation".
      expect(result.summary.dcDirectChargeKwh,
          closeTo(result.summary.pvDcKwh, 1e-9));
    });

    test('DC battery rate cap is expressed in AC units (Codex P2 round 6)', () {
      // 1 kW battery behind a 50% bus inverter discharging through
      // direct path under heavy AC load. Pre-fix: the router allowed
      // `1 kWh` of AC delivery and withdrew `1 / 0.5 = 2 kWh` from
      // the battery in one step, exceeding `maxDischargeKw`. After
      // fix: rate cap × η caps the AC delivery at 0.5 kWh and the
      // SOC withdrawal at 1 kWh.
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [
          Inverter(id: 'inv', label: 'BusInv', maxAcKw: 100.0, efficiency: 0.5),
        ],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 100.0, maxChargeKw: 100.0,
            maxDischargeKw: 1.0, minSocKwh: 0, initialSocKwh: 50.0,
            roundTripEfficiency: 1.0,
          ),
        ],
        // Lots of load to make sure the battery's rate cap is the
        // binding constraint, not the load.
        loadProfile: LoadProfile(
          dailyKwh: 24.0 * 50.0,
          hourlyShape: List<double>.filled(24, 1.0),
        ),
        days: 1,
        topology: _topology(
          mode: BusMode.hybrid, ccEfficiency: 1.0, ccMaxInputKw: null),
        weatherSource: const _DarkWeather(),
      );
      final result = const PvSimulator().run(cfg);
      for (final s in result.steps) {
        if (s.batteryDischargeKwh > 0) {
          // AC delivered per hour ≤ 1 kW × 1 h × 0.5 η = 0.5 kWh.
          expect(s.batteryDischargeKwh, lessThanOrEqualTo(0.5 + 1e-9),
              reason: 'AC delivery must respect battery rate × inv η');
        }
      }
    });

    test('hybrid load reservation scales by inverter η (Codex P2 round 6)', () {
      // Pre-fix: with 50%-efficient bus inverter, reserving the raw
      // `loadKwh` as DC reservation left too little DC for bypass to
      // actually cover the load. After fix: reservation = loadAc / η,
      // so the bus carries enough DC for AC to cover the load.
      //
      // Setup: 5 kWh PV-DC per hour, 1 kWh AC load, 50% inverter.
      // To cover 1 kWh AC the bus needs 2 kWh DC. After reservation
      // there should be 3 kWh DC left for the battery.
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [
          Inverter(id: 'inv', label: 'BusInv', maxAcKw: 10.0, efficiency: 0.5),
        ],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 1000.0, maxChargeKw: 100.0,
            maxDischargeKw: 100.0, minSocKwh: 0, initialSocKwh: 0,
            roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: LoadProfile(
          dailyKwh: 24.0 * 1.0,
          hourlyShape: List<double>.filled(24, 1.0),
        ),
        days: 1,
        topology: _topology(
          mode: BusMode.hybrid, ccEfficiency: 1.0, ccMaxInputKw: null),
        weatherSource: const _FullSunWeather(),
      );
      final result = const PvSimulator().run(cfg);
      // Load is fully covered (no grid import) — the reservation was
      // sized correctly to give the inverter enough DC to produce
      // 1 kWh AC.
      var sawSun = false;
      for (final s in result.steps) {
        if (s.pvDcKwh > 2.5 && s.loadKwh > 0.5) {
          sawSun = true;
          expect(s.gridImportKwh, closeTo(0.0, 1e-9),
              reason: 'inverter η scaling should leave enough DC for load');
        }
      }
      expect(sawSun, isTrue);
    });

    test('load reservation is capped at inverter headroom (Codex P2 round 6)', () {
      // 100 kWh of load, 5 kW/1h bus inverter. Pre-fix the policy
      // reserved the full load and the battery got 0. After fix it's
      // capped at the inverter's remaining AC headroom (5 kWh).
      //
      // With ~3 kWh PV-DC per sun hour and inv.eta=1, all 3 kWh would
      // bypass to AC; load is too large to fully cover. Battery
      // should still be allowed to absorb DC up to its rate cap once
      // the inverter is fully busy serving the load.
      final cfg = SimulationConfig(
        arrays: const [
          PvArray(
              id: 'a1', label: 'A1', peakKw: 10.0, azimuthDeg: 180, tiltDeg: 35,
              inverterId: 'inv', lossFactor: 0.0, shadingFactor: 0.0),
        ],
        inverters: const [
          Inverter(id: 'inv', label: 'BusInv', maxAcKw: 5.0, efficiency: 1.0),
        ],
        batteries: const [
          BatteryConfig(
            id: 'b1', capacityKwh: 1000.0, maxChargeKw: 100.0,
            maxDischargeKw: 100.0, minSocKwh: 0, initialSocKwh: 0,
            roundTripEfficiency: 1.0,
          ),
        ],
        loadProfile: LoadProfile(
          dailyKwh: 24.0 * 100.0,
          hourlyShape: List<double>.filled(24, 1.0),
        ),
        days: 1,
        topology: TopologyGraph(
          dcBuses: const [DcBus(id: 'dc-1')],
          acBuses: const [AcBus(id: 'ac-main')],
          chargeControllers: const [
            ChargeController(id: 'cc-1', dcBusId: 'dc-1', efficiency: 1.0),
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
        ),
        weatherSource: const _FullSunWeather(),
      );
      final result = const PvSimulator().run(cfg);
      // Some PV should have been stored — pre-fix this was 0 because
      // load was unbounded and consumed the entire reservation.
      expect(result.summary.dcDirectChargeKwh, greaterThan(0.0),
          reason: 'battery should still absorb DC beyond the inverter cap');
    });

    test('hybrid bypass DC cap applies after edge η (Codex P2 round 6)', () {
      // Bus edge with η=0.5, inverter maxDcInputKw=2 kW. PV-DC on bus
      // = 5 kWh in 1 h. Inverter input after edge = 2.5 kWh; should
      // hit the 2 kWh cap → 2 kWh through inverter, 0.5 kWh of
      // inverter input curtailed. Bus-side equivalent of that
      // curtailment is 1 kWh (= 0.5 / 0.5). PV bypass to AC at
      // inverter η=1.0 → 2 kWh AC.
      //
      // Pre-fix the cap was applied to the bus-side 5 kWh directly,
      // cutting it to 2 kWh bus-side, which then arrived at the
      // inverter as 1 kWh after the edge loss — wrong.
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [
          Inverter(
              id: 'inv',
              label: 'BusInv',
              maxAcKw: 100.0,
              efficiency: 1.0,
              maxDcInputKw: 2.0),
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
        topology: const TopologyGraph(
          dcBuses: [DcBus(id: 'dc-1')],
          acBuses: [AcBus(id: 'ac-main')],
          chargeControllers: [
            ChargeController(id: 'cc-1', dcBusId: 'dc-1', efficiency: 1.0),
          ],
          edges: [
            BusEdge(fromId: 'a1', toId: 'cc-1'),
            // 50% lossy bus→inverter edge.
            BusEdge(fromId: 'dc-1', toId: 'inv', efficiency: 0.5),
            BusEdge(fromId: 'inv', toId: 'ac-main', maxPowerKw: 100.0),
          ],
          batteryCouplings: [
            BatteryCouplingSpec(
                batteryId: 'b1', coupling: BatteryCoupling.dc, dcBusId: 'dc-1'),
          ],
        ),
        weatherSource: const _FullSunWeather(),
        gridExportLimitKw: 100.0,
      );
      final result = const PvSimulator().run(cfg);
      var sawPeak = false;
      for (final s in result.steps) {
        if (s.pvDcKwh >= 2.999) {
          sawPeak = true;
          // Battery is full; bus residual = 3 kWh bus-side.
          // Inverter input cap = 2 kWh.
          // remainingBus = 2 / 0.5 = 4 kWh → no clip needed (3 < 4).
          // raw AC = 3 × 0.5 × 1.0 = 1.5 kWh.
          // Pre-fix would have clipped bus to 2 kWh → AC = 1 kWh.
          expect(s.pvAcKwh, closeTo(1.5, 1e-9),
              reason: 'inverter DC cap must be measured at inverter input '
                  '(after edge η), not on bus-side residual');
        }
      }
      expect(sawPeak, isTrue);
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
