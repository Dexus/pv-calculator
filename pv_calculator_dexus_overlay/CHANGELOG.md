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

### Added — App
- **Quick-Start Wizard** in the projects tab — 5-step `Stepper`
  (Standort → PV-Array → optional Speicher → Lastprofil → Zusammenfassung)
  that prefills `ConfigDraft` for `+ Neues Projekt`.
- **Expertenmodus** toggle in Settings (default OFF, persisted via
  `pv_expert_mode`). Hides `TopologySection`, `MicroInverterBanksSection`
  and `DispatchPolicySection`; shows an info-card link to Settings.
  Auto-detect banner appears when a loaded draft already uses an
  advanced feature.
- **Validation warnings** on the Auswertung tab —
  inverter oversizing (DC/AC > 1.3), bank target above battery discharge,
  minSOC above 50% of capacity, missing irradiance hint.
- About dialog now shows `appVersion (engine kEngineVersion)`.

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

## [0.5.0] — 2026-05-15 (engine)

- Phase 5: cyclic-convergence pre-run mode (Pro feature flag) and
  schema v3 JSON round-trip. See `docs/ROADMAP.md` for the full list.
