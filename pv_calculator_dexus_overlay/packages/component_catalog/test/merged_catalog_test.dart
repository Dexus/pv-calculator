import 'package:component_catalog/component_catalog.dart';
import 'package:test/test.dart';

const _m1 = ModuleCatalogEntry(
    id: 'm1', manufacturer: 'A', model: '400', peakKwPerModule: 0.4);
const _m1Override = ModuleCatalogEntry(
    id: 'm1', manufacturer: 'A', model: '420', peakKwPerModule: 0.42);
const _m2 = ModuleCatalogEntry(
    id: 'm2', manufacturer: 'B', model: '500', peakKwPerModule: 0.5);
const _i1 = InverterCatalogEntry(
    id: 'i1', manufacturer: 'I', model: '5kW', maxAcKw: 5.0);

void main() {
  test('later sources win on id collision', () async {
    final merged = MergedCatalog([
      InMemoryCatalogSource(const [_m1, _m2], writable: false),
      InMemoryCatalogSource(const [_m1Override], writable: false),
    ]);
    final all = await merged.all();
    final m1 = all.firstWhere((e) => e.id == 'm1') as ModuleCatalogEntry;
    expect(m1.peakKwPerModule, 0.42, reason: 'override beats seed');
    expect(all.where((e) => e.id == 'm1'), hasLength(1));
    expect(all, hasLength(2));
  });

  test('byKind filters across sources', () async {
    final merged = MergedCatalog([
      InMemoryCatalogSource(const [_m1, _i1], writable: false),
    ]);
    final mods = await merged.byKind<ModuleCatalogEntry>(ComponentKind.module);
    final invs = await merged.byKind<InverterCatalogEntry>(
        ComponentKind.inverter);
    expect(mods, hasLength(1));
    expect(invs, hasLength(1));
    expect(mods.single.id, 'm1');
    expect(invs.single.id, 'i1');
  });

  test('invalidate forces a refetch', () async {
    final writable = InMemoryCatalogSource(const [_m1]);
    final merged = MergedCatalog([writable]);
    expect((await merged.all()).map((e) => e.id), ['m1']);
    await writable.upsert(_m2);
    // Without invalidate, cache hides the new entry.
    expect((await merged.all()).map((e) => e.id), ['m1']);
    merged.invalidate();
    expect((await merged.all()).map((e) => e.id), containsAll(['m1', 'm2']));
  });

  test('upsert on read-only source throws', () async {
    final ro = InMemoryCatalogSource(const [_m1], writable: false);
    expect(() => ro.upsert(_m2), throwsUnsupportedError);
    expect(() => ro.delete('m1'), throwsUnsupportedError);
  });
}
