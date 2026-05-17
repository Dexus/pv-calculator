import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

/// Golden scenarios for the Phase 5 pre-run modes. See:
///   docs/PRD_PV_Calculator_Flutter_App.md §6.2
///   docs/Architekturkonzept_PV_Calculator_Flutter_App.md §6
///   pv_calculator_dexus_overlay/docs/ROADMAP.md §Phase 5
const _sunnyArray = PvArray(
  id: 'south',
  label: 'South',
  peakKw: 8.0,
  azimuthDeg: 180,
  tiltDeg: 35,
  inverterId: 'main',
);
const _tinyArray = PvArray(
  id: 'tiny',
  label: 'Tiny',
  peakKw: 0.001,
  azimuthDeg: 180,
  tiltDeg: 35,
  inverterId: 'main',
);
const _mainInverter = Inverter(id: 'main', label: 'Main', maxAcKw: 10.0);
const _bigInverter = Inverter(id: 'main', label: 'Main', maxAcKw: 20.0);
const _emptyLoad = LoadProfile(dailyKwh: 0);
const _heavyLoad = LoadProfile(dailyKwh: 40);

void main() {
  group('PreRunMode.manual', () {
    test('reports start SOC equal to BatteryConfig.initialSocKwh', () {
      const startSoc = 5.0;
      final result = const PvSimulator().run(const SimulationConfig(
        arrays: [_sunnyArray],
        inverters: [_mainInverter],
        batteries: [
          BatteryConfig(
            id: 'b1',
            capacityKwh: 10.0,
            maxChargeKw: 5.0,
            maxDischargeKw: 5.0,
            initialSocKwh: startSoc,
          ),
        ],
        loadProfile: _emptyLoad,
        startDayOfYear: 172,
        days: 1,
        preRunMode: PreRunMode.manual,
        // preRunDays must be ignored in manual mode.
        preRunDays: 30,
      ));

      final s = result.summary;
      expect(s.preRunMode, PreRunMode.manual);
      expect(s.preRunActive, isFalse);
      expect(s.convergenceIterations, 0);
      expect(s.converged, isTrue);
      expect(s.startSocsUsedKwh, hasLength(1));
      expect(s.startSocsUsedKwh[0], closeTo(startSoc, 1e-9));
    });
  });

  group('PreRunMode.singleWarmUp', () {
    test('empty battery accumulates non-zero start SOC after warm-up', () {
      // Empty start, sunny synthetic year, idle load: the warm-up year
      // should push the SOC up so the reported year starts non-empty.
      final withWarmUp = const PvSimulator().run(const SimulationConfig(
        arrays: [_sunnyArray],
        inverters: [_mainInverter],
        batteries: [
          BatteryConfig(
            id: 'b1',
            capacityKwh: 10.0,
            maxChargeKw: 5.0,
            maxDischargeKw: 5.0,
            initialSocKwh: 0.0,
          ),
        ],
        loadProfile: _emptyLoad,
        startDayOfYear: 1,
        days: 365,
        preRunDays: 365,
      ));

      final withoutWarmUp = const PvSimulator().run(const SimulationConfig(
        arrays: [_sunnyArray],
        inverters: [_mainInverter],
        batteries: [
          BatteryConfig(
            id: 'b1',
            capacityKwh: 10.0,
            maxChargeKw: 5.0,
            maxDischargeKw: 5.0,
            initialSocKwh: 0.0,
          ),
        ],
        loadProfile: _emptyLoad,
        startDayOfYear: 1,
        days: 365,
        preRunDays: 0,
      ));

      expect(withWarmUp.summary.preRunActive, isTrue);
      expect(withWarmUp.summary.preRunMode, PreRunMode.singleWarmUp);
      expect(withWarmUp.summary.convergenceIterations, 1);
      expect(withWarmUp.summary.converged, isTrue);
      expect(withWarmUp.summary.startSocsUsedKwh[0], greaterThan(0.5),
          reason: 'warm-up should raise the reported start SOC above the empty seed');
      expect(withoutWarmUp.summary.preRunActive, isFalse);
      expect(withoutWarmUp.summary.startSocsUsedKwh[0], closeTo(0.0, 1e-9));
    });

    test('full battery + heavy load: warm-up drains the start SOC', () {
      // Full start, almost no PV, heavy load. The warm-up should drain
      // the battery so the reported year starts below 50 %.
      final result = const PvSimulator().run(const SimulationConfig(
        arrays: [_tinyArray],
        inverters: [_mainInverter],
        batteries: [
          BatteryConfig(
            id: 'b1',
            capacityKwh: 10.0,
            maxChargeKw: 5.0,
            maxDischargeKw: 5.0,
            initialSocKwh: 10.0,
          ),
        ],
        loadProfile: _heavyLoad,
        startDayOfYear: 1,
        days: 30,
        preRunDays: 30,
      ));

      expect(result.summary.preRunActive, isTrue);
      expect(result.summary.startSocsUsedKwh[0], lessThan(10.0),
          reason: 'warm-up should drain the initially-full battery');
    });

    test('preRunDays == 0 keeps preRunActive false and iterations == 0', () {
      final result = const PvSimulator().run(const SimulationConfig(
        arrays: [_sunnyArray],
        inverters: [_mainInverter],
        batteries: [
          BatteryConfig(
            id: 'b1',
            capacityKwh: 10.0,
            maxChargeKw: 5.0,
            maxDischargeKw: 5.0,
            initialSocKwh: 3.0,
          ),
        ],
        loadProfile: _emptyLoad,
        startDayOfYear: 172,
        days: 1,
        preRunDays: 0,
      ));

      expect(result.summary.preRunActive, isFalse);
      expect(result.summary.convergenceIterations, 0);
      expect(result.summary.startSocsUsedKwh[0], closeTo(3.0, 1e-9));
    });
  });

  group('PreRunMode.cyclicConvergence', () {
    test('converges within max iterations and reports startSocsUsedKwh', () {
      final result = const PvSimulator().run(const SimulationConfig(
        arrays: [_sunnyArray],
        inverters: [_bigInverter],
        batteries: [
          BatteryConfig(
            id: 'b1',
            capacityKwh: 10.0,
            maxChargeKw: 5.0,
            maxDischargeKw: 5.0,
            initialSocKwh: 0.0,
          ),
        ],
        loadProfile: LoadProfile(dailyKwh: 10),
        startDayOfYear: 1,
        days: 365,
        preRunMode: PreRunMode.cyclicConvergence,
        convergenceToleranceFraction: 0.01,
        maxConvergenceIterations: 10,
      ));

      final s = result.summary;
      expect(s.preRunMode, PreRunMode.cyclicConvergence);
      expect(s.preRunActive, isTrue);
      expect(s.converged, isTrue,
          reason: 'a sunny+modest-load config should converge well below 10 cycles');
      expect(s.convergenceIterations, inInclusiveRange(1, 10));
      expect(s.startSocsUsedKwh, hasLength(1));
      final usable = 10.0; // capacity - minSoc
      expect((s.finalBatterySocsKwh[0] - s.startSocsUsedKwh[0]).abs(),
          lessThanOrEqualTo(0.01 * usable + 1e-9),
          reason: 'final SOC must be within tolerance of start SOC after convergence');
    });

    test('reports converged=false when maxConvergenceIterations is too low', () {
      // A single iteration cannot satisfy a tiny tolerance starting from 0 %.
      final result = const PvSimulator().run(const SimulationConfig(
        arrays: [_sunnyArray],
        inverters: [_bigInverter],
        batteries: [
          BatteryConfig(
            id: 'b1',
            capacityKwh: 10.0,
            maxChargeKw: 5.0,
            maxDischargeKw: 5.0,
            initialSocKwh: 0.0,
          ),
        ],
        loadProfile: LoadProfile(dailyKwh: 10),
        startDayOfYear: 1,
        days: 365,
        preRunMode: PreRunMode.cyclicConvergence,
        convergenceToleranceFraction: 1e-9,
        maxConvergenceIterations: 1,
      ));

      expect(result.summary.converged, isFalse);
      expect(result.summary.convergenceIterations, 1);
      expect(result.steps, isNotEmpty,
          reason: 'non-converged runs still return the last cycle so users see something');
    });

    test('zero-battery config is trivially converged', () {
      final result = const PvSimulator().run(const SimulationConfig(
        arrays: [_sunnyArray],
        inverters: [_bigInverter],
        batteries: [],
        loadProfile: LoadProfile(dailyKwh: 10),
        startDayOfYear: 1,
        days: 365,
        preRunMode: PreRunMode.cyclicConvergence,
      ));

      expect(result.summary.converged, isTrue);
      expect(result.summary.preRunActive, isFalse);
      expect(result.summary.startSocsUsedKwh, isEmpty);
    });

    test('SOC never breaches battery limits during a cyclic run', () {
      final result = const PvSimulator().run(const SimulationConfig(
        arrays: [_sunnyArray],
        inverters: [_bigInverter],
        batteries: [
          BatteryConfig(
            id: 'b1',
            capacityKwh: 10.0,
            minSocKwh: 1.0,
            maxChargeKw: 5.0,
            maxDischargeKw: 5.0,
            initialSocKwh: 5.0,
          ),
        ],
        loadProfile: LoadProfile(dailyKwh: 10),
        startDayOfYear: 1,
        days: 365,
        preRunMode: PreRunMode.cyclicConvergence,
      ));

      for (final step in result.steps) {
        expect(step.batterySocsKwh[0], greaterThanOrEqualTo(1.0 - 1e-9));
        expect(step.batterySocsKwh[0], lessThanOrEqualTo(10.0 + 1e-9));
      }
    });
  });

  group('validation', () {
    test('cyclicConvergence rejects days != 365', () {
      expect(
        () => const PvSimulator().run(const SimulationConfig(
          arrays: [_sunnyArray],
          inverters: [_mainInverter],
          loadProfile: _emptyLoad,
          days: 30,
          preRunMode: PreRunMode.cyclicConvergence,
        )),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('cyclicConvergence rejects preRunDays > 0', () {
      expect(
        () => const PvSimulator().run(const SimulationConfig(
          arrays: [_sunnyArray],
          inverters: [_mainInverter],
          loadProfile: _emptyLoad,
          days: 365,
          preRunDays: 10,
          preRunMode: PreRunMode.cyclicConvergence,
        )),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects tolerance outside (0, 1]', () {
      expect(
        () => const PvSimulator().run(const SimulationConfig(
          arrays: [_sunnyArray],
          inverters: [_mainInverter],
          loadProfile: _emptyLoad,
          days: 365,
          preRunMode: PreRunMode.cyclicConvergence,
          convergenceToleranceFraction: 0,
        )),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => const PvSimulator().run(const SimulationConfig(
          arrays: [_sunnyArray],
          inverters: [_mainInverter],
          loadProfile: _emptyLoad,
          days: 365,
          preRunMode: PreRunMode.cyclicConvergence,
          convergenceToleranceFraction: 1.5,
        )),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects maxConvergenceIterations < 1', () {
      expect(
        () => const PvSimulator().run(const SimulationConfig(
          arrays: [_sunnyArray],
          inverters: [_mainInverter],
          loadProfile: _emptyLoad,
          days: 365,
          preRunMode: PreRunMode.cyclicConvergence,
          maxConvergenceIterations: 0,
        )),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
