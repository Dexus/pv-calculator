import 'package:pv_engine/pv_engine.dart';
import 'package:test/test.dart';

/// Phase 9 — C3: HorizontalToPoaSource memoises per-(day, hour) solar
/// geometry so multiple arrays sampled at the same instant share one
/// trig pass. The cache is invalidated when `query.latitudeDeg` changes
/// between calls, so reusing the source across configurations with
/// different sites stays correct.
HorizontalIrradianceSeries _flatSeries({
  double latitudeDeg = 50,
  double longitudeDeg = 10,
}) {
  final samples = <HorizontalIrradianceSample>[];
  for (var i = 0; i < 365 * 24; i++) {
    samples.add(const HorizontalIrradianceSample(
      globalHorizontalWPerM2: 800,
      diffuseHorizontalWPerM2: 200,
      ambientTempC: 20,
    ));
  }
  return HorizontalIrradianceSeries(
    samples: samples,
    year: 2024,
    latitudeDeg: latitudeDeg,
    longitudeDeg: longitudeDeg,
  );
}

void main() {
  test('repeated calls with the same (instant, tilt, azimuth) are idempotent', () {
    // The cache hit path must return the same POA as the cache-miss
    // path — i.e., reusing the cached SolarPosition must not change
    // the transposition output. Equal POA across two calls with
    // identical inputs is the observable signal.
    final source = HorizontalToPoaSource(_flatSeries());
    final a = source.sampleFor(const WeatherQuery(
      arrayId: 'a', tiltDeg: 30, azimuthDeg: 180, dayOfYear: 172,
      hourOfDay: 12.5, latitudeDeg: 50,
    ));
    final b = source.sampleFor(const WeatherQuery(
      arrayId: 'b', tiltDeg: 30, azimuthDeg: 180, dayOfYear: 172,
      hourOfDay: 12.5, latitudeDeg: 50,
    ));
    expect(a.poaWPerM2, closeTo(b.poaWPerM2, 1e-9));
    expect(a.poaWPerM2, greaterThan(0));
  });

  test('cache invalidates when latitude changes between calls', () {
    final source = HorizontalToPoaSource(_flatSeries());
    // Tilt the panel so cos(incidence) depends on zenith — at tilt 0
    // the formula collapses to POA = GHI for any latitude and the
    // cache-miss vs cache-hit paths are indistinguishable.
    final equator = source.sampleFor(const WeatherQuery(
      arrayId: 'a', tiltDeg: 60, azimuthDeg: 180, dayOfYear: 80,
      hourOfDay: 12, latitudeDeg: 0,
    ));
    final arctic = source.sampleFor(const WeatherQuery(
      arrayId: 'a', tiltDeg: 60, azimuthDeg: 180, dayOfYear: 80,
      hourOfDay: 12, latitudeDeg: 75,
    ));
    // POA at the equator should differ substantially from POA at 75° N
    // for the same instant — if the cache forgot to invalidate, both
    // calls would return the same value.
    expect(equator.poaWPerM2, isNot(closeTo(arctic.poaWPerM2, 20.0)));
  });

  test('zero GHI short-circuits before touching the cache', () {
    // Build a series whose samples are all dark; the source must still
    // return zero POA without throwing.
    final samples = <HorizontalIrradianceSample>[];
    for (var i = 0; i < 365 * 24; i++) {
      samples.add(HorizontalIrradianceSample.empty);
    }
    final dark = HorizontalToPoaSource(HorizontalIrradianceSeries(
      samples: samples,
      year: 2024,
      latitudeDeg: 50,
      longitudeDeg: 10,
    ));
    final result = dark.sampleFor(const WeatherQuery(
      arrayId: 'a', tiltDeg: 35, azimuthDeg: 180, dayOfYear: 1,
      hourOfDay: 12, latitudeDeg: 50,
    ));
    expect(result.poaWPerM2, 0.0);
  });

  test('solarPositionFor is deterministic for the same inputs', () {
    final p1 = solarPositionFor(
      latitudeDeg: 50, longitudeDeg: 10, dayOfYear: 172, hourOfDay: 12,
    );
    final p2 = solarPositionFor(
      latitudeDeg: 50, longitudeDeg: 10, dayOfYear: 172, hourOfDay: 12,
    );
    expect(p1.zenithRad, p2.zenithRad);
    expect(p1.azimuthRad, p2.azimuthRad);
  });

  test('quarter-hourly sub-hour queries do not collapse onto the floored hour', () {
    // Regression test for the PR #26 review threads (Codex + Copilot):
    // the cache used to be keyed by `dayIdx * 24 + hourOfDay.floor()`,
    // so for `TimeStep.quarterHourly` the geometry derived from the
    // first quarter (e.g. hourOfDay=12.125) was reused for 12.375 /
    // 12.625 / 12.875. Verify each sub-hour produces a distinct POA
    // matching the geometry at that exact instant, regardless of the
    // order the queries arrive in.
    final source = HorizontalToPoaSource(_flatSeries());
    const tilt = 60.0;
    const az = 90.0; // east-facing — POA varies fast with hour angle

    final ordered = <double>[];
    for (final h in const [12.125, 12.375, 12.625, 12.875]) {
      ordered.add(source.sampleFor(WeatherQuery(
        arrayId: 'a', tiltDeg: tilt, azimuthDeg: az, dayOfYear: 80,
        hourOfDay: h, latitudeDeg: 50,
      )).poaWPerM2);
    }

    // Re-create the source so the cache starts empty, then query in
    // reverse order. With the buggy floored-hour key the *first* call
    // (12.875) would seed the cache and the rest would return the same
    // POA. With the fixed key each sub-hour produces its own geometry.
    final reverseSource = HorizontalToPoaSource(_flatSeries());
    final reversed = <double>[];
    for (final h in const [12.875, 12.625, 12.375, 12.125]) {
      reversed.add(reverseSource.sampleFor(WeatherQuery(
        arrayId: 'a', tiltDeg: tilt, azimuthDeg: az, dayOfYear: 80,
        hourOfDay: h, latitudeDeg: 50,
      )).poaWPerM2);
    }
    // Walk the reversed list back into the forward order and compare:
    // order-independence proves the cache key disambiguates sub-hours.
    final reversedAligned = reversed.reversed.toList();
    for (var i = 0; i < ordered.length; i++) {
      expect(reversedAligned[i], closeTo(ordered[i], 1e-12),
          reason: 'sub-hour ${[12.125, 12.375, 12.625, 12.875][i]} '
              'must be order-independent');
    }
    // And the four values must not all be equal — that's the symptom
    // the old key produced. East-facing at midday gives a steep beam
    // gradient, so consecutive 15-min slots differ visibly.
    expect(ordered.toSet().length, greaterThan(1),
        reason: 'sub-hours must produce distinct POA — the floored-hour '
            'cache key would collapse them onto one value');
  });
}
