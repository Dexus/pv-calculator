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

On web, `connection_web.dart` loads `web/sqlite3.wasm` (bundled in this
repo — pinned to the version that matches `package:sqlite3`) and stores
the sqlite file in an `IndexedDbFileSystem` keyed by the same
`pv_calculator.sqlite` name used on native. Project data survives
reloads on the same origin; browsers may evict it under storage
pressure, the same way they evict any other IndexedDB content. OPFS
(which would close the async-flush window between sqlite writes and IDB
commits) still needs a worker bootstrap and stays deferred — see
`docs/ROADMAP.md` §Phase 7 Verschoben.

Native (mobile/desktop) builds keep a real file under
`getApplicationDocumentsDirectory()`, so project data persists normally.

To verify which tier was chosen at runtime, inspect the startup log line:

```
main: AppDatabase storage tier = native|indexedDb|memory.
```

### Updating sqlite3

If you bump `package:sqlite3` in `pubspec.yaml`, also refresh the
matching wasm bundle:

```bash
curl -L -o web/sqlite3.wasm \
  https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-<version>/sqlite3.wasm
```

A mismatched wasm version causes runtime errors on the first
`AppDatabase.open()` call in the browser.

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
