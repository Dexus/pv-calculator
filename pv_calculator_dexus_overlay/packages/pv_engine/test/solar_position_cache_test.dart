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
  test('arrays at the same instant produce identical solar geometry', () {
    final source = HorizontalToPoaSource(_flatSeries());
    // Same (day, hour, lat), different tilt/azimuth ⇒ different POA, but
    // the underlying geometry must be reused. We can't observe the cache
    // directly; check that POA values for the same array are stable
    // across repeated calls (idempotency) and that the source survives
    // many arrays without throwing.
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
}
