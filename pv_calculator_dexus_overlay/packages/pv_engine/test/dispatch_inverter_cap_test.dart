import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

/// Architektur §5.3 explicit per-inverter AC cap:
///   `allowedPowerW = min(targetPowerW, battery.maxDischargeW, inverterLimitW)`.
///
/// Phase-4 splits `inverterLimitW` out of `battery.maxDischargeKw` via
/// `BatteryCouplingSpec.inverterId`. When set, the named inverter's
/// `effectiveMaxAcKw` becomes the shared AC envelope for direct
/// discharge + all banks fed from this battery. When unset, the engine
/// keeps the legacy behaviour of using `maxDischargeKw` as the AC cap.
void main() {
  // Helper: two 1×800-W banks on one 5 kWh / 5 kW battery, optionally
  // routed through a battery inverter via topology coupling.
  SimulationConfig sharedBatteryWithOptionalInverter({
    required double inverterMaxAcKw,
    bool wireInverterIntoCoupling = false,
    InverterRole inverterRole = InverterRole.batteryCoupled,
  }) {
    final inverters = <Inverter>[
      const Inverter(id: 'pv-inv', label: 'PV', maxAcKw: 10.0),
      Inverter(id: 'bat-inv', label: 'Battery inverter', maxAcKw: inverterMaxAcKw, role: inverterRole),
    ];
    final coupling = wireInverterIntoCoupling
        ? const BatteryCouplingSpec(batteryId: 'b1', inverterId: 'bat-inv')
        : const BatteryCouplingSpec(batteryId: 'b1');
    return SimulationConfig(
      arrays: [
        const PvArray(id: 'a1', label: 'A', peakKw: 0.001, azimuthDeg: 180, tiltDeg: 35, inverterId: 'pv-inv'),
      ],
      inverters: inverters,
      batteries: const [
        BatteryConfig(id: 'b1', capacityKwh: 20.0, maxChargeKw: 5.0, maxDischargeKw: 5.0, initialSocKwh: 20.0),
      ],
      microInverterBanks: const [
        MicroInverterBank(id: 'bank-a', batteryId: 'b1', count: 1, unitRatedPowerW: 800, inverterEfficiency: 1.0),
        MicroInverterBank(id: 'bank-b', batteryId: 'b1', count: 1, unitRatedPowerW: 800, inverterEfficiency: 1.0),
      ],
      topology: TopologyGraph(batteryCouplings: [coupling]),
      dispatchPolicy: const ConstantFeed24hPolicy(),
      loadProfile: const LoadProfile(dailyKwh: 0),
      startDayOfYear: 355,
      days: 1,
    );
  }

  test('inverterId caps combined AC delivery below battery.maxDischargeKw', () {
    final result = const PvSimulator().run(sharedBatteryWithOptionalInverter(
      inverterMaxAcKw: 1.0,
      wireInverterIntoCoupling: true,
    ));
    const stepHours = 1.0;
    const inverterCapKwh = 1.0 * stepHours;
    for (final step in result.steps) {
      expect(step.microInverterDeliveredKwh, lessThanOrEqualTo(inverterCapKwh + 1e-9),
          reason: 'Combined bank AC delivery ${step.microInverterDeliveredKwh} exceeded '
              'the battery inverter cap $inverterCapKwh at hour ${step.hourOfDay}');
      expect(step.batteryDischargesKwh[0], lessThanOrEqualTo(inverterCapKwh + 1e-9));
    }
    final firstStep = result.steps.first;
    // bank-a saturates at 0.8 kWh; bank-b gets only the remaining 0.2 kWh
    // under the 1.0 kWh inverter cap (battery would allow 5.0 kWh).
    expect(firstStep.microInverterDeliveriesKwh[0], closeTo(0.8, 1e-6));
    expect(firstStep.microInverterDeliveriesKwh[1], closeTo(0.2, 1e-6));
    expect(result.summary.microInverterShortfallKwh, greaterThan(0.0));
  });

  test('without inverterId, both banks deliver up to the battery cap (regression)', () {
    final result = const PvSimulator().run(sharedBatteryWithOptionalInverter(
      inverterMaxAcKw: 1.0,
      wireInverterIntoCoupling: false,
    ));
    final firstStep = result.steps.first;
    // Battery allows 5 kWh/h; both banks deliver their full 0.8 kWh.
    expect(firstStep.microInverterDeliveredKwh, closeTo(1.6, 1e-6));
    expect(firstStep.microInverterDeliveriesKwh[0], closeTo(0.8, 1e-6));
    expect(firstStep.microInverterDeliveriesKwh[1], closeTo(0.8, 1e-6));
  });

  test('microInverter800W role clamps the cap to 0.8 kW even if maxAcKw is higher', () {
    final result = const PvSimulator().run(sharedBatteryWithOptionalInverter(
      inverterMaxAcKw: 3.0, // would be 3 kW...
      wireInverterIntoCoupling: true,
      inverterRole: InverterRole.microInverter800W, // ...but the role clamps to 0.8 kW.
    ));
    const stepHours = 1.0;
    const clampedCapKwh = 0.8 * stepHours;
    for (final step in result.steps) {
      expect(step.microInverterDeliveredKwh, lessThanOrEqualTo(clampedCapKwh + 1e-9),
          reason: 'microInverter800W role must clamp the cap regardless of maxAcKw');
    }
  });

  test('small battery behind a large inverter is still capped by maxDischargeKw', () {
    // Regression for PR #18 P1 review: when inverterId is set, the
    // engine must enforce min(maxDischargeKw, inverter.effectiveMaxAcKw),
    // not just the inverter cap. Otherwise a 0.5 kW battery behind a
    // 10 kW inverter would over-deliver.
    final config = SimulationConfig(
      arrays: const [
        PvArray(id: 'a1', label: 'A', peakKw: 0.001, azimuthDeg: 180, tiltDeg: 35, inverterId: 'pv-inv'),
      ],
      inverters: const [
        Inverter(id: 'pv-inv', label: 'PV', maxAcKw: 10.0),
        Inverter(id: 'bat-inv', label: 'Battery', maxAcKw: 10.0, role: InverterRole.batteryCoupled),
      ],
      batteries: const [
        BatteryConfig(id: 'b1', capacityKwh: 20.0, maxChargeKw: 5.0, maxDischargeKw: 0.5, initialSocKwh: 20.0),
      ],
      microInverterBanks: const [
        MicroInverterBank(id: 'bank-a', batteryId: 'b1', count: 1, unitRatedPowerW: 800, inverterEfficiency: 1.0),
        MicroInverterBank(id: 'bank-b', batteryId: 'b1', count: 1, unitRatedPowerW: 800, inverterEfficiency: 1.0),
      ],
      topology: const TopologyGraph(batteryCouplings: [
        BatteryCouplingSpec(batteryId: 'b1', inverterId: 'bat-inv'),
      ]),
      dispatchPolicy: const ConstantFeed24hPolicy(),
      loadProfile: const LoadProfile(dailyKwh: 0),
      startDayOfYear: 355,
      days: 1,
    );
    final result = const PvSimulator().run(config);
    const stepHours = 1.0;
    const batteryCapKwh = 0.5 * stepHours;
    for (final step in result.steps) {
      expect(step.microInverterDeliveredKwh, lessThanOrEqualTo(batteryCapKwh + 1e-9),
          reason: 'cap must be min(maxDischargeKw, inverter cap), not just the inverter cap');
      expect(step.batteryDischargesKwh[0], lessThanOrEqualTo(batteryCapKwh + 1e-9));
    }
  });

  test('DC-coupled battery ignores inverterId — battery cap stays in charge', () {
    // Regression for PR #18 Copilot review: the engine must not apply an
    // inverter AC cap to a DC-coupled battery, even if a stale inverterId
    // is left on the coupling (e.g. by an older JSON file). The path is
    // not AC, so `inverterLimitW` doesn't describe it.
    final config = SimulationConfig(
      arrays: const [
        PvArray(id: 'a1', label: 'A', peakKw: 0.001, azimuthDeg: 180, tiltDeg: 35, inverterId: 'pv-inv'),
      ],
      inverters: const [
        Inverter(id: 'pv-inv', label: 'PV', maxAcKw: 10.0),
        Inverter(id: 'bat-inv', label: 'Battery', maxAcKw: 0.1, role: InverterRole.batteryCoupled),
      ],
      batteries: const [
        BatteryConfig(id: 'b1', capacityKwh: 20.0, maxChargeKw: 5.0, maxDischargeKw: 1.0, initialSocKwh: 20.0),
      ],
      microInverterBanks: const [
        MicroInverterBank(id: 'bank-a', batteryId: 'b1', count: 1, unitRatedPowerW: 800, inverterEfficiency: 1.0),
      ],
      topology: const TopologyGraph(
        dcBuses: [DcBus(id: 'dc-main')],
        batteryCouplings: [
          BatteryCouplingSpec(
            batteryId: 'b1',
            coupling: BatteryCoupling.dc,
            dcBusId: 'dc-main',
            inverterId: 'bat-inv', // stale value; must be ignored.
          ),
        ],
      ),
      dispatchPolicy: const ConstantFeed24hPolicy(),
      loadProfile: const LoadProfile(dailyKwh: 0),
      startDayOfYear: 355,
      days: 1,
    );
    final result = const PvSimulator().run(config);
    final firstStep = result.steps.first;
    // If the stale inverterId leaked into the AC cap, delivery would be
    // capped at 0.1 kWh. With the guard in place, the battery's own
    // 1.0 kW rating governs, so the 0.8 kW bank delivers in full.
    expect(firstStep.microInverterDeliveredKwh, closeTo(0.8, 1e-6));
  });
}
