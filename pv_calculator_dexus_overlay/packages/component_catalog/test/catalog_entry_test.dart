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
}
