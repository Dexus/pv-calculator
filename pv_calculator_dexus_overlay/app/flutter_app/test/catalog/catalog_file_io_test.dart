import 'package:component_catalog/component_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/persistence/catalog_file_io.dart';

void main() {
  group('assertNoDuplicateImportIds', () {
    const a = ModuleCatalogEntry(
        id: 'a', manufacturer: 'A', model: 'A', peakKwPerModule: 0.4);
    const b = ModuleCatalogEntry(
        id: 'b', manufacturer: 'B', model: 'B', peakKwPerModule: 0.4);
    const aClone = ModuleCatalogEntry(
        id: 'a',
        manufacturer: 'A second',
        model: 'A',
        peakKwPerModule: 0.5);

    test('passes for unique ids', () {
      assertNoDuplicateImportIds(const [a, b]);
    });

    test('throws ArgumentError when ids repeat', () {
      expect(() => assertNoDuplicateImportIds(const [a, aClone]),
          throwsA(isA<ArgumentError>().having(
              (e) => e.message, 'message', contains('a'))));
    });

    test('lists every duplicate id in the error message', () {
      const c = ModuleCatalogEntry(
          id: 'c', manufacturer: 'C', model: 'C', peakKwPerModule: 0.4);
      const cClone = ModuleCatalogEntry(
          id: 'c',
          manufacturer: 'C v2',
          model: 'C',
          peakKwPerModule: 0.5);
      expect(
        () => assertNoDuplicateImportIds(const [a, aClone, c, cClone]),
        throwsA(isA<ArgumentError>().having(
            (e) => e.message, 'message', allOf(contains('a'), contains('c')))),
      );
    });

    test('empty list passes', () {
      assertNoDuplicateImportIds(const []);
    });
  });
}
