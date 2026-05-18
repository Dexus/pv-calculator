import 'package:component_catalog/component_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/catalog/catalog_repository.dart';

const _seedModule = ModuleCatalogEntry(
    id: 'seed-mod', manufacturer: 'Seed', model: '400', peakKwPerModule: 0.4);
const _seedInverter = InverterCatalogEntry(
    id: 'seed-inv', manufacturer: 'Seed', model: '5kW', maxAcKw: 5);
const _seedBattery = BatteryCatalogEntry(
    id: 'seed-bat',
    manufacturer: 'Seed',
    model: '10kWh',
    capacityKwh: 10,
    maxChargeKw: 5,
    maxDischargeKw: 5);

void main() {
  test('repository merges seed + user with user winning on id collision',
      () async {
    final seed = InMemoryCatalogSource(
        const [_seedModule, _seedInverter, _seedBattery],
        writable: false);
    final user = InMemoryCatalogSource(const []);
    final repo = CatalogRepository(seedSource: seed, userSource: user);

    final modulesBefore = await repo.modules();
    expect(modulesBefore.single.peakKwPerModule, 0.4);

    await repo.addUserEntry(const ModuleCatalogEntry(
      id: 'seed-mod',
      manufacturer: 'User',
      model: '420',
      peakKwPerModule: 0.42,
    ));
    final modulesAfter = await repo.modules();
    expect(modulesAfter, hasLength(1));
    expect(modulesAfter.single.peakKwPerModule, 0.42,
        reason: 'user override beats seed on id collision');
  });

  test('addUserEntry then deleteUserEntry leaves seed visible', () async {
    final seed = InMemoryCatalogSource(const [_seedModule], writable: false);
    final user = InMemoryCatalogSource(const []);
    final repo = CatalogRepository(seedSource: seed, userSource: user);

    await repo.addUserEntry(const ModuleCatalogEntry(
      id: 'extra', manufacturer: 'U', model: 'X', peakKwPerModule: 0.5,
    ));
    expect((await repo.modules()), hasLength(2));

    await repo.deleteUserEntry('extra');
    final modules = await repo.modules();
    expect(modules, hasLength(1));
    expect(modules.single.id, 'seed-mod');
  });

  test('byKind helpers return only the requested kind', () async {
    final seed = InMemoryCatalogSource(
        const [_seedModule, _seedInverter, _seedBattery],
        writable: false);
    final user = InMemoryCatalogSource(const []);
    final repo = CatalogRepository(seedSource: seed, userSource: user);

    expect((await repo.modules()).single.id, 'seed-mod');
    expect((await repo.inverters()).single.id, 'seed-inv');
    expect((await repo.batteries()).single.id, 'seed-bat');
  });
}
