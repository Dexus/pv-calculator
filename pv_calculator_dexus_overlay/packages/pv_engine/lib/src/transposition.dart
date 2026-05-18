import 'dart:math' as math;

import 'weather.dart';

/// Ground reflectance (albedo) used by the ground-reflected term. 0.2 is
/// the conventional default for green grass / mixed surface; snow or
/// concrete would warrant a higher value, but we don't model that yet.
const double _albedo = 0.2;

/// Convert one hour of horizontal-plane irradiance into plane-of-array
/// irradiance for a fixed module at the given tilt + azimuth, using the
/// **isotropic (Liu-Jordan)** transposition model.
///
/// Components:
///   * Beam: project DNI through the angle of incidence. DNI is derived
///     from `GHI − DHI` divided by `cos(zenith)`, with a small-zenith
///     guard to keep nighttime hours stable.
///   * Diffuse: isotropic dome — `DHI · (1 + cos β) / 2`.
///   * Ground reflected: `GHI · ρ · (1 − cos β) / 2` with ρ = 0.2.
///
/// Simplifications (acceptable for v1, well within the ±5 % tolerance vs.
/// PVGIS POA at European latitudes ≤ 45° tilt that the redesign plan
/// accepted):
///   * Solar position is computed from a single-day declination + hour
///     angle; equation-of-time correction omitted.
///   * PVGIS timestamps are UTC; [longitudeDeg] is used to convert to
///     local solar time (`LST = UTC + lon / 15 h`) before the hour angle
///     is computed, so east/west sites produce beam at the correct time.
///   * Isotropic sky underestimates clear-day POA by 2–6 % vs. anisotropic
///     models (Hay-Davies / Perez). Upgrade path is to swap this function
///     out behind the same signature.
///   * Air-mass absorption and IAM (incidence-angle modifier) ignored.
/// Sun zenith + azimuth in radians for a given site and instant.
///
/// Cached by [HorizontalToPoaSource] so multiple arrays sampled at the
/// same `(dayOfYear, hourOfDay)` reuse one trig pass per step instead
/// of re-deriving the geometry per array.
class SolarPosition {
  const SolarPosition({required this.zenithRad, required this.azimuthRad});
  final double zenithRad;
  final double azimuthRad;
}

/// Derives [SolarPosition] for a site at one instant. The UTC-to-local
/// conversion baked into [transposeToPoa] lives here too so callers can
/// precompute once and pass the result back in.
SolarPosition solarPositionFor({
  required double latitudeDeg,
  required double longitudeDeg,
  required int dayOfYear,
  required double hourOfDay, // UTC hour [0, 24)
}) {
  final solarHourOfDay = hourOfDay + longitudeDeg / 15.0;
  final zenithRad = _solarZenithRad(
    latitudeDeg: latitudeDeg,
    dayOfYear: dayOfYear,
    hourOfDay: solarHourOfDay,
  );
  final azimuthRad = _solarAzimuthRad(
    latitudeDeg: latitudeDeg,
    dayOfYear: dayOfYear,
    hourOfDay: solarHourOfDay,
    zenithRad: zenithRad,
  );
  return SolarPosition(zenithRad: zenithRad, azimuthRad: azimuthRad);
}

WeatherSample transposeToPoa({
  required HorizontalIrradianceSample h,
  required double tiltDeg,
  required double azimuthDeg,
  required double latitudeDeg,
  required double longitudeDeg,
  required int dayOfYear,
  required double hourOfDay, // UTC hour [0, 24)
  SolarPosition? solarPosition,
}) {
  if (h.globalHorizontalWPerM2 <= 0) {
    return WeatherSample(
      poaWPerM2: 0,
      ambientTempC: h.ambientTempC,
      windMS: h.windMS,
    );
  }

  final position = solarPosition ??
      solarPositionFor(
        latitudeDeg: latitudeDeg,
        longitudeDeg: longitudeDeg,
        dayOfYear: dayOfYear,
        hourOfDay: hourOfDay,
      );

  final tiltRad = tiltDeg * math.pi / 180.0;
  final cosTilt = math.cos(tiltRad);
  final cosZenith = math.cos(position.zenithRad);

  final ghi = h.globalHorizontalWPerM2;
  final dhi = h.diffuseHorizontalWPerM2.clamp(0.0, ghi).toDouble();

  // Beam horizontal = GHI - DHI; DNI = BHI / cos(zenith). Clamp the
  // zenith cosine away from zero so dawn/dusk doesn't blow DNI up
  // and produce spurious POA spikes.
  double beamPoa = 0;
  if (cosZenith > 0.05) {
    final bhi = math.max(0.0, ghi - dhi);
    final dni = bhi / cosZenith;
    final cosIncidence = _cosIncidence(
      zenithRad: position.zenithRad,
      surfaceTiltRad: tiltRad,
      solarAzimuthRad: position.azimuthRad,
      surfaceAzimuthRad: azimuthDeg * math.pi / 180.0,
    );
    if (cosIncidence > 0) {
      beamPoa = dni * cosIncidence;
    }
  }

  final diffusePoa = dhi * (1.0 + cosTilt) / 2.0;
  final groundPoa = ghi * _albedo * (1.0 - cosTilt) / 2.0;

  final poa = beamPoa + diffusePoa + groundPoa;
  return WeatherSample(
    poaWPerM2: poa.clamp(0.0, 1500.0),
    ambientTempC: h.ambientTempC,
    windMS: h.windMS,
  );
}

/// Solar zenith angle in radians. Combines a simple declination model with
/// the local hour angle (no equation-of-time correction).
double _solarZenithRad({
  required double latitudeDeg,
  required int dayOfYear,
  required double hourOfDay,
}) {
  final latRad = latitudeDeg * math.pi / 180.0;
  final declRad = _declinationRad(dayOfYear);
  final hourAngleRad = (hourOfDay - 12.0) * 15.0 * math.pi / 180.0;
  final cosZ = math.sin(latRad) * math.sin(declRad) +
      math.cos(latRad) * math.cos(declRad) * math.cos(hourAngleRad);
  return math.acos(cosZ.clamp(-1.0, 1.0));
}

/// Solar azimuth in radians, **measured the same way as the engine's
/// `PvArray.azimuthDeg` field**: 0 = north, π/2 = east, π = south,
/// 3π/2 = west, range `[0, 2π)`.
double _solarAzimuthRad({
  required double latitudeDeg,
  required int dayOfYear,
  required double hourOfDay,
  required double zenithRad,
}) {
  final latRad = latitudeDeg * math.pi / 180.0;
  final declRad = _declinationRad(dayOfYear);
  final hourAngleRad = (hourOfDay - 12.0) * 15.0 * math.pi / 180.0;
  final sinZ = math.sin(zenithRad);
  if (sinZ < 1e-6) return 0.0;
  // Standard solar-azimuth formula, measured from north (clockwise +).
  final cosAz =
      (math.sin(declRad) * math.cos(latRad) - math.cos(declRad) * math.sin(latRad) * math.cos(hourAngleRad)) / sinZ;
  final azFromNorth = math.acos(cosAz.clamp(-1.0, 1.0));
  // Disambiguate east vs west: morning hours (negative hour angle)
  // place the sun east of south → azimuth in [0, π); afternoon (positive
  // hour angle) places it west → [π, 2π).
  return hourAngleRad < 0 ? azFromNorth : 2.0 * math.pi - azFromNorth;
}

/// Cosine of the incidence angle between the sun and the tilted module
/// surface, using the engine's azimuth convention (0 = north, 180 = south).
double _cosIncidence({
  required double zenithRad,
  required double surfaceTiltRad,
  required double solarAzimuthRad,
  required double surfaceAzimuthRad,
}) {
  return math.cos(zenithRad) * math.cos(surfaceTiltRad) +
      math.sin(zenithRad) *
          math.sin(surfaceTiltRad) *
          math.cos(solarAzimuthRad - surfaceAzimuthRad);
}

/// Solar declination in radians (Spencer's approximation simplified to the
/// Cooper formula). Accurate to ~0.5°, plenty for an isotropic v1.
double _declinationRad(int dayOfYear) {
  return 23.45 * math.pi / 180.0 * math.sin(2.0 * math.pi * (284 + dayOfYear) / 365.0);
}
