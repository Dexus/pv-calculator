# pv_calculator_app

Flutter UI for the PV Calculator. Pure-Dart simulation engine lives in
`packages/pv_engine`; this app collects inputs, displays results, and now
(Phase 7) persists projects, sites, scenarios and simulation runs via
SQLite.

## Run / test

```bash
flutter pub get
flutter analyze
flutter test
flutter run                       # native (recommended for the smoke list)
flutter run -d chrome             # web (see "Browser persistence" below)
```

CI mirrors `flutter pub get / analyze / test` (`.github/workflows/ci.yml`).

## Persistence (Phase 7)

The canonical store is a `package:sqlite3` database opened in
`lib/persistence/database.dart`. Four relational tables plus an `app_meta`
KV row carry the project ▸ site ▸ scenario ▸ simulation-run hierarchy and
the on-disk schema version. Repositories
(`project_repository.dart`, `scenario_repository.dart`,
`simulation_run_repository.dart`) own the SQL; everything else talks to
those.

On startup, `SharedPreferencesMigration` imports any legacy
`pv_project:*` entries into the new schema once. It is idempotent
(`app_meta('sp_migrated_v1')`) and leaves the SP keys in place as a
read-only fallback.

### Runtime dependencies

| Package                | Why                                              |
| ---------------------- | ------------------------------------------------ |
| `sqlite3`              | Pure-Dart bindings, used directly (no codegen).  |
| `sqlite3_flutter_libs` | Bundles the native sqlite3 shared library.       |
| `path_provider`        | Resolves the app-documents directory on native.  |
| `path`                 | Joins the sqlite file path portably.             |

The engine itself remains zero-runtime-dep; sqlite3 only enters here.

### Browser persistence

On web, `WasmDatabase.open` (via `package:sqlite3`'s WASM build) picks
the best of OPFS → IndexedDB → in-memory at runtime. Until the
`sqlite3.wasm` + `drift_worker.js` assets land under `web/` (tracked in
`docs/ROADMAP.md` §Phase 7 Verschoben), the web build falls back to
**in-memory** with a logged warning — project data won't survive a
reload until the asset is bundled.

To verify which tier was chosen at runtime, inspect the startup log line:

```
main: AppDatabase storage tier = native|memory.
```

## Phase-7 manual smoke list

After any persistence-layer change, walk through these end-to-end to
catch UX regressions that `flutter test` can't see:

1. **Migration.** Seed `shared_preferences` with a legacy
   `pv_project:Demo` entry, then launch and confirm the project + a
   "Default" scenario appear under Projekte.
2. **CRUD.** Create a fresh project, add two scenarios, edit one,
   rename one, delete one — list reflects every step after restart.
3. **Duplicate.** Duplicate a scenario, edit its battery capacity,
   verify both scenarios persist independently and the duplicate's
   `inputHash` differs from the source (visible in the subtitle).
4. **Comparison.** Check two scenarios, tap **Vergleichen (2)**, run,
   confirm both the KPI table and the bar chart render. Close and
   reopen — the comparison resolves from cache (the "Quelle" column
   shows `Cache`).
5. **Hashed export.** Export a scenario as JSON; confirm top-level
   `engineVersion` and `inputHash` keys. Re-import the same file;
   verify it loads without complaint.
6. **Backwards compatibility.** Import an older bare-config JSON (no
   envelope) — it loads and gets a freshly computed hash.
