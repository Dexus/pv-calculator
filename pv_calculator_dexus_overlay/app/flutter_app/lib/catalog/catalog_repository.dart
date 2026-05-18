import 'dart:convert';

import 'package:component_catalog/component_catalog.dart';
import 'package:flutter/foundation.dart';

import '../persistence/database.dart';
import 'bundled_seed_source.dart';
import 'sqlite_user_catalog_source.dart';

/// Counts returned by [CatalogRepository.importUserEntries]. `added` are
/// ids previously absent from the user source, `updated` are ids that
/// existed and were upserted with the imported payload.
typedef CatalogImportCounts = ({int added, int updated});

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

  /// User-source entries only (no seed). Used by the management UI to
  /// distinguish editable user rows from read-only seed rows.
  Future<List<CatalogEntry>> userEntries() => _user.fetch();

  /// Seed-source entries only. Used by the management UI to render the
  /// read-only seed list with a "duplicate as user entry" action.
  Future<List<CatalogEntry>> seedEntries() => _seed.fetch();

  /// Upserts a user entry. Called for both create and edit — the user
  /// source treats id collisions as in-place updates.
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

  /// Bulk-import [entries] into the user source. Returns counts split by
  /// whether the entry id was new vs. already present. Invalidates the
  /// merged cache once and notifies listeners once at the end.
  Future<CatalogImportCounts> importUserEntries(
      List<CatalogEntry> entries) async {
    if (entries.isEmpty) return (added: 0, updated: 0);
    final existing = {for (final e in await _user.fetch()) e.id};
    var added = 0;
    var updated = 0;
    for (final entry in entries) {
      if (existing.contains(entry.id)) {
        updated++;
      } else {
        added++;
        existing.add(entry.id);
      }
      await _user.upsert(entry);
    }
    _merged.invalidate();
    notifyListeners();
    return (added: added, updated: updated);
  }

  /// Returns ids of [candidates] that would overwrite an existing user
  /// entry on import. Read-only dry-run for confirmation dialogs.
  Future<Set<String>> previewImportConflicts(
      Iterable<CatalogEntry> candidates) async {
    final existing = {for (final e in await _user.fetch()) e.id};
    return {for (final c in candidates) if (existing.contains(c.id)) c.id};
  }

  /// Serialises the **user** source into the seed-shaped JSON document
  /// (`{ version: 1, modules: [...], inverters: [...], batteries: [...] }`).
  /// The output is intentionally identical in shape to the bundled seed
  /// so that a user-exported file can be re-imported via
  /// [parseSeedCatalog], hand-edited, or even shipped as a future seed.
  Future<String> exportUserCatalogJson() async {
    final all = await _user.fetch();
    final modules = <Map<String, dynamic>>[];
    final inverters = <Map<String, dynamic>>[];
    final batteries = <Map<String, dynamic>>[];
    for (final entry in all) {
      // Strip the `kind` discriminator — the section name is authoritative
      // in the seed shape, and parseSeedCatalog re-adds it on read.
      final json = Map<String, dynamic>.from(entry.toJson())..remove('kind');
      switch (entry.kind) {
        case ComponentKind.module:
          modules.add(json);
        case ComponentKind.inverter:
          inverters.add(json);
        case ComponentKind.battery:
          batteries.add(json);
      }
    }
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'version': kSupportedSeedCatalogVersions.first,
      'modules': modules,
      'inverters': inverters,
      'batteries': batteries,
    });
  }
}
