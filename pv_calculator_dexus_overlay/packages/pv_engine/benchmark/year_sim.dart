// Phase 9 baseline benchmark: runs a one-year simulation at both step
// widths and prints wall-clock numbers. Not in CI — invoked manually
// before/after performance commits so changes are measurable.
//
// Usage:
//   dart run benchmark/year_sim.dart                  # 5 warmups + 5 measured
//   dart run benchmark/year_sim.dart --warmup=2 --runs=3
//
// The harness builds a deterministic HorizontalIrradianceSeries so the
// numbers are reproducible across machines.

import 'dart:math' as math;

import 'package:pv_engine/pv_engine.dart';

void main(List<String> args) {
  final warmup = _intArg(args, '--warmup', 3);
  final runs = _intArg(args, '--runs', 5);

  print('# pv_engine year-sim benchmark — engine $kEngineVersion');
  print('# warmups: $warmup   measured runs: $runs');
  print('');

  for (final timeStep in TimeStep.values) {
    final cfg = _yearConfig(timeStep);
    for (var i = 0; i < warmup; i++) {
      const PvSimulator().run(cfg);
    }
    final samples = <double>[];
    for (var i = 0; i < runs; i++) {
      final sw = Stopwatch()..start();
      const PvSimulator().run(cfg);
      sw.stop();
      samples.add(sw.elapsedMicroseconds / 1000.0);
    }
    samples.sort();
    final median = samples[samples.length ~/ 2];
    final min = samples.first;
    final max = samples.last;
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    final stepsPerYear = 365 * timeStep.stepsPerDay;
    print('${timeStep.name.padRight(14)} '
        '($stepsPerYear steps): '
        'median ${median.toStringAsFixed(1)} ms, '
        'min ${min.toStringAsFixed(1)} ms, '
        'max ${max.toStringAsFixed(1)} ms, '
        'mean ${mean.toStringAsFixed(1)} ms');
  }
}

int _intArg(List<String> args, String flag, int fallback) {
  for (final a in args) {
    if (a.startsWith('$flag=')) {
      final v = int.tryParse(a.substring(flag.length + 1));
      if (v != null) return v;
    }
  }
  return fallback;
}

SimulationConfig _yearConfig(TimeStep timeStep) {
  return SimulationConfig(
    arrays: const [
      PvArray(id: 'south', label: 'South', peakKw: 6.0, azimuthDeg: 180, tiltDeg: 35, inverterId: 'inv'),
      PvArray(id: 'east', label: 'East', peakKw: 4.0, azimuthDeg: 90, tiltDeg: 30, inverterId: 'inv'),
      PvArray(id: 'west', label: 'West', peakKw: 4.0, azimuthDeg: 270, tiltDeg: 30, inverterId: 'inv'),
    ],
    inverters: const [Inverter(id: 'inv', label: 'Inv', maxAcKw: 10.0, efficiency: 0.97)],
    batteries: const [
      BatteryConfig(id: 'bat', capacityKwh: 10.0, maxChargeKw: 4.0, maxDischargeKw: 4.0),
    ],
    loadProfile: const LoadProfile(dailyKwh: 12),
    startDayOfYear: 1,
    days: 365,
    timeStep: timeStep,
    weatherSource: _benchmarkSeries(),
  );
}

/// Deterministic horizontal-series. Sinusoidal global irradiance with a
/// constant diffuse share so transposition is exercised on every step.
HorizontalToPoaSource _benchmarkSeries() {
  final samples = <HorizontalIrradianceSample>[];
  for (var day = 0; day < 365; day++) {
    final seasonal = 0.5 + 0.4 * math.cos(2 * math.pi * (day - 172) / 365.0).abs();
    for (var hour = 0; hour < 24; hour++) {
      final sunOk = hour >= 6 && hour <= 18;
      final base = sunOk
          ? 900.0 * seasonal * math.sin(math.pi * (hour - 6) / 12.0)
          : 0.0;
      samples.add(HorizontalIrradianceSample(
        globalHorizontalWPerM2: base,
        diffuseHorizontalWPerM2: base * 0.35,
        ambientTempC: 15 + 10 * seasonal,
      ));
    }
  }
  return HorizontalToPoaSource(HorizontalIrradianceSeries(
    samples: samples,
    year: 2024,
    latitudeDeg: 50.0,
    longitudeDeg: 10.0,
  ));
}
