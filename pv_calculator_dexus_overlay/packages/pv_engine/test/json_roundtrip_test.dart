import 'dart:convert';

import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

void main() {
  group('JSON roundtrip', () {
    test('PvArray', () {
      const original = PvArray(
        id: 'roof', label: 'Roof', peakKw: 4.8, azimuthDeg: 180, tiltDeg: 35,
        inverterId: 'main', lossFactor: 0.12, shadingFactor: 0.05,
      );
      final decoded = PvArray.fromJson(jsonDecode(jsonEncode(original.toJson())));
      expect(decoded.id, original.id);
      expect(decoded.label, original.label);
      expect(decoded.peakKw, original.peakKw);
      expect(decoded.azimuthDeg, original.azimuthDeg);
      expect(decoded.tiltDeg, original.tiltDeg);
      expect(decoded.inverterId, original.inverterId);
      expect(decoded.lossFactor, original.lossFactor);
      expect(decoded.shadingFactor, original.shadingFactor);
    });

    test('Inverter with each role', () {
      for (final role in InverterRole.values) {
        final original = Inverter(id: 'inv', label: 'Inv', maxAcKw: 5.0, role: role, efficiency: 0.97);
        final decoded = Inverter.fromJson(jsonDecode(jsonEncode(original.toJson())));
        expect(decoded.role, role);
        expect(decoded.maxAcKw, 5.0);
        expect(decoded.efficiency, 0.97);
      }
    });

    test('BatteryConfig', () {
      const original = BatteryConfig(
        id: 'b1', label: 'Pack 1', capacityKwh: 7.5, maxChargeKw: 3.0,
        maxDischargeKw: 3.0, roundTripEfficiency: 0.92, minSocKwh: 0.5, initialSocKwh: 4.0,
      );
      final decoded = BatteryConfig.fromJson(jsonDecode(jsonEncode(original.toJson())));
      expect(decoded.id, 'b1');
      expect(decoded.label, 'Pack 1');
      expect(decoded.capacityKwh, 7.5);
      expect(decoded.maxChargeKw, 3.0);
      expect(decoded.maxDischargeKw, 3.0);
      expect(decoded.roundTripEfficiency, 0.92);
      expect(decoded.minSocKwh, 0.5);
      expect(decoded.initialSocKwh, 4.0);
    });

    test('LoadProfile', () {
      const original = LoadProfile(dailyKwh: 10.5);
      final decoded = LoadProfile.fromJson(jsonDecode(jsonEncode(original.toJson())));
      expect(decoded.dailyKwh, 10.5);
      expect(decoded.hourlyShape, original.hourlyShape);
    });

    test('SimulationConfig — full roundtrip produces identical simulation summary', () {
      final original = _config();
      final encoded = jsonEncode(original.toJson());
      final decoded = SimulationConfig.fromJson(jsonDecode(encoded));

      final originalResult = const PvSimulator().run(original);
      final decodedResult = const PvSimulator().run(decoded);
      expect(decodedResult.summary.pvAcKwh, closeTo(originalResult.summary.pvAcKwh, 1e-9));
      expect(decodedResult.summary.gridImportKwh, closeTo(originalResult.summary.gridImportKwh, 1e-9));
      expect(decodedResult.summary.gridExportKwh, closeTo(originalResult.summary.gridExportKwh, 1e-9));
      expect(decodedResult.summary.batteryChargeKwh, closeTo(originalResult.summary.batteryChargeKwh, 1e-9));
      expect(decodedResult.summary.batteryDischargeKwh, closeTo(originalResult.summary.batteryDischargeKwh, 1e-9));
    });

    test('legacy single-"battery" key migrates to batteries list with synthetic id', () {
      final legacyJson = {
        'arrays': [_config().arrays.first.toJson()],
        'inverters': [_config().inverters.first.toJson()],
        'battery': {
          // no id, no schema version on outer config
          'capacityKwh': 5.0,
          'maxChargeKw': 2.5,
          'maxDischargeKw': 2.5,
        },
        'loadProfile': const LoadProfile(dailyKwh: 8).toJson(),
        'days': 7,
      };
      final decoded = SimulationConfig.fromJson(legacyJson);
      expect(decoded.batteries, hasLength(1));
      expect(decoded.batteries.first.id, 'battery-1');
      expect(decoded.batteries.first.capacityKwh, 5.0);
      // round-trips through the new schema cleanly
      final reencoded = SimulationConfig.fromJson(jsonDecode(jsonEncode(decoded.toJson())));
      expect(reencoded.batteries.first.id, 'battery-1');
    });

    test('unknown InverterRole throws ArgumentError', () {
      expect(
        () => Inverter.fromJson({
          'id': 'x', 'label': 'X', 'maxAcKw': 1.0, 'role': 'nonexistent', 'efficiency': 1.0,
        }),
        throwsArgumentError,
      );
    });

    test('unknown schema version throws ArgumentError', () {
      expect(
        () => SimulationConfig.fromJson({
          'schemaVersion': 99,
          'arrays': [],
          'inverters': [],
          'loadProfile': const LoadProfile(dailyKwh: 1).toJson(),
        }),
        throwsArgumentError,
      );
    });

    test('Phase-5 defaults stay on schema v1', () {
      // A vanilla config with no Phase-4 and no Phase-5 changes should
      // continue to emit schemaVersion: 1, so legacy consumers keep
      // round-tripping byte-stable JSON.
      final json = _config().toJson();
      expect(json['schemaVersion'], 1);
      expect(json.containsKey('preRunMode'), isFalse);
      expect(json.containsKey('convergenceToleranceFraction'), isFalse);
      expect(json.containsKey('maxConvergenceIterations'), isFalse);
    });

    test('cyclicConvergence config round-trips as schema v3', () {
      final cyclic = SimulationConfig(
        arrays: _config().arrays,
        inverters: _config().inverters,
        batteries: _config().batteries,
        loadProfile: _config().loadProfile,
        days: 365,
        preRunMode: PreRunMode.cyclicConvergence,
        convergenceToleranceFraction: 0.002,
        maxConvergenceIterations: 5,
      );
      final json = cyclic.toJson();
      expect(json['schemaVersion'], 3);
      expect(json['preRunMode'], 'cyclicConvergence');
      expect(json['convergenceToleranceFraction'], 0.002);
      expect(json['maxConvergenceIterations'], 5);

      final decoded = SimulationConfig.fromJson(jsonDecode(jsonEncode(json)));
      expect(decoded.preRunMode, PreRunMode.cyclicConvergence);
      expect(decoded.convergenceToleranceFraction, 0.002);
      expect(decoded.maxConvergenceIterations, 5);
    });

    test('schema v1/v2 without preRunMode defaults to singleWarmUp', () {
      // Loading a legacy JSON (no `preRunMode` key) must preserve the
      // pre-Phase-5 behaviour where `preRunDays` controls a single
      // warm-up.
      final legacy = _config().toJson();
      legacy.remove('preRunMode');
      legacy.remove('convergenceToleranceFraction');
      legacy.remove('maxConvergenceIterations');
      final decoded = SimulationConfig.fromJson(legacy);
      expect(decoded.preRunMode, PreRunMode.singleWarmUp);
      expect(decoded.convergenceToleranceFraction, 0.005);
      expect(decoded.maxConvergenceIterations, 10);
    });

    test('unknown PreRunMode value throws ArgumentError', () {
      final json = _config().toJson();
      json['schemaVersion'] = 3;
      json['preRunMode'] = 'doesNotExist';
      expect(() => SimulationConfig.fromJson(json), throwsArgumentError);
    });

    test('Phase-10 simulationYears and degradation round-trip as v4', () {
      final base = _config();
      final multi = SimulationConfig(
        arrays: [
          PvArray(
            id: base.arrays.first.id,
            label: base.arrays.first.label,
            peakKw: base.arrays.first.peakKw,
            azimuthDeg: base.arrays.first.azimuthDeg,
            tiltDeg: base.arrays.first.tiltDeg,
            inverterId: base.arrays.first.inverterId,
            degradationPctPerYear: 0.5,
          ),
          base.arrays.last,
        ],
        inverters: base.inverters,
        batteries: base.batteries,
        loadProfile: base.loadProfile,
        days: 365,
        simulationYears: 5,
      );
      final json = multi.toJson();
      expect(json['schemaVersion'], 4);
      expect(json['simulationYears'], 5);
      expect((json['arrays'] as List).first['degradationPctPerYear'], 0.5);

      final decoded = SimulationConfig.fromJson(jsonDecode(jsonEncode(json)));
      expect(decoded.simulationYears, 5);
      expect(decoded.arrays.first.degradationPctPerYear, 0.5);
      expect(decoded.arrays.last.degradationPctPerYear, 0.0);
    });

    test('legacy v1 without simulationYears defaults to 1 and degradation 0', () {
      final legacy = _config().toJson();
      expect(legacy['schemaVersion'], 1);
      expect(legacy.containsKey('simulationYears'), isFalse);
      final array = (legacy['arrays'] as List).first as Map<String, dynamic>;
      expect(array.containsKey('degradationPctPerYear'), isFalse);

      final decoded = SimulationConfig.fromJson(legacy);
      expect(decoded.simulationYears, 1);
      expect(decoded.arrays.first.degradationPctPerYear, 0.0);
    });

    test('SimulationSummary toJson / fromJson roundtrip', () {
      const summary = SimulationSummary(
        pvDcKwh: 5000,
        pvAcKwh: 4800,
        loadKwh: 3500,
        selfConsumptionKwh: 2200,
        batteryChargeKwh: 800,
        batteryDischargeKwh: 700,
        gridImportKwh: 600,
        gridExportKwh: 2100,
        curtailedDcKwh: 0,
        curtailedAcKwh: 10,
        curtailedExportKwh: 0,
        finalBatterySocKwh: 4.0,
        finalBatterySocsKwh: [2.5, 1.5],
        microInverterDeliveredKwh: 50,
        microInverterShortfallKwh: 5,
        unservedLoadKwh: 0,
        preRunActive: true,
        startSocsUsedKwh: [3.75, 1.5],
        convergenceIterations: 1,
        converged: true,
      );
      final decoded = SimulationSummary.fromJson(
          jsonDecode(jsonEncode(summary.toJson())));
      expect(decoded.pvAcKwh, 4800);
      expect(decoded.finalBatterySocsKwh, [2.5, 1.5]);
      expect(decoded.preRunActive, isTrue);
      expect(decoded.startSocsUsedKwh, [3.75, 1.5]);
      expect(decoded.perYearSummaries, isEmpty);
    });

    test('SimulationSummary with perYearSummaries roundtrips', () {
      const year0 = SimulationSummary(
        pvDcKwh: 1000, pvAcKwh: 950, loadKwh: 800, selfConsumptionKwh: 500,
        batteryChargeKwh: 0, batteryDischargeKwh: 0,
        gridImportKwh: 300, gridExportKwh: 450,
        curtailedDcKwh: 0, curtailedAcKwh: 0, curtailedExportKwh: 0,
        finalBatterySocKwh: 0, finalBatterySocsKwh: [],
      );
      const year1 = SimulationSummary(
        pvDcKwh: 995, pvAcKwh: 945, loadKwh: 800, selfConsumptionKwh: 495,
        batteryChargeKwh: 0, batteryDischargeKwh: 0,
        gridImportKwh: 305, gridExportKwh: 450,
        curtailedDcKwh: 0, curtailedAcKwh: 0, curtailedExportKwh: 0,
        finalBatterySocKwh: 0, finalBatterySocsKwh: [],
      );
      const total = SimulationSummary(
        pvDcKwh: 1995, pvAcKwh: 1895, loadKwh: 1600, selfConsumptionKwh: 995,
        batteryChargeKwh: 0, batteryDischargeKwh: 0,
        gridImportKwh: 605, gridExportKwh: 900,
        curtailedDcKwh: 0, curtailedAcKwh: 0, curtailedExportKwh: 0,
        finalBatterySocKwh: 0, finalBatterySocsKwh: [],
        perYearSummaries: [year0, year1],
      );
      final decoded = SimulationSummary.fromJson(
          jsonDecode(jsonEncode(total.toJson())));
      expect(decoded.perYearSummaries, hasLength(2));
      expect(decoded.perYearSummaries[0].pvAcKwh, 950);
      expect(decoded.perYearSummaries[1].gridImportKwh, 305);
    });

    test('chargeControllers at top level round-trip as schema v6', () {
      final base = _config();
      final dcConfig = SimulationConfig(
        arrays: base.arrays,
        inverters: base.inverters,
        batteries: base.batteries,
        loadProfile: base.loadProfile,
        days: base.days,
        chargeControllers: const [
          ChargeController(id: 'cc-1', dcBusId: 'dc-main', efficiency: 0.97, maxInputKw: 5.0),
        ],
      );
      final json = dcConfig.toJson();
      expect(json['schemaVersion'], 6);
      expect((json['chargeControllers'] as List).single['id'], 'cc-1');
      final decoded = SimulationConfig.fromJson(jsonDecode(jsonEncode(json)));
      expect(decoded.chargeControllers.single.id, 'cc-1');
      expect(decoded.chargeControllers.single.dcBusId, 'dc-main');
      expect(decoded.chargeControllers.single.efficiency, closeTo(0.97, 1e-9));
      expect(decoded.chargeControllers.single.maxInputKw, closeTo(5.0, 1e-9));
    });

    test('DcBus.batteryFed mode inside topology triggers schema v6', () {
      final base = _config();
      const topo = TopologyGraph(
        dcBuses: [DcBus(id: 'dc-main', mode: BusMode.batteryFed)],
        chargeControllers: [
          ChargeController(id: 'cc-1', dcBusId: 'dc-main', efficiency: 0.97),
        ],
        acBuses: [AcBus(id: 'ac-main')],
      );
      final cfg = SimulationConfig(
        arrays: base.arrays,
        inverters: base.inverters,
        batteries: base.batteries,
        loadProfile: base.loadProfile,
        days: base.days,
        topology: topo,
      );
      final json = cfg.toJson();
      expect(json['schemaVersion'], 6);
      final decoded = SimulationConfig.fromJson(jsonDecode(jsonEncode(json)));
      expect(decoded.topology!.dcBuses.single.mode, BusMode.batteryFed);
      expect(decoded.topology!.chargeControllers.single.id, 'cc-1');
    });

    test('topology with no DC-coupling fields still round-trips on its old schema', () {
      // Sanity: setting only legacy Phase-4 topology must NOT bump to v6.
      final base = _config();
      const topo = TopologyGraph(
        dcBuses: [DcBus(id: 'dc-main')],
        acBuses: [AcBus(id: 'ac-main')],
      );
      final cfg = SimulationConfig(
        arrays: base.arrays,
        inverters: base.inverters,
        batteries: base.batteries,
        loadProfile: base.loadProfile,
        days: base.days,
        topology: topo,
      );
      expect(cfg.toJson()['schemaVersion'], 2);
    });

    test('topology + top-level chargeControllers is rejected (single source of truth)', () {
      final base = _config();
      const topo = TopologyGraph(
        dcBuses: [DcBus(id: 'dc-main')],
        acBuses: [AcBus(id: 'ac-main')],
      );
      final cfg = SimulationConfig(
        arrays: base.arrays,
        inverters: base.inverters,
        batteries: base.batteries,
        loadProfile: base.loadProfile,
        days: base.days,
        topology: topo,
        chargeControllers: const [
          ChargeController(id: 'cc-1', dcBusId: 'dc-main'),
        ],
      );
      expect(cfg.validate, throwsArgumentError);
    });

    test('top-level chargeControllers validate against legacy auto-generated dc bus ids', () {
      final base = _config();
      // Inverter id is 'main' ⇒ legacy fromLegacy produces dc bus 'dc-main'.
      final ok = SimulationConfig(
        arrays: base.arrays,
        inverters: base.inverters,
        batteries: base.batteries,
        loadProfile: base.loadProfile,
        days: base.days,
        chargeControllers: const [
          ChargeController(id: 'cc-1', dcBusId: 'dc-main'),
        ],
      );
      expect(ok.validate, returnsNormally);
      // A mistyped dc bus id must fail.
      final broken = SimulationConfig(
        arrays: base.arrays,
        inverters: base.inverters,
        batteries: base.batteries,
        loadProfile: base.loadProfile,
        days: base.days,
        chargeControllers: const [
          ChargeController(id: 'cc-1', dcBusId: 'dc-phantom'),
        ],
      );
      expect(broken.validate, throwsArgumentError);
    });
  });
}

SimulationConfig _config() => SimulationConfig(
      arrays: const [
        PvArray(id: 'south-roof', label: 'Süddach', peakKw: 4.8, azimuthDeg: 180, tiltDeg: 35, inverterId: 'main'),
        PvArray(id: 'balcony', label: 'Balkon', peakKw: 1.2, azimuthDeg: 180, tiltDeg: 30, inverterId: 'micro'),
      ],
      inverters: const [
        Inverter(id: 'main', label: 'Main', maxAcKw: 5.0),
        Inverter(id: 'micro', label: 'Micro', maxAcKw: 0.8, role: InverterRole.microInverter800W),
      ],
      batteries: const [
        BatteryConfig(id: 'main', capacityKwh: 7.5, maxChargeKw: 3.0, maxDischargeKw: 3.0, minSocKwh: 0.5),
        BatteryConfig(id: 'secondary', capacityKwh: 3.0, maxChargeKw: 1.5, maxDischargeKw: 1.5),
      ],
      loadProfile: const LoadProfile(dailyKwh: 10.5),
      days: 30,
      preRunDays: 7,
      gridExportLimitKw: 6.0,
      latitudeDeg: 50.1,
    );
