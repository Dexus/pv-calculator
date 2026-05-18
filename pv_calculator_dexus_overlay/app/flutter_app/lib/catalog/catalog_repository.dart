import 'package:component_catalog/component_catalog.dart';
import 'package:flutter/foundation.dart';

import '../persistence/database.dart';
import 'bundled_seed_source.dart';
import 'sqlite_user_catalog_source.dart';

/// App-side façade in front of [MergedCatalog]. Composes the bundled
/// seed source (read-only) and the sqlite user source (writable), with
/// user rows winning on id collisions.
///
/// Notifies listeners whenever a write succeeds so widgets that hold a
/// `Future<List<…>>` can re-issue `fetch()`.
class CatalogRepository extends ChangeNotifier {
  CatalogRepository({
    required CatalogSource seedSource,
    required CatalogSource userSource,
  })  : _seed = seedSource,
        _user = userSource,
        _merged = MergedCatalog([seedSource, userSource]);

  /// Production constructor — composes the default Flutter sources.
  factory CatalogRepository.standard(AppDatabase db) {
    return CatalogRepository(
      seedSource: BundledSeedCatalogSource(),
      userSource: SqliteUserCatalogSource(db),
    );
  }

  final CatalogSource _seed;
  final CatalogSource _user;
  final MergedCatalog _merged;

  /// Exposed for tests that want to seed the user source directly.
  CatalogSource get userSource => _user;
  CatalogSource get seedSource => _seed;

  Future<List<ModuleCatalogEntry>> modules() =>
      _merged.byKind<ModuleCatalogEntry>(ComponentKind.module);

  Future<List<InverterCatalogEntry>> inverters() =>
      _merged.byKind<InverterCatalogEntry>(ComponentKind.inverter);

  Future<List<BatteryCatalogEntry>> batteries() =>
      _merged.byKind<BatteryCatalogEntry>(ComponentKind.battery);

  Future<void> addUserEntry(CatalogEntry entry) async {
    await _user.upsert(entry);
    _merged.invalidate();
    notifyListeners();
  }

  Future<void> deleteUserEntry(String id) async {
    await _user.delete(id);
    _merged.invalidate();
    notifyListeners();
  }
}
