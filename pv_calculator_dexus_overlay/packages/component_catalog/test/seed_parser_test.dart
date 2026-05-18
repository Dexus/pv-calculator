import 'dart:convert';
import 'dart:io';

import 'package:component_catalog/component_catalog.dart';
import 'package:test/test.dart';

void main() {
  test('parses the bundled seed asset', () {
    // Path relative to package root; `dart test` runs from there.
    final txt = File('assets/components_seed_v1.json').readAsStringSync();
    final entries = parseSeedCatalog(txt);
    expect(entries, isNotEmpty);
    expect(entries.whereType<ModuleCatalogEntry>(), isNotEmpty);
    expect(entries.whereType<InverterCatalogEntry>(), isNotEmpty);
    expect(entries.whereType<BatteryCatalogEntry>(), isNotEmpty);
    // Every parsed entry passes its own validation.
    for (final e in entries) {
      e.validate();
    }
  });

  test('honours the in-section kind even when entries omit `kind`', () {
    final txt = jsonEncode({
      'version': 1,
      'modules': [
        {'id': 'm', 'manufacturer': 'A', 'model': 'B', 'peakKwPerModule': 0.4},
      ],
      'inverters': [
        {'id': 'i', 'manufacturer': 'A', 'model': 'B', 'maxAcKw': 5},
      ],
      'batteries': [
        {
          'id': 'b',
          'manufacturer': 'A',
          'model': 'B',
          'capacityKwh': 5,
          'maxChargeKw': 2,
          'maxDischargeKw': 2,
        },
      ],
    });
    final entries = parseSeedCatalog(txt);
    expect(entries.map((e) => e.kind).toSet(), {
      ComponentKind.module,
      ComponentKind.inverter,
      ComponentKind.battery,
    });
  });

  test('rejects non-object top-level json', () {
    expect(() => parseSeedCatalog('[]'), throwsArgumentError);
  });

  test('rejects a section that is not a list', () {
    expect(
        () => parseSeedCatalog(
            jsonEncode({'version': 1, 'modules': {'id': 'm'}})),
        throwsArgumentError);
  });

  test('rejects missing or non-integer version field', () {
    expect(
        () => parseSeedCatalog(jsonEncode({'modules': []})),
        throwsArgumentError);
    expect(
        () => parseSeedCatalog(jsonEncode({'version': '1'})),
        throwsArgumentError);
  });

  test('rejects an unsupported future seed catalog version', () {
    expect(
        () => parseSeedCatalog(jsonEncode({'version': 99, 'modules': []})),
        throwsArgumentError);
  });
}
