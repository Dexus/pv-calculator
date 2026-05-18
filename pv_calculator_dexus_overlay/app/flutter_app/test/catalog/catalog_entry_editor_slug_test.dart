import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/widgets/catalog/catalog_entry_editor.dart';

void main() {
  group('slugifyForCatalogId', () {
    test('lowercases and collapses non-alphanumerics to a single dash', () {
      expect(slugifyForCatalogId('Trina  Solar TSM 450W'),
          'trina-solar-tsm-450w');
    });

    test('folds German umlauts and ß to ASCII', () {
      expect(slugifyForCatalogId('Wäch tär Größe'), 'waech-taer-groesse');
    });

    test('strips leading/trailing dashes', () {
      expect(slugifyForCatalogId('  -- foo -- '), 'foo');
    });

    test('empty input yields empty slug (caller handles)', () {
      expect(slugifyForCatalogId(''), '');
      expect(slugifyForCatalogId('   '), '');
    });

    test('drops everything if no ASCII letters/digits survive', () {
      expect(slugifyForCatalogId('!@#'), '');
    });
  });

  test('addCollisionSuffix appends 4+ chars and preserves the slug', () {
    final out = addCollisionSuffix('trina-450');
    expect(out, startsWith('trina-450-'));
    expect(out.length, greaterThan('trina-450-'.length));
  });

  test('addCollisionSuffix on empty slug yields just the suffix', () {
    final out = addCollisionSuffix('');
    expect(out, isNotEmpty);
    expect(out, isNot(startsWith('-')));
  });
}
