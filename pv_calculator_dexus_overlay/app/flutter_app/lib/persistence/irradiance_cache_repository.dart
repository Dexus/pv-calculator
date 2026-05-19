import 'dart:convert';

import 'package:pv_engine/pv_engine.dart';

import 'database.dart';

/// Local cache for PVGIS horizontal-irradiance fetches. One row per
/// (rounded lat, rounded lon, year, radDatabase) — multiple projects at
/// the same location reuse the same row, and reopening a project
/// restores its irradiance without a network round-trip.
///
/// Coordinates are quantised to four decimal places (~11 m at the
/// equator). PVGIS's underlying grid is coarser than that, so two
/// nearby map pins effectively share one cache entry. The full-precision
/// values from the original `HorizontalIrradianceSeries` are stored on
/// the row for display/audit purposes.
class IrradianceCacheRepository {
  IrradianceCacheRepository(this._db);

  final AppDatabase _db;

  /// Returns the cached series for the given site/year, or `null` if no
  /// entry exists.
  HorizontalIrradianceSeries? lookup({
    required double latitudeDeg,
    required double longitudeDeg,
    required int year,
    String? radDatabase,
  }) {
    final key = buildLookupKey(
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg,
      year: year,
      radDatabase: radDatabase,
    );
    final rows = _db.db.select(
      'SELECT payload_json FROM irradiance_cache WHERE lookup_key = ?',
      [key],
    );
    if (rows.isEmpty) return null;
    final raw = jsonDecode(rows.first['payload_json'] as String) as Map<String, dynamic>;
    return HorizontalIrradianceSeries.fromJson(raw);
  }

  /// Inserts or replaces the cache row for [series] under the
  /// **requested** lat/lon/year/radDatabase. The series' own metadata
  /// can differ from the request — PVGIS snaps requested coordinates
  /// to its grid and reports the snapped values in the response — but
  /// the user asked for the requested coords, so the cache must be
  /// keyed on those to make a follow-up request hit.
  void store({
    required double latitudeDeg,
    required double longitudeDeg,
    required int year,
    required String? radDatabase,
    required HorizontalIrradianceSeries series,
    String source = 'pvgis',
  }) {
    final key = buildLookupKey(
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg,
      year: year,
      radDatabase: radDatabase,
    );
    final payload = jsonEncode(series.toJson());
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    _db.db.execute(
      'INSERT OR REPLACE INTO irradiance_cache('
      'lookup_key, latitude_deg, longitude_deg, year, rad_database, '
      'payload_json, fetched_at, source) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        key,
        latitudeDeg,
        longitudeDeg,
        year,
        radDatabase,
        payload,
        now,
        source,
      ],
    );
  }

  /// Pure helper exposed for tests. Coordinates are rounded to four
  /// decimal places; `null` radDatabase distinguishes the "PVGIS auto"
  /// case from any named database.
  static String buildLookupKey({
    required double latitudeDeg,
    required double longitudeDeg,
    required int year,
    required String? radDatabase,
  }) {
    final lat = latitudeDeg.toStringAsFixed(4);
    final lon = longitudeDeg.toStringAsFixed(4);
    return '$lat|$lon|$year|${radDatabase ?? ''}';
  }
}
