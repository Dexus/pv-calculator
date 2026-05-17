# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository overview

This repo contains **three parallel implementations** of the same PV (photovoltaic) calculator concept, at different maturity levels. Understanding which one a task targets is the first step.

1. **`pv_calculator_pvgis_clientv4pgis.html`** — single-file production web app. Deployed to GitHub Pages as `index.html` via `.github/workflows/pages.yml` on every push to `main` that touches the HTML file. This is the **functional reference** for what the simulation must do (PVGIS import, PV + battery + 800 W micro-inverter, SOC carry-over, pre-run year, 24h simulation). Has no build step — open directly in a browser or serve with `python3 -m http.server 8000`.

2. **`pv_calculator_dexus_overlay/`** — the **active development target**: a Flutter app backed by a pure-Dart simulation engine. Covered by the `CI` workflow (`.github/workflows/ci.yml`). All new feature work goes here.
   - `packages/pv_engine/` — pure-Dart domain + simulation (no Flutter deps).
   - `app/flutter_app/` — Flutter UI that depends on `pv_engine` via path dependency.

3. **`pv-calculator-repo-content/`** — an **older starter skeleton** for the Flutter app (different package name `pv_calculator`, different model shapes like `SimulationSummary.acPvKwh` vs the overlay's `pvAcKwh`). Not in CI. Treat as legacy/reference; do not extend it unless explicitly asked. New work should go to the `_dexus_overlay/` tree.

The single-file HTML and the overlay implementations have **divergent type names** for the same concepts — when porting logic from the HTML reference into Dart, restate it in the overlay's type model rather than mirroring HTML variable names.

## Build, test, lint

### Engine (`pv_calculator_dexus_overlay/packages/pv_engine/`)

```bash
cd pv_calculator_dexus_overlay/packages/pv_engine
dart pub get
dart analyze
dart test
dart test --name 'micro inverter is capped'   # run a single test by name
dart run bin/example.dart                       # smoke-run a one-year simulation
```

Requires Dart SDK `^3.9.0`. Lints come from `package:lints`.

### Flutter app (`pv_calculator_dexus_overlay/app/flutter_app/`)

```bash
cd pv_calculator_dexus_overlay/app/flutter_app
flutter pub get
flutter analyze
flutter test
flutter test test/widget_test.dart -p chrome    # single test file
flutter run
```

Requires Flutter `>=3.35.0`, Dart `^3.9.0`. If platform folders are missing (fresh checkout on a new machine), regenerate them without overwriting `lib/`:

```bash
flutter create --platforms=android,ios,web .
flutter pub get
```

### CI mirror

`.github/workflows/ci.yml` runs `dart pub get / analyze / test` against the engine and `flutter pub get / analyze / test` against the Flutter app on every push and PR. Run those four commands locally before pushing to keep CI green.

## Architecture — engine and dispatch

The engine (`packages/pv_engine/lib/pv_engine.dart`) is intentionally a **single file** holding domain types plus the simulator. Public surface, in order:

- `PvArray`, `Inverter` (with `InverterRole.grid | microInverter800W | batteryCoupled`), `BatteryConfig`, `LoadProfile` — value types with `validate()`.
- `SimulationConfig` — aggregates the above plus `timeStep`, `days`, `preRunDays`, `gridExportLimitKw`, `latitudeDeg`.
- `SimulationStep` / `SimulationSummary` / `SimulationResult` — outputs.
- `PvSimulator.run(config)` — the entry point.

**Dispatch order per timestep** (enforced by `_simulateStep`, must be preserved in any change):

1. Sum DC kWh per array, group by `inverterId`.
2. Apply inverter efficiency, then cap per-inverter AC at `effectiveMaxAcKw * stepHours`. Overshoot becomes `curtailedKwh`. **`InverterRole.microInverter800W` forces the cap to ≤ 0.8 kW** regardless of `maxAcKw` (`Inverter.effectiveMaxAcKw`).
3. Self-consumption from PV covers load first.
4. Surplus charges the battery (limited by `maxChargeKw * stepHours` and remaining capacity, using `chargeEfficiency = sqrt(roundTripEfficiency)`).
5. Battery discharges to cover remaining load (limited by `maxDischargeKw`, `minSocKwh`, and `dischargeEfficiency`).
6. Remaining surplus becomes `gridExportKwh`, optionally capped by `gridExportLimitKw` (overflow → `curtailedKwh`).

**SOC carry-over via pre-run**: the simulator iterates from `dayIndex = -preRunDays` to `days - 1`. Steps with `dayIndex < 0` advance SOC but are **not** appended to `steps[]`. This is how `BatteryConfig.initialSocKwh` stabilises before reporting begins — preserve this when changing the loop.

The `_dcPowerKw` model is **synthetic** (sin curve over a season-shifted day length, plus azimuth/tilt penalties). It is explicitly a placeholder for a real PVGIS/irradiance integration — when extending it, keep it isolated behind the same call signature so an adapter can replace it.

## Architecture — Flutter app

`app/flutter_app/lib/main.dart` is currently a one-screen demo (`DashboardPage`) that constructs a hardcoded `SimulationConfig`, runs `PvSimulator`, and renders KPI cards from `SimulationSummary`. The hard rule from `pv_calculator_dexus_overlay/AGENTS.md`:

> Flutter widgets may display simulation results and collect input, but must not contain dispatch or PV core calculations. Battery dispatch, inverter limiting, 800 W micro-inverter capping, SOC carry-over and export/import must remain separately testable in `packages/pv_engine`.

When you add input forms, persistence, or PVGIS adapters, route them through `pv_engine` types — never reimplement the simulation in widgets.

## Project conventions

- **License is AGPL-3.0.** Any feature that could later be deployed as a web/backend service must preserve source-availability obligations.
- **No secrets in code.** No API keys, tokens, or credentials in committed files. PVGIS integration in the HTML prototype is intentionally key-less; keep it that way in Dart adapters too.
- **Tests for every simulation change.** Any change to dispatch, inverter limiting, SOC, or export logic needs a unit test in `packages/pv_engine/test/`. Use tolerances (`closeTo`, `lessThanOrEqualTo … + 1e-9`), never exact float equality — see existing tests for the pattern.
- **Synthetic vs. real models must be labelled.** The current irradiance model is a demo fallback; do not present it as a validated yield forecast in UI strings, docs, or commit messages.
- **No new runtime dependencies without justification.** `pv_engine` has zero runtime deps by design — keep it that way so it stays usable from CLI/server contexts.
- **`pubspec.lock` policy** (`.gitignore`): the Flutter app's lockfile is committed; the engine library's lockfile is ignored.
- **Don't edit `pv_calculator_pvgis_clientv4pgis.html`** for new feature work — it's the reference prototype and the deployed Pages site. Changes there trigger a Pages redeploy.
- **Always record deferred work in the docs.** When a task is partially completed, scoped down, or a review surfaces follow-ups that aren't being fixed in the same commit, capture them before ending the session. Default location: a `Verschoben` / `Deferred` subsection under the relevant phase in `pv_calculator_dexus_overlay/docs/ROADMAP.md`. If the work belongs to a more specific doc (e.g. architectural debt → `ARCHITECTURE.md`, starter task → `CODEX_FIRST_TASKS.md`), note it there and cross-reference from the roadmap. Each entry should state the gap in one sentence, point at the relevant file/PR, and note the trigger for picking it up later. Never rely on commit messages or PR comments alone — those rot out of view.

## Documentation map

When the user asks "where is X documented", these are the canonical sources (most are in German):

- `pv_calculator_dexus_overlay/AGENTS.md` — agent rules, architecture constraints, build commands. The authoritative ruleset for the overlay tree.
- `pv_calculator_dexus_overlay/docs/PRD.md` — product requirements (MVP scope, non-goals).
- `pv_calculator_dexus_overlay/docs/ARCHITECTURE.md` — layer diagram and module responsibilities.
- `pv_calculator_dexus_overlay/docs/ROADMAP.md` — phased plan (engine → MVP app → real PV data → product quality).
- `pv_calculator_dexus_overlay/docs/CODEX_FIRST_TASKS.md` — concrete starter tasks.
- `pv-calculator-repo-content/docs/` — older but more detailed dispatch-pipeline and GitHub workflow notes; consult for historical context only.
- `docs/research-req.txt` — original user requirement (German).
- `docs/*.md` — prd and architecture and other informations with highest priority


# Behavioral guidelines to reduce common LLM coding mistakes. 

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.