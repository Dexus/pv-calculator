import 'dart:math' as math;

import 'weather.dart';

/// Cell-temperature model. Converts ambient conditions + irradiance
/// into the operating cell temperature that the power-derating step
/// later applies via the module's temperature coefficient.
abstract class TemperatureModel {
  const TemperatureModel();

  /// Cell temperature in °C for the given weather sample.
  double cellTemperatureC(WeatherSample weather, {required double nominalOperatingCellTempC});
}

/// NOCT-based model. Standard simplification:
///
///   T_cell = T_ambient + (NOCT - 20 °C) / 800 W/m² * G_poa
///
/// NOCT defaults to 45 °C (typical crystalline silicon). Wind cooling
/// is folded into the NOCT calibration; for finer-grained Faiman-style
/// modelling, swap this out for a different [TemperatureModel].
class NoctTemperatureModel extends TemperatureModel {
  const NoctTemperatureModel();

  @override
  double cellTemperatureC(WeatherSample weather, {required double nominalOperatingCellTempC}) {
    return weather.ambientTempC + (nominalOperatingCellTempC - 20.0) / 800.0 * weather.poaWPerM2;
  }
}

/// Faiman-style model with explicit wind cooling:
///
///   T_cell = T_ambient + G_poa / (u0 + u1 * windMS)
///
/// Defaults u0=25, u1=6.84 (open rack, IEC 61853-2 indicative values).
/// Pass smaller u0 / u1 for tightly mounted modules with poor airflow.
class FaimanTemperatureModel extends TemperatureModel {
  const FaimanTemperatureModel({this.u0 = 25.0, this.u1 = 6.84});

  final double u0;
  final double u1;

  @override
  double cellTemperatureC(WeatherSample weather, {required double nominalOperatingCellTempC}) {
    final denom = math.max(1e-6, u0 + u1 * math.max(0.0, weather.windMS));
    return weather.ambientTempC + weather.poaWPerM2 / denom;
  }
}
