import 'package:flutter_test/flutter_test.dart';
import 'package:pv_calculator_app/persistence/database.dart';
import 'package:pv_calculator_app/persistence/irradiance_cache_repository.dart';
import 'package:pv_engine/pv_engine.dart';

HorizontalIrradianceSeries _series({
  double lat = 52.5,
  double lon = 13.4,
  int year = 2022,
  String? radDatabase = 'PVGIS-SARAH3',
  double ghiSeed = 100.0,
}) {
  final samples = List<HorizontalIrradianceSample>.generate(
    365 * 24,
    (i) => HorizontalIrradianceSample(
      globalHorizontalWPerM2: ghiSeed + i * 0.001,
      diffuseHorizontalWPerM2: (ghiSeed + i * 0.001) * 0.3,
      ambientTempC: 15.0,
      windMS: 2.0,
    ),
  );
  return HorizontalIrradianceSeries(
    samples: samples,
    year: year,
    latitudeDeg: lat,
    longitudeDeg: lon,
    radDatabase: radDatabase,
  );
}

void main() {
  late AppDatabase db;
  late IrradianceCacheRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = IrradianceCacheRepository(db);
  });

  tearDown(() => db.close());

  test('lookup returns null when no entry exists', () {
    expect(
      repo.lookup(
        latitudeDeg: 50.0,
        longitudeDeg: 10.0,
        year: 2022,
        radDatabase: 'PVGIS-SARAH3',
      ),
      isNull,
    );
  });

  test('store + lookup round-trips a series with metadata intact', () {
    final source = _series();
    repo.store(
      latitudeDeg: source.latitudeDeg,
      longitudeDeg: source.longitudeDeg,
      year: source.year,
      radDatabase: source.radDatabase,
      series: source,
    );
    final loaded = repo.lookup(
      latitudeDeg: source.latitudeDeg,
      longitudeDeg: source.longitudeDeg,
      year: source.year,
      radDatabase: source.radDatabase,
    );
    expect(loaded, isNotNull);
    expect(loaded!.year, source.year);
    expect(loaded.latitudeDeg, source.latitudeDeg);
    expect(loaded.longitudeDeg, source.longitudeDeg);
    expect(loaded.radDatabase, source.radDatabase);
    expect(loaded.samples.length, 365 * 24);
    expect(loaded.samples[1234].globalHorizontalWPerM2,
        source.samples[1234].globalHorizontalWPerM2);
  });

  test('coordinate quantisation collapses sub-11 m neighbours onto one row',
      () {
    // 4 decimal places ≈ 11 m at the equator. Two pins within that grid
    // cell must share the same cache entry — otherwise multiple
    // projects at the "same" address each force their own PVGIS fetch.
    final series = _series(lat: 52.12340, lon: 13.40002);
    repo.store(
      latitudeDeg: series.latitudeDeg,
      longitudeDeg: series.longitudeDeg,
      year: series.year,
      radDatabase: series.radDatabase,
      series: series,
    );
    final hit = repo.lookup(
      latitudeDeg: 52.12343,
      longitudeDeg: 13.40001,
      year: 2022,
      radDatabase: 'PVGIS-SARAH3',
    );
    expect(hit, isNotNull);
    final rows = db.db.select('SELECT COUNT(*) AS n FROM irradiance_cache');
    expect(rows.first['n'], 1);
  });

  test('null radDatabase is distinct from a named database', () {
    final series = _series(radDatabase: null);
    repo.store(
      latitudeDeg: series.latitudeDeg,
      longitudeDeg: series.longitudeDeg,
      year: series.year,
      radDatabase: series.radDatabase,
      series: series,
    );
    expect(
      repo.lookup(
        latitudeDeg: 52.5,
        longitudeDeg: 13.4,
        year: 2022,
        radDatabase: null,
      ),
      isNotNull,
    );
    expect(
      repo.lookup(
        latitudeDeg: 52.5,
        longitudeDeg: 13.4,
        year: 2022,
        radDatabase: 'PVGIS-SARAH3',
      ),
      isNull,
    );
  });

  test('storing the same key replaces the previous payload', () {
    final s1 = _series(ghiSeed: 100.0);
    final s2 = _series(ghiSeed: 250.0);
    repo.store(
      latitudeDeg: s1.latitudeDeg,
      longitudeDeg: s1.longitudeDeg,
      year: s1.year,
      radDatabase: s1.radDatabase,
      series: s1,
    );
    repo.store(
      latitudeDeg: s2.latitudeDeg,
      longitudeDeg: s2.longitudeDeg,
      year: s2.year,
      radDatabase: s2.radDatabase,
      series: s2,
    );
    final loaded = repo.lookup(
      latitudeDeg: 52.5,
      longitudeDeg: 13.4,
      year: 2022,
      radDatabase: 'PVGIS-SARAH3',
    );
    expect(loaded, isNotNull);
    expect(loaded!.samples.first.globalHorizontalWPerM2, 250.0);
    final rows = db.db.select('SELECT COUNT(*) AS n FROM irradiance_cache');
    expect(rows.first['n'], 1);
  });

  test('buildLookupKey is stable and produces distinct keys per dimension',
      () {
    final a = IrradianceCacheRepository.buildLookupKey(
      latitudeDeg: 52.5,
      longitudeDeg: 13.4,
      year: 2022,
      radDatabase: 'PVGIS-SARAH3',
    );
    final sameQuantised = IrradianceCacheRepository.buildLookupKey(
      latitudeDeg: 52.50002,
      longitudeDeg: 13.40001,
      year: 2022,
      radDatabase: 'PVGIS-SARAH3',
    );
    expect(a, sameQuantised);
    expect(
      IrradianceCacheRepository.buildLookupKey(
        latitudeDeg: 52.5,
        longitudeDeg: 13.4,
        year: 2021,
        radDatabase: 'PVGIS-SARAH3',
      ),
      isNot(a),
    );
    expect(
      IrradianceCacheRepository.buildLookupKey(
        latitudeDeg: 52.5,
        longitudeDeg: 13.4,
        year: 2022,
        radDatabase: 'PVGIS-ERA5',
      ),
      isNot(a),
    );
  });
}
