import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

/// Per-step energy conservation invariant (NFR-02 from the PRD: energy
/// balance error must stay under 0.1% per year).
///
/// On the AC household bus:
///   In:  pvAc + batteryDirectDischarge + bankAcDelivered + gridImport
///   Out: load + batteryCharge + gridExport + curtailedExport + unservedLoad
///
/// `batteryDischargesKwh` already contains the bank contributions
/// (the router attributes bank AC delivery back to its source battery),
/// so the residual is computed against the direct portion only.
double _balance(SimulationStep s) {
  // Direct discharge = total discharge minus bank deliveries (banks
  // already booked their AC to the battery as discharge).
  final bankAc = s.microInverterDeliveredKwh;
  final directDischarge = s.batteryDischargeKwh - bankAc;
  final inflow = s.pvAcKwh + directDischarge + bankAc + s.gridImportKwh;
  final outflow = s.loadKwh + s.batteryChargeKwh + s.gridExportKwh + s.curtailedExportKwh + s.unservedLoadKwh;
  return inflow - outflow;
}

SimulationConfig _scaffold({
  required DispatchPolicy? policy,
  required List<MicroInverterBank> banks,
  required List<BatteryConfig> batteries,
  required double load,
}) =>
    SimulationConfig(
      arrays: const [
        PvArray(id: 'a', label: 'A', peakKw: 5.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'inv'),
        PvArray(id: 'b', label: 'B', peakKw: 3.0, azimuthDeg: 270, tiltDeg: 35, inverterId: 'inv'),
      ],
      inverters: const [Inverter(id: 'inv', label: 'Inv', maxAcKw: 6.0)],
      batteries: batteries,
      microInverterBanks: banks,
      dispatchPolicy: policy,
      loadProfile: LoadProfile(dailyKwh: load),
      gridExportLimitKw: 4.0,
      startDayOfYear: 172,
      days: 3,
    );

void main() {
  group('energy conservation per step', () {
    final scenarios = <(String, SimulationConfig)>[
      (
        'SelfConsumptionFirst, single battery, no banks',
        _scaffold(
          policy: null,
          banks: const [],
          batteries: const [BatteryConfig(id: 'b', capacityKwh: 4, maxChargeKw: 3, maxDischargeKw: 3)],
          load: 6,
        ),
      ),
      (
        'BatteryReserve, two batteries, no banks',
        _scaffold(
          policy: const BatteryReservePolicy(reserveSocFraction: 0.6),
          banks: const [],
          batteries: const [
            BatteryConfig(id: 'a', capacityKwh: 4, maxChargeKw: 2, maxDischargeKw: 2),
            BatteryConfig(id: 'b', capacityKwh: 2, maxChargeKw: 2, maxDischargeKw: 2),
          ],
          load: 5,
        ),
      ),
      (
        'ConstantFeed24h with one bank',
        _scaffold(
          policy: const ConstantFeed24hPolicy(),
          banks: const [
            MicroInverterBank(
              id: 'bank-1', batteryId: 'b', count: 1, unitRatedPowerW: 800,
              minSocShutdown: 0.1, inverterEfficiency: 0.95,
            ),
          ],
          batteries: const [BatteryConfig(id: 'b', capacityKwh: 8, maxChargeKw: 3, maxDischargeKw: 3)],
          load: 4,
        ),
      ),
      (
        'GridAssist islanded',
        _scaffold(
          policy: const GridAssistPolicy(allowGridImport: false),
          banks: const [],
          batteries: const [BatteryConfig(id: 'b', capacityKwh: 2, maxChargeKw: 2, maxDischargeKw: 2)],
          load: 5,
        ),
      ),
    ];

    for (final (name, cfg) in scenarios) {
      test(name, () {
        final result = const PvSimulator().run(cfg);
        for (final step in result.steps) {
          expect(_balance(step).abs(), lessThan(1e-6),
              reason: 'imbalance ${_balance(step)} at step ${step.dayIndex}/${step.stepOfDay}');
          expect(step.batterySocsKwh.every((s) => s >= -1e-9), isTrue,
              reason: 'SOC went negative at ${step.dayIndex}/${step.stepOfDay}');
        }
      });
    }
  });
}
