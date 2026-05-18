import 'dart:convert';

import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

/// Minimal one-day-friendly config used to keep the tariff hot-path
/// tests deterministic. Single array, single inverter, no battery so
/// every Wh of self-consumption + grid import / export comes through
/// the same path.
SimulationConfig _config({TariffConfig? tariff, TimeStep timeStep = TimeStep.hourly}) {
  return SimulationConfig(
    arrays: const [
      PvArray(
        id: 'roof',
        label: 'Roof',
        peakKw: 5.0,
        azimuthDeg: 180,
        tiltDeg: 30,
        inverterId: 'main',
      ),
    ],
    inverters: const [Inverter(id: 'main', label: 'Main', maxAcKw: 5.0)],
    loadProfile: const LoadProfile(dailyKwh: 6.0),
    days: 1,
    timeStep: timeStep,
    tariff: tariff,
  );
}

void main() {
  group('TariffConfig validation', () {
    test('flat prices must be non-negative', () {
      expect(
        () => const TariffConfig(
          importPricePerKwh: -0.01,
          exportPricePerKwh: 0.08,
        ).validate(),
        throwsArgumentError,
      );
      expect(
        () => const TariffConfig(
          importPricePerKwh: 0.30,
          exportPricePerKwh: -0.01,
        ).validate(),
        throwsArgumentError,
      );
    });

    test('hourly TOU arrays must have exactly 24 entries', () {
      final tooFew = List<double>.filled(23, 0.30);
      expect(
        () => TariffConfig(
          importPricePerKwh: 0.30,
          exportPricePerKwh: 0.08,
          hourlyImportPrices: tooFew,
        ).validate(),
        throwsArgumentError,
      );
      final tooMany = List<double>.filled(25, 0.08);
      expect(
        () => TariffConfig(
          importPricePerKwh: 0.30,
          exportPricePerKwh: 0.08,
          hourlyExportPrices: tooMany,
        ).validate(),
        throwsArgumentError,
      );
    });

    test('hourly TOU entries must be non-negative', () {
      final withNegative = List<double>.filled(24, 0.30)..[5] = -0.01;
      expect(
        () => TariffConfig(
          importPricePerKwh: 0.30,
          exportPricePerKwh: 0.08,
          hourlyImportPrices: withNegative,
        ).validate(),
        throwsArgumentError,
      );
    });

    test('flat prices reject NaN and infinity', () {
      expect(
        () => TariffConfig(
          importPricePerKwh: double.nan,
          exportPricePerKwh: 0.08,
        ).validate(),
        throwsArgumentError,
      );
      expect(
        () => TariffConfig(
          importPricePerKwh: 0.30,
          exportPricePerKwh: double.infinity,
        ).validate(),
        throwsArgumentError,
      );
    });

    test('hourly TOU entries reject NaN and infinity', () {
      final withNaN = List<double>.filled(24, 0.30)..[3] = double.nan;
      expect(
        () => TariffConfig(
          importPricePerKwh: 0.30,
          exportPricePerKwh: 0.08,
          hourlyImportPrices: withNaN,
        ).validate(),
        throwsArgumentError,
      );
      final withInf = List<double>.filled(24, 0.08)..[10] = double.infinity;
      expect(
        () => TariffConfig(
          importPricePerKwh: 0.30,
          exportPricePerKwh: 0.08,
          hourlyExportPrices: withInf,
        ).validate(),
        throwsArgumentError,
      );
    });
  });

  group('TariffConfig price lookup', () {
    test('flat tariff returns the same price at every hour', () {
      const t = TariffConfig(
        importPricePerKwh: 0.30,
        exportPricePerKwh: 0.08,
      );
      expect(t.importPriceAtHour(0.5), 0.30);
      expect(t.importPriceAtHour(23.5), 0.30);
      expect(t.exportPriceAtHour(12.5), 0.08);
    });

    test('TOU lookup slots on hour floor — quarter-hourly steps share the slot', () {
      final prices = List<double>.generate(24, (i) => 0.10 + i * 0.01);
      final t = TariffConfig(
        importPricePerKwh: 0.0,
        exportPricePerKwh: 0.0,
        hourlyImportPrices: prices,
      );
      expect(t.importPriceAtHour(7.0), prices[7]);
      expect(t.importPriceAtHour(7.25), prices[7]);
      expect(t.importPriceAtHour(7.5), prices[7]);
      expect(t.importPriceAtHour(7.75), prices[7]);
      // boundary: 8.0 must move into slot 8
      expect(t.importPriceAtHour(8.0), prices[8]);
    });

    test('TOU lookup clamps to slot 0 / 23 at extremes', () {
      final prices = List<double>.generate(24, (i) => i.toDouble());
      final t = TariffConfig(
        importPricePerKwh: 0.0,
        exportPricePerKwh: 0.0,
        hourlyImportPrices: prices,
      );
      // The engine's hourOfDay is always in [0, 24) but defend against
      // pathological callers: the clamp guarantees no out-of-bounds.
      expect(t.importPriceAtHour(-1), 0.0);
      expect(t.importPriceAtHour(100), 23.0);
    });
  });

  group('engine tariff integration', () {
    test('null tariff -> summary economics fields are null', () {
      final result = const PvSimulator().run(_config());
      expect(result.summary.importCostEur, isNull);
      expect(result.summary.exportRevenueEur, isNull);
      expect(result.summary.netCostEur, isNull);
    });

    test('flat tariff: importCost = gridImport × price; netCost = import − export', () {
      const tariff = TariffConfig(
        importPricePerKwh: 0.40,
        exportPricePerKwh: 0.10,
      );
      final result = const PvSimulator().run(_config(tariff: tariff));
      final s = result.summary;
      expect(s.importCostEur, isNotNull);
      expect(s.importCostEur!, closeTo(s.gridImportKwh * 0.40, 1e-9));
      expect(s.exportRevenueEur!, closeTo(s.gridExportKwh * 0.10, 1e-9));
      expect(s.netCostEur!, closeTo(s.importCostEur! - s.exportRevenueEur!, 1e-9));
    });

    test('TOU prices respected: hour-0-only import price shows up only in pre-dawn import', () {
      final hourly = List<double>.filled(24, 0.0);
      hourly[0] = 1.0;
      hourly[1] = 1.0;
      hourly[2] = 1.0;
      hourly[3] = 1.0;
      final tariff = TariffConfig(
        importPricePerKwh: 0.0,
        exportPricePerKwh: 0.0,
        hourlyImportPrices: hourly,
      );
      // Step through the result; we know the synthetic model produces
      // zero PV at night, so all early-hour load becomes grid import.
      final result =
          const PvSimulator().run(_config(tariff: tariff));
      var sumExpected = 0.0;
      for (final step in result.steps) {
        if (step.hourOfDay < 4.0) {
          sumExpected += step.gridImportKwh * 1.0;
        }
      }
      expect(result.summary.importCostEur, closeTo(sumExpected, 1e-9));
    });

    test('15-min step reads the same hourly tariff slot as the hour midpoint', () {
      final hourly = List<double>.generate(24, (i) => 0.10 + i * 0.01);
      final tariff = TariffConfig(
        importPricePerKwh: 0.0,
        exportPricePerKwh: 0.0,
        hourlyImportPrices: hourly,
      );
      final result = const PvSimulator()
          .run(_config(tariff: tariff, timeStep: TimeStep.quarterHourly));
      var sumExpected = 0.0;
      for (final step in result.steps) {
        final slot = step.hourOfDay.floor().clamp(0, 23);
        sumExpected += step.gridImportKwh * hourly[slot];
      }
      expect(result.summary.importCostEur, closeTo(sumExpected, 1e-9));
    });
  });

  group('JSON roundtrip', () {
    test('TariffConfig roundtrip flat', () {
      const original = TariffConfig(
        importPricePerKwh: 0.30,
        exportPricePerKwh: 0.082,
      );
      final decoded =
          TariffConfig.fromJson(jsonDecode(jsonEncode(original.toJson())));
      expect(decoded.importPricePerKwh, 0.30);
      expect(decoded.exportPricePerKwh, 0.082);
      expect(decoded.hourlyImportPrices, isNull);
      expect(decoded.hourlyExportPrices, isNull);
    });

    test('TariffConfig roundtrip TOU', () {
      final original = TariffConfig(
        importPricePerKwh: 0.30,
        exportPricePerKwh: 0.082,
        hourlyImportPrices: List<double>.generate(24, (i) => 0.10 + i * 0.01),
        hourlyExportPrices: List<double>.filled(24, 0.05),
      );
      final decoded =
          TariffConfig.fromJson(jsonDecode(jsonEncode(original.toJson())));
      expect(decoded.hourlyImportPrices, original.hourlyImportPrices);
      expect(decoded.hourlyExportPrices, original.hourlyExportPrices);
    });

    test('SimulationConfig with tariff round-trips as schema v5', () {
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
      final json = cfg.toJson();
      expect(json['schemaVersion'], 5);
      final decoded = SimulationConfig.fromJson(jsonDecode(jsonEncode(json)));
      expect(decoded.tariff, isNotNull);
      expect(decoded.tariff!.importPricePerKwh, 0.30);
    });

    test('SimulationConfig without tariff stays on a pre-v5 schema', () {
      final cfg = _config();
      final v = cfg.toJson()['schemaVersion'] as int;
      expect(v, lessThan(5));
    });

    test('SimulationSummary serializes import/export costs only when present', () {
      const withTariff = SimulationSummary(
        pvDcKwh: 0,
        pvAcKwh: 0,
        loadKwh: 0,
        selfConsumptionKwh: 0,
        batteryChargeKwh: 0,
        batteryDischargeKwh: 0,
        gridImportKwh: 100,
        gridExportKwh: 50,
        curtailedDcKwh: 0,
        curtailedAcKwh: 0,
        curtailedExportKwh: 0,
        finalBatterySocKwh: 0,
        finalBatterySocsKwh: [],
        importCostEur: 30.0,
        exportRevenueEur: 4.0,
        netCostEur: 26.0,
      );
      final json = withTariff.toJson();
      expect(json['importCostEur'], 30.0);
      expect(json['netCostEur'], 26.0);
      final decoded = SimulationSummary.fromJson(json);
      expect(decoded.importCostEur, 30.0);
      expect(decoded.netCostEur, 26.0);

      const withoutTariff = SimulationSummary(
        pvDcKwh: 0,
        pvAcKwh: 0,
        loadKwh: 0,
        selfConsumptionKwh: 0,
        batteryChargeKwh: 0,
        batteryDischargeKwh: 0,
        gridImportKwh: 100,
        gridExportKwh: 50,
        curtailedDcKwh: 0,
        curtailedAcKwh: 0,
        curtailedExportKwh: 0,
        finalBatterySocKwh: 0,
        finalBatterySocsKwh: [],
      );
      final jsonNo = withoutTariff.toJson();
      expect(jsonNo.containsKey('importCostEur'), isFalse);
      expect(jsonNo.containsKey('netCostEur'), isFalse);
    });
  });
}
