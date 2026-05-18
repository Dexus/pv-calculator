import 'package:component_catalog/component_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/catalog/bundled_seed_source.dart';

void main() {
  test('bundled seed asset is reachable via rootBundle and parses cleanly',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final source = BundledSeedCatalogSource();
    final entries = await source.fetch();
    expect(entries, isNotEmpty);
    expect(entries.whereType<ModuleCatalogEntry>(), isNotEmpty);
    expect(entries.whereType<InverterCatalogEntry>(), isNotEmpty);
    expect(entries.whereType<BatteryCatalogEntry>(), isNotEmpty);
  });
}
