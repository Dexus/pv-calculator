# component_catalog

Pure-Dart catalog of PV components (modules, inverters, batteries) used to
prefill the calculator's input forms. Zero runtime dependencies — the
package stays usable from Flutter UIs, CLI tools and future server code
alike.

## Public surface

- `ComponentKind` — enum: `module`, `inverter`, `battery`.
- `CatalogEntry` — sealed base type. All entries carry
  `id`, `manufacturer`, `model`, optional `sourceUrl` / `notes`.
- `ModuleCatalogEntry` / `InverterCatalogEntry` / `BatteryCatalogEntry` —
  pure data classes with `validate()`, `toJson()`, `fromJson()`.
- `CatalogInverterRole` — local enum (`grid`, `batteryCoupled`,
  `microInverter800W`). The Flutter app maps this 1:1 to
  `pv_engine`'s `InverterRole` at the consumption point so this package
  does not depend on `pv_engine`.
- `CatalogSource` — abstract source interface. Implementations:
  - Return a `Future<List<CatalogEntry>>` from `fetch()`.
  - Set `isWritable` and override `upsert` / `delete` if mutable.
- `InMemoryCatalogSource` — useful for tests and hard-coded sources.
- `MergedCatalog` — composes a list of sources in **priority order**.
  Later sources win on `id` collision (so user overrides beat the
  bundled seed). Caches `fetch()` results; call `invalidate()` after
  writes.
- `parseSeedCatalog(jsonText)` — pure-function parser for the bundled
  seed JSON shape `{ version, modules[], inverters[], batteries[] }`.

## Adding a new source

```dart
class MyCatalogSource implements CatalogSource {
  @override bool get isWritable => false;
  @override Future<List<CatalogEntry>> fetch() async => …;
  // upsert / delete inherit `throw UnsupportedError` from the base.
}
```

Plug it into a `MergedCatalog([seed, myNewSource, userSqlite])`.

## What this package does not do

- No I/O: Flutter's `rootBundle`, `dart:io` `File`, `package:sqlite3`,
  `package:http` etc. live in adapters that *depend on* this package,
  not the other way around.
- No engine awareness: the consuming app maps catalog enums to
  `pv_engine` types.
