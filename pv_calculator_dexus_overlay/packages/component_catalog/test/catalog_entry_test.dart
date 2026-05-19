import 'package:component_catalog/component_catalog.dart';
import 'package:test/test.dart';

void main() {
  group('ModuleCatalogEntry', () {
    test('JSON round-trips losslessly', () {
      const entry = ModuleCatalogEntry(
        id: 'm1',
        manufacturer: 'Acme',
        model: 'X 400',
        peakKwPerModule: 0.4,
        cellTechnology: 'Mono PERC',
        temperatureCoefficientPctPerC: -0.35,
        nominalOperatingCellTempC: 45.0,
        degradationPctPerYear: 0.5,
        sourceUrl: 'https://example.com/datasheet.pdf',
        notes: 'a note',
      );
      final decoded = CatalogEntry.fromJson(entry.toJson()) as ModuleCatalogEntry;
      expect(decoded.id, entry.id);
      expect(decoded.peakKwPerModule, entry.peakKwPerModule);
      expect(decoded.cellTechnology, entry.cellTechnology);
      expect(decoded.degradationPctPerYear, entry.degradationPctPerYear);
      expect(decoded.sourceUrl, entry.sourceUrl);
      expect(decoded.notes, entry.notes);
    });

    test('validate rejects zero peakKw and out-of-range degradation', () {
      expect(
          () => const ModuleCatalogEntry(
                id: 'm', manufacturer: 'a', model: 'b', peakKwPerModule: 0,
              ).validate(),
          throwsArgumentError);
      expect(
          () => const ModuleCatalogEntry(
                id: 'm', manufacturer: 'a', model: 'b', peakKwPerModule: 0.4,
                degradationPctPerYear: 10,
              ).validate(),
          throwsArgumentError);
    });
  });

  group('InverterCatalogEntry', () {
    test('role is preserved across JSON', () {
      const entry = InverterCatalogEntry(
        id: 'i', manufacturer: 'a', model: 'b',
        maxAcKw: 0.8, role: CatalogInverterRole.microInverter800W,
      );
      final decoded =
          CatalogEntry.fromJson(entry.toJson()) as InverterCatalogEntry;
      expect(decoded.role, CatalogInverterRole.microInverter800W);
    });

    test('validate rejects out-of-range efficiency', () {
      expect(
          () => const InverterCatalogEntry(
                id: 'i', manufacturer: 'a', model: 'b',
                maxAcKw: 5, efficiency: 1.2,
              ).validate(),
          throwsArgumentError);
    });
  });

  group('BatteryCatalogEntry', () {
    test('minSocKwh must be < capacityKwh', () {
      expect(
          () => const BatteryCatalogEntry(
                id: 'b', manufacturer: 'a', model: 'b',
                capacityKwh: 5, maxChargeKw: 2, maxDischargeKw: 2,
                minSocKwh: 5,
              ).validate(),
          throwsArgumentError);
    });
  });

  test('CatalogEntry.fromJson dispatches by kind', () {
    final inv = CatalogEntry.fromJson({
      'kind': 'inverter',
      'id': 'i', 'manufacturer': 'a', 'model': 'b', 'maxAcKw': 5,
    });
    expect(inv, isA<InverterCatalogEntry>());
    final bat = CatalogEntry.fromJson({
      'kind': 'battery',
      'id': 'b', 'manufacturer': 'a', 'model': 'c',
      'capacityKwh': 5, 'maxChargeKw': 2, 'maxDischargeKw': 2,
    });
    expect(bat, isA<BatteryCatalogEntry>());
  });

  test('CatalogEntry.fromJson rejects unknown kind', () {
    expect(
        () => CatalogEntry.fromJson({
              'kind': 'mystery',
              'id': 'x', 'manufacturer': 'a', 'model': 'b',
            }),
        throwsArgumentError);
  });

  group('unitPriceEur', () {
    test('round-trips on every entry kind when set', () {
      const module = ModuleCatalogEntry(
        id: 'm', manufacturer: 'a', model: 'b', peakKwPerModule: 0.4,
        unitPriceEur: 80.0,
      );
      const inverter = InverterCatalogEntry(
        id: 'i', manufacturer: 'a', model: 'b', maxAcKw: 5.0,
        unitPriceEur: 950.0,
      );
      const battery = BatteryCatalogEntry(
        id: 'b', manufacturer: 'a', model: 'b',
        capacityKwh: 5.0, maxChargeKw: 2.5, maxDischargeKw: 2.5,
        unitPriceEur: 2500.0,
      );
      const controller = ChargeControllerCatalogEntry(
        id: 'c', manufacturer: 'a', model: 'b',
        unitPriceEur: 180.0,
      );
      expect(
          (CatalogEntry.fromJson(module.toJson()) as ModuleCatalogEntry)
              .unitPriceEur,
          80.0);
      expect(
          (CatalogEntry.fromJson(inverter.toJson()) as InverterCatalogEntry)
              .unitPriceEur,
          950.0);
      expect(
          (CatalogEntry.fromJson(battery.toJson()) as BatteryCatalogEntry)
              .unitPriceEur,
          2500.0);
      expect(
          (CatalogEntry.fromJson(controller.toJson())
                  as ChargeControllerCatalogEntry)
              .unitPriceEur,
          180.0);
    });

    test('round-trips as null when omitted', () {
      const module = ModuleCatalogEntry(
        id: 'm', manufacturer: 'a', model: 'b', peakKwPerModule: 0.4,
      );
      final json = module.toJson();
      expect(json.containsKey('unitPriceEur'), isFalse,
          reason: 'null price must not be emitted into JSON');
      final decoded = CatalogEntry.fromJson(json) as ModuleCatalogEntry;
      expect(decoded.unitPriceEur, isNull);
    });

    test('validate rejects negative, NaN, infinite prices', () {
      for (final bad in [-1.0, double.nan, double.infinity]) {
        expect(
            () => ModuleCatalogEntry(
                  id: 'm', manufacturer: 'a', model: 'b',
                  peakKwPerModule: 0.4, unitPriceEur: bad,
                ).validate(),
            throwsArgumentError,
            reason: 'module: $bad must throw');
        expect(
            () => InverterCatalogEntry(
                  id: 'i', manufacturer: 'a', model: 'b',
                  maxAcKw: 5.0, unitPriceEur: bad,
                ).validate(),
            throwsArgumentError,
            reason: 'inverter: $bad must throw');
        expect(
            () => BatteryCatalogEntry(
                  id: 'b', manufacturer: 'a', model: 'b',
                  capacityKwh: 5.0, maxChargeKw: 2.5, maxDischargeKw: 2.5,
                  unitPriceEur: bad,
                ).validate(),
            throwsArgumentError,
            reason: 'battery: $bad must throw');
        expect(
            () => ChargeControllerCatalogEntry(
                  id: 'c', manufacturer: 'a', model: 'b',
                  unitPriceEur: bad,
                ).validate(),
            throwsArgumentError,
            reason: 'controller: $bad must throw');
      }
    });

    test('validate accepts zero (free / promo)', () {
      const m = ModuleCatalogEntry(
        id: 'm', manufacturer: 'a', model: 'b',
        peakKwPerModule: 0.4, unitPriceEur: 0.0,
      );
      expect(m.validate, returnsNormally);
    });
  });
}
