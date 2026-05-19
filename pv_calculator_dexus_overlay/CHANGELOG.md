# Changelog – PV Calculator (Dexus Overlay)

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The two artefacts versioned here are:

- **App** (`app/flutter_app/pubspec.yaml`) — user-facing Flutter app.
- **Engine** (`packages/pv_engine/pubspec.yaml`, `kEngineVersion`) — pure-Dart
  simulation library that the app depends on via path.

The About dialog in the app surfaces `appVersion (engine kEngineVersion)`
so a deployed scenario can be tied to an exact engine revision (PRD NFR-05).

## [Unreleased] — engine 0.16.0

Phase 4c — DC-Bus-Solver-Konsolidierung. 30+ Codex review findings
across 7 rounds on the Phase-4b implementation were all
manifestations of the same root cause: the per-bus DC energy
balance was scattered across `_simulateStep`, the dispatch
policies, and `EnergyRouter`. Each layer had partial η / cap /
unit conversions; every fix in one layer left a different one
inconsistent. Phase 4c consolidates the bus-level balance into a
single `DcBusSolver` so future patches converge.

### Changed — Engine

- **New `DcBusSolver`** in `lib/src/dc_bus_solver.dart` owns the
  per-bus, per-step energy allocation atomically. Inputs
  (`pvDcInKwh`, `loadAcShareKwh`, `HybridInverterInfo`,
  `DcBusBattery[]`, `mode`) → outputs (`batteryChargesDcKwh`,
  `batteryDischargesDcKwh`, `bypassAcKwh`, `loadCoveredAcKwh`,
  `dischargeAcKwh`, `curtailedDcKwh`, `inverterAcConsumedKwh`,
  `inverterDcConsumedKwh`). Five-step allocation: load coverage →
  battery charging → hybrid bypass → battery discharge →
  curtailment. Shared AC / DC / edge caps live in one mutable
  budget per call.
- **`_simulateStep`** calls the solver once per DC bus. Global
  load reservation is allocated greedily across hybrid buses in
  declared order; `array → cc` edge η + `maxPowerKw` are honored
  before the controller's own clip + efficiency; `dcBus →
  inverter` edge η + `maxPowerKw` flow through
  `HybridInverterInfo` to the solver.
- **`DispatchContext`** loses 5 Phase-4b fields (`pvDcByBus`,
  `dcBusForBattery`, `dcBusesWithAcPath`, `estimatedBypassAcKwh`,
  `dcReservedForLoadByBus`) and gains a single
  `dcCoupledIndices: Set<int>`. Policies emit per-battery
  CEILINGS (rate cap + headroom); the router / solver cap them
  against actual surplus / load.
- **`EnergyRouter.apply`** loses 4 Phase-4b parameters
  (`batteryDirectDischargeAcLossEff`, `batteryInverter`,
  `inverterAcRemainingKwh`, plus the loaded `skipChargeIndices`
  semantic). Direct discharge for DC-coupled batteries happens in
  the solver; the router gains a separate `skipDirectDischargeIndices`
  to keep them out of step 2. Step 2 returns to the pre-Phase-4b
  simple form.
- **`dispatch_policies.dart`** loses the `_dcChargeRequest`
  helper and all DC-specific branches in the three policies
  (~150 lines net). All policies now emit identical "fill to
  capacity / reserve ceiling" requests irrespective of coupling;
  the solver enforces what's physically feasible.

Net: ~277 lines of engine code removed (449 added, 726 deleted).

### Added — Engine

- **`packages/pv_engine/test/dc_bus_solver_test.dart`** — 13 unit
  tests for the solver: allocation order, batteryFed discharge,
  lossy edges, tight caps, shared inverter, charge-only buses,
  inverter-side vs bus-side cap conversions, and a bus DC ledger
  invariant.
- **`packages/pv_engine/test/dc_dispatch_invariants_test.dart`** —
  property-based backstop. Previously 200 random topologies × 24
  hourly steps; extended (this release) to 250 random topologies
  with multi-bus shared-inverter shapes and a two-sided I6
  invariant plus a new I8 DC-side ledger sanity check.
  Approximately 6000 step-level invariant checks per run cover
  SOC bounds, rate caps, no NaN / negative, grid export limit,
  energy balance with `(1 − η_min⁴) × throughput` slack bound,
  aggregate inverter AC cap, and `pvDcKwh ≥ Σ DC-coupled charges
  + curtailedDcKwh`. The strengthened balance closes the gap
  where Round-8 Finding #2 (`array → cc` edge clip silently
  dropped clipped energy) slipped past the previous one-sided
  `inputs ≥ outputs` check; the multi-bus shapes cover Findings
  #1/#3/#4 which all needed a shared inverter between buses.
  Generator and bound were validated by locally reverting
  Finding #2 — the test fails with a clear seed+step+slack dump
  in that scenario. Any future η / cap / unit-mismatch
  regression fails immediately with the failing seed + step
  dumped.

### Fixed — Engine (caught by the property test on first run)

- Solver `loadCoveredAcKwh` was double-counted in `_simulateStep`:
  both pushed into `pvAcKwh` (where the router treated it as
  exportable surplus) AND added back as self-consumption after
  the router ran. Reported `selfConsumption + gridExport` could
  therefore exceed `pvDcKwh + gridImport - ΔSOC`. Split into
  `solverLoadCoveredAc` + `solverDischargeAcTotal`; subtract from
  router's `pvAcKwh` and `loadKwh` so the router sees only the
  exportable AC and the unmet load.

### Compatibility

- `kEngineVersion` bumps to `0.16.0`.
- AC-only scenarios continue to produce byte-identical results
  (regression-guarded by `dc_coupled_dispatch_test.dart`'s
  `legacy AC-only scenario stays byte-identical`).
- Phase-4b JSON schema v6 still accepted as-is; nothing about
  the persisted shape changes.

## [Unreleased] — engine 0.15.0

Phase 4b — DC-Kopplung & Laderegler. Closes the "planned for future
phases" marker in `packages/pv_engine/lib/src/topology.dart`: the
simulator now actually routes DC-coupled flows (PV → charge
controller → DC bus → battery / hybrid inverter) instead of treating
`BatteryCoupling.dc` as a descriptive marker. Per DC bus, `BusMode`
selects between hybrid (PV bypasses a full battery to the inverter)
and `batteryFed` (PV reaches AC only via the battery). Existing
AC-coupled scenarios stay byte-identical (regression-guarded by
`test/dc_coupled_dispatch_test.dart`).

### Added — Engine
- **`ChargeController`** (MPPT charge controller / Laderegler) value
  type in `lib/src/topology.dart`, with `dcBusId`, multiplicative
  `efficiency`, optional `maxInputKw`, parasitic `standbyW`, JSON
  round-trip and field-level validation.
- **`BusMode { hybrid, batteryFed }`** and a new `DcBus.mode` field.
  Default `hybrid` preserves legacy behaviour; JSON emits `mode`
  only when non-default so legacy projects round-trip byte-stable.
- **`SimulationConfig.chargeControllers`** top-level list, fed into
  `TopologyGraph.fromLegacy` when no explicit topology is given.
  When `topology` is set, controllers MUST live inside it (single
  source of truth — enforced in `validate()`).
- **JSON schema v6** triggered by the new fields. `fromJson` range
  widened to `[1, 6]`; legacy projects continue to round-trip on
  their original schema version.
- **DC-side pre-dispatch in `_simulateStep`**: arrays wired to a
  charge controller via an `array → cc` edge are partitioned off the
  legacy AC path. For each DC bus, PV-DC charges DC-coupled batteries
  without the inverter η, then either flows through a hybrid inverter
  to AC (`hybrid` mode) or is curtailed (`batteryFed` mode).
- **`EnergyRouter.apply(skipChargeIndices: ...)`** parameter so DC-
  coupled batteries are not double-charged from AC surplus.
- **`SimulationStep.dcDirectChargeKwh` / `dcCurtailedKwh`** and the
  matching `SimulationSummary` fields, defaulted to `0.0` so legacy
  consumers compile unchanged. Aggregated across years in
  `_aggregateYears`.
- **Cross-validation rules** in `TopologyGraph.validate` (rules 2-5
  in ROADMAP §Phase 4b): DC-coupled batteries require ≥1 cc on
  their bus; batteryFed buses need exactly one DC battery + one
  outgoing inverter edge and no AC-side PV; no array on both a cc
  and an MPPT path.
- **`kEngineVersion = '0.15.0'`**.

### Added — App
- **`ChargeControllerCatalogEntry`** kind in `component_catalog`
  (efficiency, optional maxInputKw / maxOutputKw / mpptCount /
  standbyW), three sample seed entries.
- **DB schema v2 → v3 migration** relaxes the `component_catalog.kind`
  CHECK to include `'chargeController'` (rebuild-and-rename inside a
  transaction so a failure leaves the table intact).
- **`widgets/forms/charge_controllers_section.dart`** mounted in the
  Results tab between Inverters and Batteries; supports loading
  entries from the catalog picker and free-form entry.
- **BusMode dropdown** per DC bus in the expert-mode topology editor
  (`topology_section.dart`) with inline help on each option.
- **`ConfigSection.chargeControllers`** with keyword routing in
  `classifyValidationMessage` so engine errors land in the right
  card.

### Added — Infra
- **PVGIS caching proxy ROADMAP tick + bookkeeping**. Acknowledges the
  Cloudflare-Worker + R2-bucket proxy that has been live alongside the
  app since commit `81bf635` (May 2026) but was never formally ticked
  off in `docs/ROADMAP.md`. No app/engine code changes — both stay at
  `0.9.0` / `0.14.0` respectively.
  - Worker source: `cloudflare-pvgis-proxy/src/index.ts` — SHA-256
    cache key over 14 canonicalised PVGIS query params, `X-Cache:
    HIT|MISS` response header, transparent `PVGIS-SARAH2` → v5.2 vs.
    everything else → v5.3 routing (v5.3 dropped SARAH2).
  - CI gate: `.github/workflows/ci.yml` `pvgis-proxy` job runs the
    proxy's vitest suite on every push.
  - Manual deploy fallback: `.github/workflows/proxy-deploy.yml`
    (`workflow_dispatch` only — day-to-day deploys go through
    Cloudflare's own GitHub integration).
  - App wiring: `app/flutter_app/lib/config.dart` reads
    `PVGIS_PROXY` from `--dart-define`; `lib/services/pvgis_api.dart`
    surfaces the `X-Cache` flag in the UI. Without the define the app
    falls back to the public PVGIS endpoint.
  - Pages workflow injects the secret only when set
    (`.github/workflows/pages.yml` lines 64, 86, 99–100).
  - Setup guide at `docs/CLOUDFLARE_SETUP.md`; proxy `README.md`
    documents the full deploy flow.
  - `docs/ROADMAP.md` Phase 10 weather-proxy line flipped to `[x]`;
    Global Solar Atlas / cross-source normalisation split out as a
    new "Verschoben" entry with an explicit trigger.

### Added — Proxy tests
- `cloudflare-pvgis-proxy/test/index.spec.ts`: two new cases close
  branch-coverage gaps in `src/index.ts`:
  - **`returns a 502 envelope when the upstream fetch throws`** —
    asserts the `try/catch` around `fetch(upstreamUrl)` (lines
    175–182) returns the `{ error: "PVGIS upstream unreachable",
    detail: … }` JSON body with `Content-Type: application/json`.
  - **`propagates upstream 5xx without caching`** — mirrors the
    existing 4xx test on the `pvgisResponse.ok` gate (line 188), so a
    transient PVGIS 503 is forwarded once and re-issuing the request
    still goes upstream (the error never lands in R2).

### Documentation
- `docs/ARCHITECTURE.md` "Externe Datenquellen" section: one-line
  reference to the optional Cloudflare proxy so the architecture
  overview matches what's actually deployed.
- `cloudflare-pvgis-proxy/README.md`: new "Fehlerbehebung" section
  between Antwort-Header (§10) and Cache-Verwaltung (§11) covering
  the three operator-facing failure modes (`502 upstream unreachable`,
  unexpected `X-Cache: MISS`, 4xx forwarded but not cached).

## [0.9.0] — 2026-05-19 (app) / [0.14.0] — 2026-05-19 (engine)

Phase 10 follow-up — Pareto frontier (cost × autarky). Closes the
ROADMAP "Pareto-Frontier für Optimierer (Kosten × Autarkie)" deferred
item. Additive: every Optimizer run computes the frontier as a
by-product of the existing sweep (no extra simulator calls). When no
tariff is configured, the frontier is empty and the Optimizer page
silently omits the Pareto card — single-objective behaviour is
unchanged.

### Added — Engine
- **`OptimizerResult.paretoFrontier`** (default `const []`) — list of
  non-dominated `OptimizerCandidate`s over (`lifetimeNetCostEur` ×
  `autarkyRate`), sorted by lifetime cost ascending. On the kept points
  autarky is strictly increasing.
- `Optimizer._computePareto` — O(n log n) helper: drops candidates
  with `lifetimeNetCostEur == null`, sorts by (cost asc, autarky desc),
  then a single forward scan keeping points whose autarky exceeds the
  running max. Dedups exact (cost, autarky) ties.
- **Computed from the pre-truncation set**: the frontier is built
  before `OptimizerSpec.topN` slicing, so it is identical regardless of
  `topN`. A non-dominated combo cannot be silently dropped just because
  a different objective put it outside the top slice.
- **`OptimizerResult.allCandidates`** (default `const []`) — full
  pre-truncation list of every successfully simulated candidate, in
  best-first order for the chosen objective. `result.candidates` is
  its `topN` prefix. Lets UI surfaces (e.g. the Pareto scatter cloud)
  plot the complete evaluated sweep rather than the displayed top-N.
- Engine version bumped `0.13.0 → 0.14.0`.

### Added — App
- Optimizer page (`pages/optimizer_page.dart`): new "Pareto frontier"
  card under the existing results table, hidden when
  `paretoFrontier.isEmpty` (i.e. no tariff). Card key
  `Key('optimizer-pareto-card')`.
- New widget `widgets/results/optimizer_pareto_chart.dart` — `fl_chart`
  `ScatterChart` with a `LineChart` overlay tracing the frontier
  through the cloud of all candidates. Frontier dots are larger and
  primary-blue; cloud dots are small and blue-grey. Legend renders
  inline above the chart.
- New widget `widgets/results/optimizer_pareto_table.dart` — compact
  5-column table (battery kWh, inverter kW, PV scale, lifetime cost €,
  autarky %) listing only the Pareto-optimal candidates in
  cost-ascending order. Row keys `Key('optimizer-pareto-row-N')`.
- ARB strings added in `en/de/es/fr`: `optimizerParetoTitle`,
  `optimizerParetoHint`, `optimizerParetoAxisCost`,
  `optimizerParetoAxisAutarky`, `optimizerParetoLegendCloud`,
  `optimizerParetoLegendFrontier`.
- App version bumped `0.8.2 → 0.9.0`.

### Added — Tests
- `packages/pv_engine/test/optimizer_test.dart` — six new cases under
  a `group('Pareto frontier', ...)`:
  - `empty when no candidate has a tariff-derived cost`
  - `frontier is sorted by cost ascending with strictly increasing autarky`
  - `frontier excludes a dominated candidate` (pairwise check over
    every Pareto vs. every candidate)
  - `a clearly dominated combo is not in the frontier` (smallest
    combo is dropped when a strictly better point exists)
  - `frontier is independent of topN` (top 1 vs top 50 produce
    identical frontier identities)
  - `frontier endpoints match the per-objective extrema` (first =
    cheapest, last = highest autarky)
- `app/flutter_app/test/optimizer_page_test.dart` — two new widget
  tests: Pareto card hidden without tariff, Pareto card rendered
  with tariff active.

## [0.8.2] — 2026-05-19 (app) / [0.13.0] — 2026-05-19 (engine)

Phase 10 follow-up — Optimizer NPV / discount rate. Closes the ROADMAP
"NPV / Diskontierungssatz für Optimierer" deferred item. With both new
rates at 0 % the result is byte-identical to 0.12.0 (the legacy formula
`investment + horizon × annual` is a special case of the new geometric
sum), so existing test fixtures and `OptimizerCandidate.toString()`
output are unchanged for default specs.

### Added — Engine
- **`OptimizerSpec.discountRatePct`** (default `0.0`) — annual discount
  rate in % applied to future yearly costs so `lifetimeNetCostEur` is
  reported as a present-value sum. Must be > -100.
- **`OptimizerSpec.priceEscalationPctPerYear`** (default `0.0`) — annual
  electricity-price escalation in % applied to the recurring
  `netCostEur` term. Must be > -100.
- `Optimizer._discountedLifetimeCost` replaces the old
  `investment + horizonYears × netCostEur` closed form with
  `investment + Σ_{y=1..N} netCostEur · (1 + e)^(y-1) / (1 + r)^y`
  where `r = discountRatePct/100`, `e = priceEscalationPctPerYear/100`.
  Reduces to the legacy formula when both rates are zero.
- Engine version bumped `0.12.0 → 0.13.0`.

### Added — App
- Optimizer page gains two NumberFields in the prices card
  (`Key('optimizer-discount-rate')`, `Key('optimizer-price-escalation')`)
  plus a one-line hint that explains the 0/0 = legacy-formula
  shortcut and notes that payback / IRR are still not computed.
- `OptimizerController` forwards both new fields when it rebuilds the
  effective spec from the draft.
- ARB strings added in de/en/es/fr: `optimizerDiscountRate`,
  `optimizerPriceEscalation`, `optimizerDiscountHint`.
- App version bumped `0.8.1 → 0.8.2`.

### Added — Tests
- `packages/pv_engine/test/optimizer_test.dart` — five new cases:
  - `discountRatePct=0 and escalation=0 reproduce the pre-NPV sum`
    (closed-form parity vs. the legacy formula).
  - `discount-only matches the analytic geometric series`
    (horizon=2, r=5 %, closed-form check).
  - `escalation-only matches the analytic geometric series`
    (horizon=3, e=3 %, closed-form check).
  - `discount and escalation cancel when equal` (r=e collapses the
    per-year factor to `1/(1+r)` for every year).
  - `rejects out-of-range discount/escalation rates`
    (-100, -150, NaN).
- `app/flutter_app/test/optimizer_controller_test.dart` —
  `_RecordingRunner` captures the effective spec and asserts both
  rates are forwarded unchanged from the page's spec to the runner.

### Fixed — App (review fixes for PR #32)
- `OptimizerRunner` (native isolate): when `cancel()` lands on the same
  tick the isolate sends its final `OptimizerResult`, the result is now
  dropped and the future fails with `OptimizerCancelledException`
  instead of silently returning the sweep the user tried to abort.
  Previously the listener checked `cancelled` for progress events but
  not for the result message (Copilot).
- `OptimizerController`: notify listeners immediately after assigning
  `_currentHandle` so `canCancel` flips true and the Cancel button
  enables during the isolate-spawn window, rather than only after the
  first progress event arrives (Copilot).
- `OptimizerProgress` docstring: removed the incorrect claim that the
  runner emits a `(0, 0)` event for empty sweeps — the engine always
  falls every empty sweep dimension back to a single baseline value,
  so `total >= 1` (Copilot).

### Changed — App (review fixes for PR #32)
- `OptimizerController` now throttles `notifyListeners()` to integer-
  percent transitions during progress callbacks (≤ 101 notifies per
  run) so a maximal documented sweep (12 × 12 × 12 × 16 ≈ 27 k
  candidates) doesn't trigger 27 k back-to-back Provider rebuilds.
  Mirrors `ProjectController._lastNotifiedPct` (Codex).
- `OptimizerController` gains an `_runGeneration` guard plus a public
  `supersede()` method. With the native isolate path a sweep can keep
  running after the user navigates away and edits another project;
  the page now calls `supersede()` from `dispose()`, which bumps the
  generation, cancels the underlying handle, and clears local state.
  Any late result lands in a higher-generation bucket and is dropped
  by the guards in `runFromDraft`. Mirrors `ProjectController._runGeneration`
  (Codex).

## [0.8.1] — 2026-05-18 (app)

Phase 10 follow-up — Optimizer sweep runs off the UI thread on native,
gains a determinate progress bar, and is now cancellable mid-run. Engine
untouched (`onProgress(done, total)` was already exposed in 0.12.0).

### Changed — App
- **`OptimizerRunner`** (`app/flutter_app/lib/services/optimizer_runner.dart`
  + `_io.dart` / `_web.dart`) mirrors the Phase-9 `SimulationRunner`
  shape: spawns a worker `Isolate` on native, falls back to in-process
  on web (no `dart:isolate`). The engine's per-candidate
  `onProgress(done, total)` callback is surfaced to the UI as an
  `OptimizerProgress` stream.
- **`OptimizerController`** consumes the new runner. Exposes `progress`,
  `cancelled`, `canCancel` plus a `cancel()` method that abruptly kills
  the worker isolate on native. Cancellation surfaces as a dedicated
  `OptimizerCancelledException` so the page can show a "Optimierung
  abgebrochen." banner without piping through the error string.
- **Optimizer page** now renders a determinate `LinearProgressIndicator`
  with a per-frame "X / N Kandidaten" label and a Cancel button. The
  button is disabled on web with a tooltip explaining cancellation is
  only available on native (Dart can't interrupt a synchronous sweep on
  the main isolate).

### Added — Tests
- `test/services/optimizer_runner_test.dart` — exercises the isolate
  runner end-to-end: completion, monotonic progress, parity vs.
  `const Optimizer().run(spec)`, `canCancel` per platform mode, and
  cancel-mid-sweep raising `OptimizerCancelledException`.
- `test/optimizer_controller_test.dart` — controller-level transitions
  for the bits flutter_test can't observe through the page (the
  "running" frame is gone before pump renders): progress propagation,
  cancel-on-in-process is a no-op, cancel-on-cancellable runner settles
  in the cancelled state, `clearResult` resets the cancelled flag.

## [0.8.0] — 2026-05-18 (app) / [0.12.0] — 2026-05-18 (engine)

Phase 10 — Optimizer (Pro). Parametric sweep over battery capacity,
inverter AC output and PV scale (with optional per-array on/off
toggles), ranked by either maximum autarky or minimum lifetime
electricity cost, respecting a hard budget cap.

### Added — Engine
- **`Optimizer`, `OptimizerSpec`, `OptimizerPrices`, `OptimizerObjective`,
  `OptimizerCandidate`, `OptimizerResult`** in
  `packages/pv_engine/lib/src/optimizer.dart`. Pure-Dart, zero new runtime
  deps. Cartesian sweep on `(batteryKwh × inverterKw × pvScale ×
  arraySubset)`; per candidate the optimizer (1) computes a linear
  investment from `OptimizerPrices`, (2) skips over-budget candidates,
  (3) clones the baseline via `fromJson(toJson())` and patches the
  swept fields, scaling battery power and `minSocKwh` proportionally
  to preserve the baseline's C-rate and SOC-floor fraction, (4) forces
  `keepSteps: false` and `simulationYears: 1`, (5) runs the simulator,
  (6) computes `lifetimeNetCostEur = investmentEur + horizonYears ×
  summary.netCostEur` when the baseline has a tariff. Candidates are
  sorted ascending by internal score (`-autarkyRate` for `maxAutarky`,
  `lifetimeNetCostEur` for `minNetCost`) and truncated to `topN`.
  Non-serialised `weatherSource` and `temperatureModel` are re-attached
  from the baseline so the optimizer sees the user's loaded PVGIS data
  instead of falling back to the synthetic model. Failed engine
  validation (e.g. `pvScale = 0`) increments `failedValidation` and
  the sweep continues.
- Engine version bumped `0.11.0 → 0.12.0`.

### Added — App
- **Optimizer page** (`app/flutter_app/lib/pages/optimizer_page.dart`)
  with sweep ranges (min/max/steps per dimension), prices (€/kWp PV,
  €/kW inverter, €/kWh battery), optional budget cap, horizon years,
  objective dropdown, optional-array checkboxes and a top-N results
  table (`widgets/results/optimizer_results_table.dart`).
- **`OptimizerController`** (`lib/state/optimizer_controller.dart`)
  holds the last spec + result, runs `Optimizer.run` in-process on the
  calling isolate using `ConfigDraft.buildForRun()` as baseline so Pro
  gating is honoured. Indeterminate progress indicator while the
  synchronous loop runs (moving the sweep to `dart:isolate` is captured
  as a deferred item in the roadmap).
- **Entry button "Optimieren (Pro)"** in the Results tab, gated
  identically to the existing PDF report button.
- New provider wired into `main.dart` `MultiProvider`.
- L10n keys `optimizer*` added to all four ARBs (de/en/es/fr).
- App version bumped `0.7.0 → 0.8.0` (`0.7.0` shipped Catalog v2; this
  release stacks on top of it).

## [0.7.0] — 2026-05-18 (app)

Phase 10 — Catalog v2 management UI and JSON import/export. Closes the
in-app CRUD + user-catalog file I/O sub-items of the Phase 10 component
library deferred entry. Engine and `component_catalog` package versions
are unchanged.

### Added — App
- **Drawer entry "Komponentenbibliothek"** (`Key('drawer-catalog')`)
  opens the new `CatalogManagementPage` from the projects-tab drawer.
- **`CatalogManagementPage`** with three tabs (Module / Wechselrichter /
  Batterien). Each tab lists user entries (editable, deletable) above a
  read-only seed section; a "Als eigenen Eintrag kopieren" action on
  every seed row pre-fills the editor with the seed values under a
  fresh id and a `"Eigene Kopie — "` manufacturer prefix.
- **`CatalogEntryEditor`** — full-screen form with kind-specific fields
  (module / inverter / battery) backed by `CatalogEntry.validate()`.
  IDs auto-slug from manufacturer/model on create, lock on edit. A
  collision dialog confirms overwrites when a freshly typed id already
  exists in the user source.
- **JSON import/export** (`catalog_file_io.dart`) using the seed-shaped
  envelope `{ version: 1, modules, inverters, batteries }`. Import goes
  through a dry-run confirmation dialog showing "N neu, M ersetzen"
  before any writes; export skips file I/O entirely when no user
  entries exist. File size cap matches the project importer (1 MiB).

### Added — `CatalogRepository`
- `userEntries()` / `seedEntries()` — read accessors that expose the
  individual sources for management UIs that need to distinguish them.
- `importUserEntries(entries)` — bulk upsert returning
  `({added, updated})` counts; invalidates the merge cache and notifies
  listeners exactly once.
- `previewImportConflicts(candidates)` — read-only dry-run partition
  for confirmation dialogs.
- `exportUserCatalogJson()` — pretty-printed JSON in the seed shape.
  User-exported catalogs round-trip back through `parseSeedCatalog`.

### Refactored
- Extracted `summariseCatalogEntry()` and `catalogRoleLabel()` into a
  shared helper (`widgets/catalog/catalog_entry_summary.dart`); the
  existing picker sheet delegates instead of carrying its own
  per-kind subtitle code.

### Changed
- App version `0.6.0 → 0.7.0` (`pubspec.yaml`, `lib/app_info.dart`).
  Engine `kEngineVersion` and `component_catalog 0.1.0` unchanged —
  this slice is consumer-side only.
- No sqlite schema migration: the Phase-10 `component_catalog` table
  already supports the full CRUD path via the `payload_json` column.

## [0.6.0] — 2026-05-18 (app) / [0.11.0] — 2026-05-18 (engine) / [0.1.0] — 2026-05-18 (component_catalog)

Phase 10 — Component library (local seed + user-pluggable). Plus two
deferred items closed: Phase-10 monthly cashflow aggregation and the
matching €-cost CSV / monthly-table / PDF columns.

### Added — Engine
- **`SimulationStep.importCostEur` / `exportRevenueEur`** (non-nullable,
  default `0.0`). The `_StepBuffer` already carried these columns from
  the Phase-10 tariff work; exposing them on `SimulationStep` makes
  per-step cashflow available to aggregators and CSV exporters.
- **`MonthlyBucket.importCostEur` / `exportRevenueEur`** plus derived
  `netCostEur` getter. `SummaryAggregator.monthly` now accumulates both
  fields on the buffer fast path and the list fallback. Sums match
  `SimulationSummary.importCostEur` within `1e-9` on a flat-tariff
  fixture.
- **`stepsCsv`** appends two trailing columns (`importCostEur`,
  `exportRevenueEur`). **`monthlyCsv`** appends three
  (`importCostEur`, `exportRevenueEur`, `netCostEur`). Columns are
  always present so the CSV schema stays deterministic regardless of
  whether a tariff was configured (zero-tariff scenarios emit zeros).
- Engine version bumped `0.10.0 → 0.11.0`.

### Added — New package `component_catalog` (`0.1.0`)
- Pure-Dart sibling of `pv_engine`. Zero runtime deps.
- **`ComponentKind`**, **`CatalogEntry`** sealed base, plus
  `ModuleCatalogEntry` / `InverterCatalogEntry` / `BatteryCatalogEntry`
  data classes (with `validate()`, `toJson`, `fromJson`).
- Catalog-local **`CatalogInverterRole`** enum keeps the package
  decoupled from `pv_engine`; consumers map to `InverterRole` at the
  call site.
- **`CatalogSource`** interface with read-only base + opt-in
  `isWritable` for sources that can `upsert` / `delete`.
- **`InMemoryCatalogSource`** for tests and hard-coded fallbacks.
- **`MergedCatalog`** composes a priority-ordered list of sources;
  later sources win on `id` collision. Caches `fetch()` results until
  `invalidate()` is called.
- **`parseSeedCatalog(jsonText)`** parses the bundled JSON shape
  `{ version, modules[], inverters[], batteries[] }`.
- **Bundled seed asset** `assets/components_seed_v1.json` ships 3–5
  generic entries per kind (400 W / 440 W / 500 W / 410 W modules;
  string 5 kW / 10 kW, hybrid 8 kW, micro 800 W inverters; 5 / 10 /
  15 kWh LFP batteries). Asset is declared in the package's pubspec so
  Flutter bundles it automatically when consumed via a path dependency.

### Added — App
- **Catalog adapters** under `lib/catalog/`:
  - `BundledSeedCatalogSource` — loads the package's JSON via
    `rootBundle`, caches per-app-lifetime.
  - `SqliteUserCatalogSource` — writable, backed by the new
    `component_catalog` table; payload stored as JSON so new fields
    on existing kinds need no schema work. Adding a new
    `ComponentKind` still requires widening the table's `kind`
    CHECK constraint.
  - `CatalogRepository` (Provider-registered `ChangeNotifier`) composes
    seed + user via `MergedCatalog`, exposes
    `modules()` / `inverters()` / `batteries()` and
    `addUserEntry` / `deleteUserEntry`.
- **`CatalogPickerSheet`** modal bottom-sheet picker
  (`lib/widgets/catalog/catalog_picker_sheet.dart`) — search field,
  filtered list, optional `filter` predicate (used by the micro-
  inverter banks section to constrain to
  `microInverter800W` entries).
- **"Aus Bibliothek wählen" buttons** in four form sections:
  - Arrays tab — prompts for module count, prefills
    `peakKw = peakKwPerModule × count`, plus temperature coefficient,
    NOCT and degradation.
  - Inverters section — prefills `maxAcKw`, `maxDcInputKw`,
    `efficiency`, `role`, `label`.
  - Batteries section — prefills capacity, charge / discharge,
    round-trip efficiency, min-SOC, `label`.
  - Micro-inverter banks section — filtered inverter picker, prefills
    `unitRatedPowerW` and `inverterEfficiency`.
- **Sqlite schema v1 → v2** migration adds the `component_catalog`
  table and a `kind` index. `database.dart` `_upgrade` ladder grew its
  first real step (`_migrateV1ToV2`). Existing v1 stores upgrade once,
  in place; no project / scenario / run data is touched.
- **MonthlyTable** grows three optional cashflow columns
  (`Bezugskosten`, `Einspeise-Erlös`, `Netto`). Caller passes
  `showCashflow: summary.importCostEur != null` so the columns appear
  exactly when the run was scored against a tariff.
- **PDF report** appends a compact "Monatlicher Cashflow" section
  (12-row table) whenever the summary carries cashflow KPIs.
- ARB strings added in de/en/es/fr: `monthlyColImportCost`,
  `monthlyColExportRevenue`, `monthlyColNetCost`,
  `pdfSectionMonthlyCashflow`, `catalogPickButton`,
  `catalogPickerTitle`, `catalogSearchHint`, `catalogEmptyState`,
  `catalogModuleCountPrompt`, `commonOk`.
- App version bumped `0.5.0 → 0.6.0`.

### Changed — App
- `CatalogRepository.standard(db)` is registered in `main.dart`'s
  `MultiProvider` alongside the existing repositories.
- `flutter_app/pubspec.yaml` gains a path dependency on
  `component_catalog`.

### Changed — CI
- `.github/workflows/ci.yml` grows a `component-catalog` job that runs
  `dart pub get / analyze / test` against the new package.

## [0.5.0] — 2026-05-18 (app) / [0.10.0] — 2026-05-18 (engine)

Phase 10 — CSV load-profile import. Plus two deferred items picked up:
Phase 8 structured engine warnings and the Phase 9 C4b buffer-column
aggregator refactor.

### Added — Engine
- **`parseLoadProfileCsv`** in `lib/src/load_profile_csv.dart` — pure-
  Dart parser for Smartmeter / Home Assistant / Shelly CSV exports.
  Auto-detects delimiter (`;`, `,`, tab), header row, and value column
  kind (power W/kW or energy Wh/kWh, inferred from header annotations
  and value magnitude). Sub-hourly samples aggregate into 24 hourly
  buckets and multi-day inputs average into one representative day.
  ISO 8601 timestamps with timezone offsets are parsed by wall-clock
  components so the recorded local hour is preserved.
- **`SimulationWarning`** + **`SimulationConfigWarnings.nonBlockingWarnings()`**
  — engine-side design rules (inverter oversizing, bank-vs-battery
  discharge cap, deep min-SOC). Emits stable codes plus structured
  args; the UI maps each code to its form section and appends the
  one UI-only hint (`irradiance-missing`) that depends on a draft
  cache the engine doesn't see. A future backend can now surface the
  same warnings without spinning up the UI layer.

### Changed — Engine
- **`SummaryAggregator` reads `_StepBuffer` columns directly** when
  the input is the `_StepListView` returned by `SimulationResult.steps`.
  Achieved by converting `summary_aggregator.dart` into a `part of`
  file so the engine-private buffer stays internal. Plain
  `List<SimulationStep>` inputs (hand-crafted in tests) still take
  the unchanged list-fallback path. Benchmark:
  `monthly + bankRuntime` over 35 040 quarter-hourly steps drops
  from ~10.5 ms to ~0.4 ms on the same desktop (~27× faster) — the
  Phase 9 C4b deferred item is now closed.
- Engine version bumped `0.9.0 → 0.10.0`.

### Changed — App
- **`LoadSection`** grows an "**CSV importieren**" button next to the
  daily-kWh field; importing replaces both `dailyKwh` and the hourly
  shape, and the hint text switches to a one-line summary that calls
  out the imported peak hour. Translations added in de/en/es/fr.
- **`FileIo.importLoadProfileCsv`** wraps the parser and the
  `file_selector` flow (1 MB cap, mirrors the existing
  `importConfig` pattern).
- **`ConfigDraft.validationWarnings()`** delegates the three
  arithmetic rules to `build().nonBlockingWarnings()` and only
  appends the `irradiance-missing` UI-only hint locally. Existing
  widget tests pass unchanged because codes and arg keys are
  byte-identical.
- App version bumped `0.4.0 → 0.5.0`.

## [0.4.0] — 2026-05-18 (app) / [0.9.0] — 2026-05-18 (engine)

Phase 10 — Multi-year simulation, tariff model & PDF reports.

### Added — Engine
- **`SimulationConfig.simulationYears`** (default `1`, max `30`). When
  `> 1`, the engine runs the existing per-year linear path once per
  year with each array's `peakKw` derated by
  `(1 - degradationPctPerYear/100)^year` and the SOC ledger carried
  across year boundaries. The configured warm-up (singleWarmUp) runs
  once in year 0 only. Schema bump to v4 only when a multi-year or
  degradation knob is non-default.
- **`PvArray.degradationPctPerYear`** (default `0.0`). Annual module
  power loss in %/year; only effective with `simulationYears > 1`.
- **`SimulationSummary.perYearSummaries`** (default `[]`). Length
  equals `simulationYears` for multi-year runs, empty otherwise. The
  top-level summary is the scalar sum across all years.
- **`SimulationSummary.toJson` / `fromJson`** — engine-side
  serialisation so per-year detail survives a persistence round-trip.
- **`TariffConfig`** in `lib/src/tariff.dart`: flat €/kWh import /
  export prices plus optional 24-slot time-of-use schedules.
  Validated for non-negative prices and length 24.
- **`SimulationConfig.tariff`** (nullable). When non-null, the
  simulator multiplies finalised `gridImportKwh`/`gridExportKwh` by
  the per-hour tariff slot **after** dispatch step 6 — the locked
  1..6 dispatch order is preserved. Schema v5 is emitted only when a
  tariff is configured.
- **`SimulationSummary.importCostEur` / `exportRevenueEur` /
  `netCostEur`** — nullable cashflow KPIs, populated whenever a
  tariff is configured.

### Changed — Engine
- `keepSteps: true && simulationYears > 1` retains only the final
  year's per-step data. Concatenation across years would corrupt
  `SummaryAggregator.monthly`'s `dayOfYear` keying.
- Engine version bumped `0.7.0 → 0.8.0` (multi-year + degradation)
  then `0.8.0 → 0.9.0` (tariff model & cashflow KPIs).

### Added — App
- **Simulationsjahre NumberField** in the Auswertung tab's
  simulation-parameters tile, behind the existing `kProFeatures`
  Pro flag. Disabled with a `(Pro)` suffix in free builds.
- **Per-array `degradationPctPerYear` NumberField** in the PV-Arrays
  tab — shown unconditionally since `0.0` is a no-op default.
- **`TariffSection`** in `widgets/forms/tariff_section.dart`: master
  enable switch, flat €/kWh fields (Free), and a 24-slot TOU grid
  (Pro-only, behind `kProFeatures`).
- **Cashflow KPIs** (`Bezugskosten`, `Einspeise-Erlös`,
  `Netto-Stromkosten`) rendered on the Auswertung tab when a tariff
  is configured.
- **PDF report export (Pro)** — `services/pdf_report.dart` builds an
  A4 report with title block, KPI summary, per-year breakdown,
  monthly table, PV arrays, micro-inverter bank coverage, warnings,
  and an AGPL footer (plus a synthetic-irradiance disclaimer when
  applicable). New "Bericht exportieren (PDF)" button on the
  Auswertung tab; disabled with a `(Pro)` tooltip in free builds.
- Adds `package:pdf` and `package:printing` as Flutter-app-only
  dependencies; engine remains zero-runtime-dep.

### Changed — App
- `_ResultsBody` accepts injected `proFeatures` and `onSharePdf` so
  widget tests can flip the gate without `--dart-define`.
- `NumberField` gains an `enabled` flag for the new Pro gates.
- Persistence helpers in `simulation_run_repository.dart`
  serialise `SimulationSummary.perYearSummaries` so multi-year
  scenario runs survive in `simulation_runs.summary_json`.
- App version bumped `0.3.0 → 0.4.0`.

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
- Pre-Phase-9 baseline:           hourly 64.8 ms,  quarterHourly 251.2 ms
- After C3 (solar geometry):      hourly 60.2 ms,  quarterHourly 225.5 ms
- After C4 (accumulator):         hourly 55.7 ms,  quarterHourly 219.1 ms
- After C4a (Float64List buffer): hourly 41.0 ms,  quarterHourly 170.8 ms

Cumulative ~37 % faster hourly, ~32 % faster quarter-hourly. The
allocation-pressure win matters more than the wall-clock number: the
hot loop no longer allocates 35 040 `SimulationStep` objects and
~245 000 unmodifiable `List<double>` wrappers per quarter-hourly
year, which is exactly the GC pressure that hides on a fast desktop
and surfaces as jank on a mid-range smartphone.

Report-render cost is now well off the critical path:
- `monthly + bankRuntime` over a 35 040-step result: ~10.5 ms desktop.

A new manual `dart run benchmark/year_sim.dart` harness captures these
numbers reproducibly. It runs both `keepSteps: true` and `false` for
each `TimeStep`, plus the report-render cost.

### Verschoben (Phase 9)
- **Column-reading `SummaryAggregator`** (the originally planned C4b).
  Measured cost of the existing list-iterating path on the columnar
  buffer is ~10.5 ms desktop / ~50–100 ms mobile estimate for one full
  monthly + bankRuntime render — 6 % of the simulator runtime and well
  inside the 5 s budget. Refactoring `SummaryAggregator.monthly /
  bankRuntime / bankDaily` to read `_StepBuffer` columns directly would
  require either making `StepBuffer` public API or restructuring
  `lib/src/summary_aggregator.dart` as `part of pv_engine.dart`.
  Re-open if a Phase 10 feature (mehrjährige Simulation, Optimierer-
  Sweep, multi-scenario dashboard) starts running the aggregator
  hundreds of times per session, or mobile profiling shows the render
  path itself as the bottleneck.

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
