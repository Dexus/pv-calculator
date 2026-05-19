import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

/// Phase-5 deferred — `PreRunMode.previousYearWarmUp` uses a different
/// `IrradianceSource` for the pre-run leg than for the reported year, so
/// the SOC settles on a real (but distinct) calendar year's weather.
/// See `docs/Architekturkonzept_PV_Calculator_Flutter_App.md` §6 and the
/// `ROADMAP.md` Phase-5 Verschoben entry.

const _array = PvArray(
  id: 'south',
  label: 'South',
  peakKw: 8.0,
  azimuthDeg: 180,
  tiltDeg: 35,
  inverterId: 'main',
);
const _inverter = Inverter(id: 'main', label: 'Main', maxAcKw: 10.0);
const _battery = BatteryConfig(
  id: 'b1',
  capacityKwh: 10.0,
  maxChargeKw: 5.0,
  maxDischargeKw: 5.0,
  initialSocKwh: 5.0,
);
const _idleLoad = LoadProfile(dailyKwh: 0);
const _heavyLoad = LoadProfile(dailyKwh: 40);

/// Constant-POA stub source: returns the same [WeatherSample] for every
/// `(array, time)` query. Lets a test set the warm-up year to "bright"
/// or "dark" without building a full `HorizontalIrradianceSeries`.
class _FlatSource extends IrradianceSource {
  const _FlatSource(this._poaWPerM2);
  final double _poaWPerM2;
  @override
  WeatherSample sampleFor(WeatherQuery query) =>
      WeatherSample(poaWPerM2: _poaWPerM2, ambientTempC: 20.0);
}

void main() {
  group('PreRunMode.previousYearWarmUp', () {
    test('sunny prior year raises start SOC above the configured seed', () {
      final result = PvSimulator().run(SimulationConfig(
        arrays: const [_array],
        inverters: const [_inverter],
        batteries: const [
          BatteryConfig(
            id: 'b1',
            capacityKwh: 10.0,
            maxChargeKw: 5.0,
            maxDischargeKw: 5.0,
            initialSocKwh: 0.0,
          ),
        ],
        loadProfile: _idleLoad,
        startDayOfYear: 1,
        days: 30,
        preRunDays: 30,
        preRunMode: PreRunMode.previousYearWarmUp,
        // Reported year stays on the synthetic model; pre-run sees a
        // very bright flat source so the SOC fills well above 0.
        preRunWeatherSource: const _FlatSource(900),
      ));

      final s = result.summary;
      expect(s.preRunMode, PreRunMode.previousYearWarmUp);
      expect(s.preRunActive, isTrue);
      expect(s.convergenceIterations, 1);
      expect(s.converged, isTrue);
      expect(s.startSocsUsedKwh, hasLength(1));
      expect(s.startSocsUsedKwh[0], greaterThan(0.5),
          reason:
              'warm-up against a bright prior year should raise the reported start SOC');
    });

    test('dark prior year drains the start SOC below the configured seed', () {
      final result = PvSimulator().run(SimulationConfig(
        arrays: const [_array],
        inverters: const [_inverter],
        batteries: const [_battery],
        loadProfile: _heavyLoad,
        startDayOfYear: 1,
        days: 30,
        preRunDays: 30,
        preRunMode: PreRunMode.previousYearWarmUp,
        // Pre-run sees zero PV; the heavy load drains the half-full
        // seed across 30 warm-up days.
        preRunWeatherSource: const _FlatSource(0),
      ));

      expect(result.summary.preRunActive, isTrue);
      expect(result.summary.startSocsUsedKwh[0], lessThan(5.0),
          reason: 'overcast prior year + heavy load should drain the seed SOC');
    });

    test('reported KPIs match singleWarmUp when the source is the same', () {
      // Sanity: handing the same flat source to both legs reduces to
      // `singleWarmUp` behaviour. Confirms the new branch only swaps
      // the weather during dayIndex < 0 and does not perturb anything
      // else.
      const flat = _FlatSource(500);
      final viaPrev = PvSimulator().run(const SimulationConfig(
        arrays: [_array],
        inverters: [_inverter],
        batteries: [_battery],
        loadProfile: _idleLoad,
        startDayOfYear: 1,
        days: 5,
        preRunDays: 5,
        preRunMode: PreRunMode.previousYearWarmUp,
        weatherSource: flat,
        preRunWeatherSource: flat,
      ));
      final viaSingle = PvSimulator().run(const SimulationConfig(
        arrays: [_array],
        inverters: [_inverter],
        batteries: [_battery],
        loadProfile: _idleLoad,
        startDayOfYear: 1,
        days: 5,
        preRunDays: 5,
        weatherSource: flat,
      ));
      expect(viaPrev.summary.pvAcKwh, closeTo(viaSingle.summary.pvAcKwh, 1e-9));
      expect(viaPrev.summary.gridImportKwh,
          closeTo(viaSingle.summary.gridImportKwh, 1e-9));
      expect(viaPrev.summary.startSocsUsedKwh[0],
          closeTo(viaSingle.summary.startSocsUsedKwh[0], 1e-9));
    });
  });

  group('validation', () {
    test('previousYearWarmUp without preRunWeatherSource is rejected', () {
      expect(
        () => PvSimulator().run(const SimulationConfig(
          arrays: [_array],
          inverters: [_inverter],
          batteries: [_battery],
          loadProfile: _idleLoad,
          startDayOfYear: 1,
          days: 30,
          preRunDays: 30,
          preRunMode: PreRunMode.previousYearWarmUp,
        )),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('previousYearWarmUp with preRunDays == 0 is rejected', () {
      expect(
        () => PvSimulator().run(const SimulationConfig(
          arrays: [_array],
          inverters: [_inverter],
          batteries: [_battery],
          loadProfile: _idleLoad,
          startDayOfYear: 1,
          days: 30,
          preRunDays: 0,
          preRunMode: PreRunMode.previousYearWarmUp,
          preRunWeatherSource: _FlatSource(800),
        )),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('multi-year', () {
    test('only year 0 honours the prior-year warm-up; years 1..N drop it', () {
      // Three-year run with a bright prior-year warm-up against a
      // synthetic reported year. The aggregated `preRunActive` reflects
      // the year-0 pre-run; per-year summaries show years 1..N as
      // `manual` (no pre-run).
      final result = PvSimulator().run(const SimulationConfig(
        arrays: [_array],
        inverters: [_inverter],
        batteries: [_battery],
        loadProfile: LoadProfile(dailyKwh: 5),
        days: 365,
        preRunDays: 30,
        preRunMode: PreRunMode.previousYearWarmUp,
        preRunWeatherSource: _FlatSource(900),
        simulationYears: 3,
      ));
      expect(result.summary.perYearSummaries, hasLength(3));
      expect(result.summary.preRunActive, isTrue);
      expect(result.summary.perYearSummaries[0].preRunActive, isTrue);
      expect(result.summary.perYearSummaries[1].preRunActive, isFalse);
      expect(result.summary.perYearSummaries[2].preRunActive, isFalse);
    });
  });

  group('JSON schema', () {
    test('previousYearWarmUp config bumps schemaVersion to 7', () {
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [_inverter],
        batteries: const [_battery],
        loadProfile: _idleLoad,
        days: 30,
        preRunDays: 30,
        preRunMode: PreRunMode.previousYearWarmUp,
        preRunWeatherSource: const _FlatSource(0),
      );
      final json = cfg.toJson();
      expect(json['schemaVersion'], 7);
      expect(json['preRunMode'], 'previousYearWarmUp');
      // Runtime-only — like `weatherSource`, the pre-run source must
      // not be serialised.
      expect(json.containsKey('preRunWeatherSource'), isFalse);
    });

    test('fromJson restores the mode without the runtime source', () {
      final cfg = SimulationConfig(
        arrays: const [_array],
        inverters: const [_inverter],
        batteries: const [_battery],
        loadProfile: _idleLoad,
        days: 30,
        preRunDays: 30,
        preRunMode: PreRunMode.previousYearWarmUp,
        preRunWeatherSource: const _FlatSource(0),
      );
      final decoded = SimulationConfig.fromJson(cfg.toJson());
      expect(decoded.preRunMode, PreRunMode.previousYearWarmUp);
      expect(decoded.preRunWeatherSource, isNull,
          reason:
              'pre-run source is runtime-only and must be re-supplied by the caller');
    });
  });
}
