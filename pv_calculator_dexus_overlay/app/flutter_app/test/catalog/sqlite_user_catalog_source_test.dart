import 'package:component_catalog/component_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/catalog/sqlite_user_catalog_source.dart';
import 'package:pv_calculator_app/persistence/database.dart';

void main() {
  group('SqliteUserCatalogSource', () {
    late AppDatabase db;
    late SqliteUserCatalogSource source;

    setUp(() {
      db = AppDatabase.memory();
      source = SqliteUserCatalogSource(db);
    });

    tearDown(() => db.close());

    test('isWritable is true', () {
      expect(source.isWritable, isTrue);
    });

    test('upsert then fetch round-trips a module entry', () async {
      const entry = ModuleCatalogEntry(
        id: 'user-mod-1',
        manufacturer: 'Acme',
        model: 'X 450',
        peakKwPerModule: 0.45,
        cellTechnology: 'TOPCon',
      );
      await source.upsert(entry);
      final all = await source.fetch();
      expect(all, hasLength(1));
      final fetched = all.single as ModuleCatalogEntry;
      expect(fetched.id, entry.id);
      expect(fetched.peakKwPerModule, entry.peakKwPerModule);
      expect(fetched.cellTechnology, entry.cellTechnology);
    });

    test('upsert with same id updates in place', () async {
      const a = InverterCatalogEntry(
          id: 'i', manufacturer: 'A', model: 'B', maxAcKw: 5);
      const b = InverterCatalogEntry(
          id: 'i', manufacturer: 'A', model: 'B v2', maxAcKw: 8);
      await source.upsert(a);
      await source.upsert(b);
      final all = await source.fetch();
      expect(all, hasLength(1));
      expect((all.single as InverterCatalogEntry).maxAcKw, 8);
    });

    test('delete removes the row', () async {
      const entry = BatteryCatalogEntry(
        id: 'b1',
        manufacturer: 'A',
        model: 'B',
        capacityKwh: 10,
        maxChargeKw: 5,
        maxDischargeKw: 5,
      );
      await source.upsert(entry);
      expect((await source.fetch()), hasLength(1));
      await source.delete('b1');
      expect((await source.fetch()), isEmpty);
    });

    test('rejects entries that fail validation', () async {
      const bad = ModuleCatalogEntry(
        id: 'bad', manufacturer: 'A', model: 'B', peakKwPerModule: 0,
      );
      expect(() => source.upsert(bad), throwsArgumentError);
    });
  });
}
