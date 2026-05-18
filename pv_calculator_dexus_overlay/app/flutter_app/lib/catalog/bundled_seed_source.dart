import 'package:component_catalog/component_catalog.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Read-only [CatalogSource] backed by the JSON asset shipped with the
/// `component_catalog` path-dependency package. The asset is loaded
/// once and cached for the app's lifetime; subsequent `fetch()` calls
/// return the cached list.
class BundledSeedCatalogSource extends CatalogSource {
  BundledSeedCatalogSource({this.assetKey = _defaultAssetKey});

  static const String _defaultAssetKey =
      'packages/component_catalog/assets/components_seed_v1.json';

  final String assetKey;

  List<CatalogEntry>? _cache;

  @override
  Future<List<CatalogEntry>> fetch() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(assetKey);
    final parsed = List<CatalogEntry>.unmodifiable(parseSeedCatalog(raw));
    _cache = parsed;
    return parsed;
  }
}
