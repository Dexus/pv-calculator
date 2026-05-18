import 'dart:convert';

import 'package:component_catalog/component_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/catalog/catalog_repository.dart';

const _seedModule = ModuleCatalogEntry(
    id: 'seed-mod', manufacturer: 'Seed', model: '400', peakKwPerModule: 0.4);
const _seedInverter = InverterCatalogEntry(
    id: 'seed-inv', manufacturer: 'Seed', model: '5kW', maxAcKw: 5);
const _userBattery = BatteryCatalogEntry(
    id: 'user-bat',
    manufacturer: 'User',
    model: '10kWh',
    capacityKwh: 10,
    maxChargeKw: 5,
    maxDischargeKw: 5);

CatalogRepository _repo({
  List<CatalogEntry> seed = const [],
  List<CatalogEntry> user = const [],
}) {
  return CatalogRepository(
    seedSource: InMemoryCatalogSource(seed, writable: false),
    userSource: InMemoryCatalogSource(user),
  );
}

void main() {
  test('userEntries() returns only user-source rows', () async {
    final repo = _repo(
        seed: const [_seedModule, _seedInverter], user: const [_userBattery]);
    final users = await repo.userEntries();
    expect(users, hasLength(1));
    expect(users.single.id, 'user-bat');
  });

  test('seedEntries() returns only seed-source rows', () async {
    final repo = _repo(
        seed: const [_seedModule, _seedInverter], user: const [_userBattery]);
    final seeds = await repo.seedEntries();
    expect(seeds.map((e) => e.id), unorderedEquals(['seed-mod', 'seed-inv']));
  });

  test('exportUserCatalogJson() produces a seed-shaped document', () async {
    final repo =
        _repo(seed: const [_seedModule], user: const [_userBattery]);
    final jsonText = await repo.exportUserCatalogJson();
    final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
    expect(decoded['version'], 1);
    expect((decoded['modules'] as List), isEmpty);
    expect((decoded['inverters'] as List), isEmpty);
    final batteries = decoded['batteries'] as List;
    expect(batteries, hasLength(1));
    expect((batteries.single as Map)['id'], 'user-bat');
    expect((batteries.single as Map).containsKey('kind'), isFalse,
        reason: 'kind discriminator must be stripped from sectioned output');
  });

  test('exportUserCatalogJson() excludes seed entries entirely', () async {
    final repo = _repo(
        seed: const [_seedModule, _seedInverter], user: const []);
    final jsonText = await repo.exportUserCatalogJson();
    final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
    for (final section in ['modules', 'inverters', 'batteries']) {
      expect(decoded[section], isEmpty,
          reason: '$section section must not leak seed entries');
    }
  });

  test('export → parseSeedCatalog round-trips user entries', () async {
    const module = ModuleCatalogEntry(
        id: 'm', manufacturer: 'M', model: 'X', peakKwPerModule: 0.45);
    const inverter = InverterCatalogEntry(
        id: 'i', manufacturer: 'I', model: 'Y', maxAcKw: 7);
    final repo = _repo(user: const [module, inverter, _userBattery]);
    final exported = await repo.exportUserCatalogJson();
    final parsed = parseSeedCatalog(exported);
    expect(parsed, hasLength(3));
    final ids = parsed.map((e) => e.id).toList();
    expect(ids, containsAll(['m', 'i', 'user-bat']));
  });

  test('importUserEntries([]) is a no-op and does not notify', () async {
    final repo = _repo();
    var notifications = 0;
    repo.addListener(() => notifications++);
    final counts = await repo.importUserEntries(const []);
    expect(counts, (added: 0, updated: 0));
    expect(notifications, 0);
  });

  test('importUserEntries partitions added vs. updated correctly', () async {
    const newOne = ModuleCatalogEntry(
        id: 'm-new', manufacturer: 'New', model: 'A', peakKwPerModule: 0.4);
    const updated = ModuleCatalogEntry(
        id: 'm-exists',
        manufacturer: 'Updated',
        model: 'B',
        peakKwPerModule: 0.5);
    const existing = ModuleCatalogEntry(
        id: 'm-exists',
        manufacturer: 'Original',
        model: 'B',
        peakKwPerModule: 0.4);
    final repo = _repo(user: const [existing]);

    var notifications = 0;
    repo.addListener(() => notifications++);

    final counts = await repo.importUserEntries(const [newOne, updated]);
    expect(counts, (added: 1, updated: 1));
    expect(notifications, 1,
        reason: 'one notify per bulk-import call, not per entry');

    final users = await repo.userEntries();
    expect(users, hasLength(2));
    final updatedFetched =
        users.firstWhere((e) => e.id == 'm-exists') as ModuleCatalogEntry;
    expect(updatedFetched.manufacturer, 'Updated');
    expect(updatedFetched.peakKwPerModule, 0.5);
  });

  test('previewImportConflicts identifies existing user-source ids',
      () async {
    const conflict = ModuleCatalogEntry(
        id: 'm', manufacturer: 'A', model: 'B', peakKwPerModule: 0.4);
    const fresh = ModuleCatalogEntry(
        id: 'fresh', manufacturer: 'C', model: 'D', peakKwPerModule: 0.5);
    final repo = _repo(user: const [conflict]);
    final conflicts =
        await repo.previewImportConflicts(const [conflict, fresh]);
    expect(conflicts, {'m'});
  });
}
