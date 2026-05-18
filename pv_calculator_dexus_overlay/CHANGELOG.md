# Changelog – PV Calculator (Dexus Overlay)

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The two artefacts versioned here are:

- **App** (`app/flutter_app/pubspec.yaml`) — user-facing Flutter app.
- **Engine** (`packages/pv_engine/pubspec.yaml`, `kEngineVersion`) — pure-Dart
  simulation library that the app depends on via path.

The About dialog in the app surfaces `appVersion (engine kEngineVersion)`
so a deployed scenario can be tied to an exact engine revision (PRD NFR-05).

## [Unreleased]

## [0.3.0] — 2026-05-18 (app) / [0.7.0] — 2026-05-18 (engine)

Phase 9 — Performance & 15-Minute Resolution.

### Added — Engine
- **`SimulationProgress` + `onProgress` callback** on `PvSimulator.run`.
  Emits one event per simulated day (pre-run + reporting) with phase,
  completed/total days and (for `cyclicConvergence`) the iteration index.
  Drives the UI progress bar; engine stays Flutter-free.
- **`SolarPosition` + `solarPositionFor()`** — public helpers for the
  per-(day, hour, lat, lon) solar geometry. `transposeToPoa` accepts a
  precomputed `solarPosition` to skip the internal trig.
- **`SimulationConfig.keepSteps`** (default `true`). When `false`, the
  simulator skips retaining per-step records — annual KPIs are still
  produced but `SimulationResult.steps` is empty. JSON emits the field
  only when non-default so pre-Phase-9 round-trips and `inputHash` stay
  byte-identical.

### Changed — Engine
- **15-min step width verified end-to-end.** `TimeStep.quarterHourly`
  was already plumbed; this release adds the parity test (60-min and
  15-min summaries agree to ≤ 1e-9 kWh on piecewise-constant inputs) and
  documents the load-profile + weather-source quantisation behaviour.
- **Solar-geometry cache in `HorizontalToPoaSource`.** Each step's
  arrays share the cached zenith/azimuth instead of recomputing trig
  per array. The source now carries an 8760-slot cache invalidated on
  latitude change.
- **`_summarize` reads from an in-loop accumulator** instead of folding
  over the kept-steps list. Combined with `keepSteps: false` this drops
  ~35,040 `SimulationStep` allocations for batch comparisons.
- Engine version bumped `0.6.0 → 0.7.0` (new public API: `SimulationProgress`,
  `SolarPosition`, `keepSteps`).

### Added — App
- **Simulation runs in a worker isolate** on native; **stays in-process**
  on web (no isolates available). `SimulationRunner` owns the boundary;
  controllers (`ProjectController.run`, `ScenarioComparisonController`)
  switched to `async` and bridge engine progress to the UI.
- **Determinate progress bar** under the Run button on the Auswertung tab,
  with phase label (pre-run / reporting / cyclic-iteration N).
- **In-memory result cache** (size 3) in `ProjectController`, keyed on
  `(inputHash, engineVersion)`. Repeated Run on an unchanged draft
  returns instantly.

### Changed — App
- App version bumped `0.2.0 → 0.3.0`.

### Benchmarks (engine, this dev machine, 3 arrays × 365 days)
- pre-Phase-9: hourly 64.8 ms,  quarterHourly 251.2 ms
- post-Phase-9: hourly 55.7 ms, quarterHourly 219.1 ms

A new manual `dart run benchmark/year_sim.dart` harness captures these
numbers reproducibly and is the baseline for future perf commits.

### Verschoben (Phase 9)
- **`Float64List`-backed columnar step storage.** Originally planned as
  C4a/C4b. The current 219 ms quarter-hourly run is already comfortably
  under the PRD's 5 s mid-range-mobile target, so the storage refactor
  doesn't earn its review cost yet. Pick up if mobile profiling shows
  GC pressure dominating the year-sim runtime.

## [0.2.0] — 2026-05-15 (app) / [0.6.0] — 2026-05-15 (engine)

### Added — App
- **Quick-Start Wizard** in the projects tab — 5-step `Stepper`
  (Standort → PV-Array → optional Speicher → Lastprofil → Zusammenfassung)
  that prefills `ConfigDraft` for `+ Neues Projekt`. Each step now wraps
  its inputs in a `Form` with `autovalidateMode: onUserInteraction` so
  Continue stays disabled while any visible field shows a validation
  error.
- **Expertenmodus** toggle in Settings (default OFF, persisted via
  `pv_expert_mode`). Hides `TopologySection`, `MicroInverterBanksSection`
  and `DispatchPolicySection`; shows an info-card link to Settings.
  Auto-detect banner appears when a loaded draft already uses an
  advanced feature.
- **Validation warnings** on the Auswertung tab —
  inverter oversizing (DC/AC > 1.3), bank target above battery discharge,
  minSOC above 50% of capacity, missing irradiance hint.
- About dialog now shows `appVersion (engine kEngineVersion)`.
- Wizard-created projects now seed the auto-created `sites` row with
  the wizard's lat/lon (previously fell back to the 50.0/10.0 default).

### Added — Engine
- `SimulationStep.dcKwhByArray` / `acKwhByArray` — per-array energy
  breakdown. Sums match `pvDcKwh` / `pvAcKwh` within floating-point
  tolerance.
- `stepsCsv(arrayIds: [...])` emits one `dcKwh_<id>` / `acKwh_<id>`
  column per array; identifiers are sanitised so they can't break
  the CSV delimiter.

### Changed
- App version bumped `0.1.0 → 0.2.0` to reflect the Phase 8 slice 1–3
  feature set.
- Engine version bumped `0.5.0 → 0.6.0` because `SimulationStep` and
  `stepsCsv` gained new public outputs (per-array columns); scenario/run
  rows tagged with `0.6.0` are distinguishable from the previous
  per-array-blind output.

## [0.5.0] — 2026-05-15 (engine)

- Phase 5: cyclic-convergence pre-run mode (Pro feature flag) and
  schema v3 JSON round-trip. See `docs/ROADMAP.md` for the full list.
