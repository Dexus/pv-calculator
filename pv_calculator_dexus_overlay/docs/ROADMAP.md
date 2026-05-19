# Roadmap – PV Calculator (Dexus Overlay)

Basiert auf PRD v0.1 und Architekturkonzept v0.1 (15. Mai 2026).

Kanonische Quellen (alle „PRD FR-…" und „Architektur Kap. …" Referenzen in dieser Datei zeigen hierauf):

- `../../docs/PRD_PV_Calculator_Flutter_App.md` — vollständiges PRD mit funktionalen Anforderungen (FR-…), Akzeptanzkriterien und User Stories.
- `../../docs/Architekturkonzept_PV_Calculator_Flutter_App.md` — Architekturkonzept mit Energiefluss-Pipeline, Modulgrenzen und Persistenzdesign.
- `./PRD.md` / `./ARCHITECTURE.md` — verdichtete Overlay-Sichten dieser Quellen, fokussiert auf den MVP-Umfang dieses Repos.

---

## Phase 1 – Repo-Codebasis ✓

- `AGENTS.md` hinzufügen.
- Pure-Dart-Engine kompilierbar machen.
- Engine-Tests ausführen und ergänzen.
- Flutter-Projektgerüst prüfen.
- CI grün bekommen.

---

## Phase 2 – MVP-App ✓

- [x] Eingabemasken für PV-Arrays, Wechselrichter, Batterien (Mehrfach-Speicher) und Lastprofil.
- [x] Simulation starten und KPIs anzeigen.
- [x] Monats-Tabelle inkl. CSV-Export von Schritten und Monatswerten.
- [x] Projekt als JSON speichern/laden (lokale Liste über `shared_preferences`, plus Datei-Import/Export über `file_selector`).
- [x] Engine-API erweitert: `SimulationConfig.batteries` als Liste, schemaversionierte JSON-Serialisierung mit Legacy-Migration des einzelnen `battery`-Feldes.

---

## Phase 3 – Fachliche Genauigkeit ✓

- [x] PVGIS-/Wetterdaten-Adapter: `IrradianceSource`-Abstraktion, `SyntheticIrradianceSource` (Demo-Fallback), `HourlyWeatherSeries` (8760-Slots pro Array), `parsePvgisHourlyJson` für PVGIS-`seriescalc`-Dokumente, `PvgisHourlyData.toAveragedYear()` als TMY-Mittelwertbildung.
- [x] Temperatur-/Verlustmodelle: `NoctTemperatureModel` und `FaimanTemperatureModel`. `PvArray.temperatureCoefficientPctPerC` und `nominalOperatingCellTempC`.
- [x] MPPT-/String-nahe Wechselrichtermodellierung: `Inverter.maxDcInputKw` clippt DC-Energie vor der Wechselrichter-Effizienz, Überschuss in `curtailedKwh`.
- [x] Referenzvergleiche: `reference_yield_test.dart` prüft 1-kWp-Süddach gegen Korridor, 800-W-Microclipping- und Overcast-Tests.
- [x] UI-Anbindung des PVGIS-JSON-Imports pro Modulfeld mit Hybrid-Fallback auf Demo-Modell.

---

## Phase 4 – Topologie & erweitertes Dispatch ✓

Ziel: Mehrere PV-Arrays mit individuellen Ausrichtungen, gerichteter Energiegraph, erweiterte Dispatch-Policies (PRD FR-03, FR-08, FR-09; Architektur Kap. 4).

- [x] `TopologyGraph`-Modell in `pv_engine`: DC-Bus, AC-Bus, MPPT-Knoten, Kanten mit Wirkungsgrad und Leistungslimit (`src/topology.dart` + `TopologyGraph.fromLegacy`).
- [x] Arrays auf getrennte MPPTs/Busse verdrahten *im Modell* (per `PvArray.inverterId` und `fromLegacy`-Adapter).
- [x] Dispatch-Policies als austauschbares Interface: `SelfConsumptionFirst`, `BatteryReserve`, `ConstantFeed24h`, `TimeWindowFeed`, `GridAssist` (`src/dispatch_policy.dart`, `src/dispatch_policies.dart`).
- [x] `MicroInverterBank`-Modell: Anzahl × Einheitsleistung, Zeitplan, `minSocShutdown`, Shortfall-Tracking (`src/micro_inverter_bank.dart`, `src/energy_router.dart`).
- [x] Tests: Energieerhaltung über alle Pfade, SOC nie außerhalb Grenzen, Shortfall korrekt ausgewiesen (`test/energy_conservation_test.dart`, `test/dispatch_policy_test.dart`, geteilter-Batterie-Cap).
- [x] **Topologie-Editor im UI** (`widgets/forms/topology_section.dart`): DC-/AC-Busse, MPPT-Knoten (read-only), Kanten und Batterie-Kopplungen (AC vs. DC, optional Battery-Inverter) im Auswertung-Tab.
- [x] **`HourlySchedule`-Editor im UI** (`widgets/forms/micro_inverter_banks_section.dart`): Auswahl `Dauerbetrieb` / `Zeitfenster` / `Stündlich (24 Werte)` mit 24-Zellen-Grid und „Auf 1.0 zurücksetzen".
- [x] **Per-Inverter-AC-Cap im Energie-Router** (Architektur §5.3 `min(target, battery.maxDischargeW, inverterLimitW)`): `BatteryCouplingSpec.inverterId` ersetzt im `EnergyRouter` den AC-Anteil von `maxDischargeKw`, sobald gesetzt. Direkt-Discharge und alle Banks dieser Batterie respektieren denselben Inverter-Cap. Backward-compatible: ohne `inverterId` bleibt die Pre-Phase-4-Logik aktiv.

---

## Phase 4b – DC-Kopplung & Laderegler ✓

Ziel: Echte DC-gekoppelte Topologie simulieren — PV → Laderegler → DC-Bus → (Batterie ∥ Hybrid-/Batterie-Wechselrichter). Der `TopologyGraph` kennt bereits `BatteryCoupling.dc` und `dcBusId`, der UI-Editor zeigt die Wahl AC/DC; der Header-Kommentar in `packages/pv_engine/lib/src/topology.dart` Z. 9-11 markiert die Dispatch-Seite jedoch als „planned for future phases". Diese verschobene Arbeit wird hier nachgeholt. Bestehende AC-Szenarien rechnen byte-identisch weiter (Regressions-Test gegen Pre-Change-Fixture mit Toleranz `1e-9`).

Begründung: Reale Aufbauten mit MPPT-Ladereglern und Hybrid- oder Off-Grid-Wechselrichtern lassen sich heute nicht modellieren — die Batterie wird ausschließlich aus dem AC-Überschuss geladen (`pvAcKwh − loadKwh`), der DC-Pfad ohne Inverter-η existiert nicht, und die Bauart „PV erreicht AC nur über die Batterie" ist nicht abbildbar.

### Implementierungs-Chunks (jeweils eigener Commit auf `claude/add-battery-charger-topology-XgywK`)

- **Chunk 1 – Engine-Domäne**: `class ChargeController { id, dcBusId, efficiency, maxInputKw?, standbyW, label }`, `enum BusMode { hybrid, batteryFed }`, `DcBus.mode`, `TopologyGraph.chargeControllers` in `packages/pv_engine/lib/src/topology.dart`. `kEngineVersion = '0.15.0'`. Dispatch-Logik unverändert ⇒ keine Verhaltensänderung.
- **Chunk 2 – `SimulationConfig`**: `chargeControllers: List<ChargeController> = const []`, JSON-Schema-Stufe `v6` (nur wenn neue Felder genutzt werden). `effectiveTopology` reicht Controller durch `TopologyGraph.fromLegacy`; bei explizitem `topology` wird `config.chargeControllers.isEmpty` erzwungen (Single Source of Truth).
- **Chunk 3 – Dispatch (Kern)**: `_simulateStep` partitioniert Arrays in AC-/DC-Pfad und akkumuliert `pvDcByBus`. `EnergyRouter.apply()` bekommt vorgelagerten DC-Block (Step 1a–1d): (1a) DC-Pool je Bus, (1b) DC-gekoppelte Batterien laden ohne Inverter-η, (1c) `hybrid`-Rest fließt über zugewiesenen Inverter zu AC, (1d) `batteryFed`-Rest landet in `dcCurtailedKwh`. Steps 2–6 = bestehende Legacy-Pipeline unverändert. Neue Felder `RoutedFlows.dcDirectChargeKwh` / `.dcCurtailedKwh`, `SimulationStep`/`SimulationSummary` analog (Default `0.0`).
- **Chunk 4 – Policies + Validation**: `DispatchContext.pvDcByBus` & `dcBusForBattery`; alle drei Policies (`SelfConsumptionFirst`, `BatteryReserve`, `ConstantFeed24h`) erhalten einen einzeiligen Branch für DC-Batterien (sonst würden sie bei `pvAcKwh = 0` nie laden). `TopologyGraph.validate` und `SimulationConfig.validate` erzwingen die unten gelisteten Cross-Refs.
- **Chunk 5 – Katalog + DB**: `ComponentKind.chargeController` + `ChargeControllerCatalogEntry` in `packages/component_catalog/`, Seed-JSON-Sektion `chargeControllers` (Seed-Version bleibt `1`, additiv). SQLite-Migration v2→v3 entspannt den `CHECK`-Constraint auf `component_catalog.kind` per Tabellen-Rename (`component_catalog__new` + `INSERT … SELECT *`) in einer Transaktion. Bestehende Zeilen unverändert übernommen.
- **Chunk 6 – Flutter-UI**: Neue Section `widgets/forms/charge_controllers_section.dart` (Spiegel von `inverters_section.dart`, Katalog-Picker auf `ChargeControllerCatalogEntry`). `state/config_draft.dart` bekommt `ChargeControllerDraft` und `DcBusDraft.mode`; `classifyValidationMessage` routet `charge controller` / `laderegler` zu `ConfigSection.chargeControllers`. `topology_section.dart` ergänzt eine `BusMode`-Spalte je DC-Bus. `pages/results_tab.dart` mountet die neue Section zwischen Wechselrichter und Batterie. L10n-ARBs erweitert.

### Validierungsregeln

1. `ChargeController.dcBusId` zeigt auf bekannten `DcBus`; alle `ChargeController`-Ids eindeutig und disjunkt zu Array-/Inverter-/MPPT-/Battery-/Bank-/Bus-Ids.
2. `BatteryCouplingSpec.coupling == dc` ⇒ `dcBusId` hat ≥ 1 `ChargeController`.
3. `DcBus.mode == batteryFed` ⇒ genau eine DC-gekoppelte Batterie an diesem Bus und genau eine ausgehende `BusEdge` in einen Inverter.
4. `DcBus.mode == batteryFed` ⇒ keine `array → mppt`-Kante für den/die Inverter dieses Bus (PV muss über `ChargeController` kommen).
5. Keine Kombination `array → cc` und `array → mppt` für dasselbe Array (kein Doppelt-Routing).
6. `SimulationConfig.topology != null` ⇒ `SimulationConfig.chargeControllers.isEmpty` (Single Source of Truth).

### Verifikation

- Engine-Tests in `packages/pv_engine/test/`:
  - `charge_controller_clip_test.dart` — `maxInputKw`-Cap + Wirkungsgrad korrekt, Überlauf in `curtailedDcKwh`.
  - `dc_coupled_charge_test.dart` — Batterie lädt mit `dcKwh × chargeEfficiency` ohne Inverter-η; `pvAcKwh == 0`.
  - `dc_hybrid_bypass_test.dart` — Batterie voll ⇒ PV-Rest fließt über Hybrid-Inverter zu AC.
  - `dc_battery_fed_no_bypass_test.dart` — `batteryFed` + Batterie voll ⇒ `dcCurtailedKwh == pvDcRest`, `pvAcKwh == 0`.
  - `legacy_ac_regression_test.dart` — Pre-Change-Fixture step-für-step gegen Toleranz `1e-9`.
  - `dc_validation_test.dart` — jede Regel oben löst `ArgumentError` mit Section-routender Message aus.
  - `dc_coupled_charge_pre_run_test.dart` — SOC-Carry-Over bei `preRunDays > 0` weiterhin korrekt.
- CI-Smoke vor jedem Push: `dart pub get / analyze / test` in `pv_engine` + `component_catalog`, `flutter pub get / analyze / test` in `app/flutter_app`.
- End-to-End in der App: Hybrid- vs. `batteryFed`-Bus zeigen das erwartete Export-/Discharge-Verhalten; bestehendes Legacy-Projekt liefert identische KPI-Snapshots.

Ablöse-Hinweis: Mit Abschluss dieser Phase wird der „planned for future phases"-Marker in `packages/pv_engine/lib/src/topology.dart` Z. 9-11 obsolet und beim Engine-Versions-Bump auf `0.15.0` entfernt.

---

## Phase 4c – DC-Bus-Solver-Konsolidierung ✓

Ziel: 30+ Codex-Befunde aus 7 Review-Runden auf Phase 4b haben gezeigt, dass die DC-Bus-Energiebilanz über drei Layer (`_simulateStep`, Dispatch-Policies, `EnergyRouter`) verstreut war. Jeder Patch fixte einen η-/Cap-/Einheiten-Mismatch in einem Layer und der nächste Reviewer fand denselben in einem anderen. Phase 4c konsolidiert die per-Bus-Bilanz in einen einzigen Solver.

Begründung: Solange der Bus nicht von einer Stelle besessen wird, konvergieren Patches nicht — die Anzahl möglicher η/Cap-Pfade ist multiplikativ über die drei Layer.

### Refactor

- **Neuer `DcBusSolver`** in `packages/pv_engine/lib/src/dc_bus_solver.dart`: atomare Allokation pro Bus pro Schritt. Inputs (`pvDcInKwh`, `loadAcShareKwh`, `HybridInverterInfo`, `DcBusBattery[]`, `mode`) → Outputs (`batteryChargesDcKwh`, `batteryDischargesDcKwh`, `bypassAcKwh`, `loadCoveredAcKwh`, `dischargeAcKwh`, `curtailedDcKwh`, `inverterAcConsumedKwh`, `inverterDcConsumedKwh`). Fünf-Schritt-Allokation: Load → Charge → Bypass → Discharge → Curtail. Geteilte Inverter-AC/DC/Edge-Caps in einer Datenstruktur.
- **`_simulateStep`**: ruft Solver pro DC-Bus genau einmal auf. Globale Lastreservierung greedy auf hybride Busse verteilt (deterministisch, Bus-Reihenfolge). `array → cc`-Edge-η + `maxPowerKw` werden vor dem Controller angewandt. `dcBus → inverter`-Edge-η + `maxPowerKw` fließen über `HybridInverterInfo` in den Solver.
- **`DispatchContext`** verliert 5 Felder (`pvDcByBus`, `dcBusForBattery`, `dcBusesWithAcPath`, `estimatedBypassAcKwh`, `dcReservedForLoadByBus`) und gewinnt nur `dcCoupledIndices: Set<int>`. Policies emittieren Per-Batterie-CEILINGS (Rate-Cap + Headroom), Router/Solver kappen gegen tatsächliches Surplus/Last.
- **`EnergyRouter.apply`** verliert 4 Parameter (`batteryDirectDischargeAcLossEff`, `batteryInverter`, `inverterAcRemainingKwh`, alter `skipChargeIndices`-Semantik) und gewinnt einen reinen `skipDirectDischargeIndices`. Direct-Discharge passiert für DC-Batterien jetzt im Solver, der Router sieht nur AC-gekoppelte Batterien + Banks + Grid.
- **`dispatch_policies.dart`** verliert den `_dcChargeRequest`-Helfer und DC-Branches in allen drei Policies. Nettoeffekt: ~150 Zeilen Policy-Code entfallen.

Netto: ~277 Zeilen Engine-Code weg (449 hinzu, 726 weg).

### Property-Test als Backstop

- `packages/pv_engine/test/dc_dispatch_invariants_test.dart`: 100 zufällige Topologien × 24 Schritte = 2400 Invariant-Checks pro Lauf. Sieben Invarianten (SOC-Bounds, Rate-Caps, kein NaN/negativ, Grid-Export-Limit, Energiebilanz mit SOC-Tracking, Inverter-AC-Cap-Summe). Ein Test schlägt fehl, sobald irgendein η/Cap-Pfad versehentlich gebrochen wird; das Failure dumpt Seed + Step für gezielte Diagnose.

### Engine-Version

- `kEngineVersion = '0.16.0'` (Bump wegen Refactor — bestehende AC-only-Szenarien rechnen byte-identisch weiter via Regressions-Test).

### Nachgezogen

- ~~**Property-Test-Generator: Multi-Bus & Curtailment-Accounting**~~ — erledigt. Der Generator in `packages/pv_engine/test/dc_dispatch_invariants_test.dart` produziert jetzt drei Bus-Shapes (kein DC-Bus / ein DC-Bus / zwei DC-Busse mit geteiltem Inverter, letzteres optional `hybrid + batteryFed`) und respektiert Rule 4 aus dem „Rules 3 + 4"-Block in `lib/src/topology.dart:568` (`MpptNode` wird für geteilte batteryFed-Inverter weggelassen, damit keine `array → mppt`-Kante übrig bleibt). 250 statt 200 Random-Configs decken die neuen Multi-Bus-Pfade ab. I6 wurde von einseitig (`inputs ≥ outputs`) auf zweiseitig umgebaut: Verlust-Slack ist jetzt nach unten und oben begrenzt — `0 ≤ inputs − outputs ≤ (1 − η_min⁴) × (pvDc + Σchg + Σdis)`, wobei die drei Curtailment-Buckets bereits in `outputs` subtrahiert sind. `loadServed = loadKwh − unservedLoadKwh` ersetzt das alte `selfConsumptionKwh`, damit netz-gedeckte Last nicht künstlich Slack aufbläht. Neue I8 (`pvDcKwh ≥ Σ DC-coupled charges + curtailedDcKwh`) ist eine kostenlose DC-Ledger-Sanity-Check. Verifiziert: Test wird grün auf Engine 0.16.0 und rot, sobald Round-8-Finding #2 (`array → cc`-Edge-Clip) versuchsweise reverted wird. **Weiter offen**: noch mehr Bus-Topologien (z.B. echte DC-DC-Konverter zwischen Bussen) — wird erst relevant, wenn Phase 10 oder später den `TopologyGraph` darauf erweitert.

---

## Phase 5 – SOC Pre-Run & Jahresgrenzen ✓

Ziel: Realistische Startzustände; keine künstlich verzerrten Januarwerte (PRD FR-11; Architektur Kap. 6; `docs/PRD_PV_Calculator_Flutter_App.md` §6.2; `docs/Architekturkonzept_PV_Calculator_Flutter_App.md` §6).

- [x] Single Warm-Up Pre-Run: Jahr N-1 vorrechnen, End-SOC als Start für Ergebnisjahr (`PreRunMode.singleWarmUp`, weiterhin über `preRunDays` steuerbar).
- [x] Cyclic Convergence (Pro): Gleiches Jahr wiederholen bis |Start-SOC − End-SOC| < `convergenceToleranceFraction` × nutzbare Kapazität (Default 0,5 %), max. `maxConvergenceIterations` Zyklen. Im UI über das Build-Flag `--dart-define=PRO_FEATURES=true` freigeschaltet (im Pages-Workflow automatisch aktiv).
- [x] Manuelle SOC-Eingabe als MVP-Option: `BatteryConfig.initialSocKwh` + `PreRunMode.manual`; UI-Checkbox in `widgets/forms/batteries_section.dart` unverändert.
- [x] Report-Feld: `SimulationSummary.preRunMode`, `.preRunActive`, `.startSocsUsedKwh`, `.convergenceIterations`, `.converged`; im Auswertung-Tab als eigene KPI-Sektion „SOC-Vorlauf".
- [x] Tests: `packages/pv_engine/test/pre_run_mode_test.dart` (leerer Speicher, voller Speicher, Konvergenz, Nicht-Konvergenz, Validierung), JSON-Roundtrip + Schema v3 in `json_roundtrip_test.dart`, Widget-Test `app/flutter_app/test/pre_run_widget_test.dart` (free + Pro).

### Verschoben

- ~~**Previous-Year Weather Pre-Run** (Architektur §6, dritte Methode)~~ — erledigt 2026-05-19 (Engine 0.18.0 / App 0.10.0). `PreRunMode.previousYearWarmUp` läuft den vorhandenen `_runLinear`-Warm-Up-Loop, ersetzt aber für `dayIndex < 0` die Irradianzquelle durch `SimulationConfig.preRunWeatherSource` — typischerweise ein `HorizontalToPoaSource` über die PVGIS-Daten des Vorjahres. Validate-Regel: `previousYearWarmUp` ⇒ `preRunWeatherSource != null && preRunDays >= 1`. Multi-Year-kompatibel (Jahr 0 ehrt den Vormodus, Jahre 1..N laufen weiter manuell). Schema-Bump v6 → v7 (nur wenn `previousYearWarmUp` aktiv); `preRunWeatherSource` ist runtime-only wie `weatherSource`, `preRunIrradianceYear` persistiert die Jahresauswahl. UI: Pro-gated Dropdown-Eintrag „Vorjahr" plus Jahres-Picker (`Key('pre-run-year-field')`) im Auswertung-Tab; `ProjectController.loadSiteIrradiance` zieht beide Jahre über denselben Cache/Proxy. Verifiziert in `packages/pv_engine/test/previous_year_warmup_test.dart` (8 Tests).

---

## Phase 6 – 24h-Ausgang & Grundlastprofil ✓

Ziel: Konstante oder zeitgesteuerte AC-Einspeisung aus Speicher (PRD FR-10; Architektur Kap. 5.3).

- [x] `ConstantFeed24h`- und `TimeWindowFeed`-Policy vollständig implementiert (`packages/pv_engine/lib/src/dispatch_policies.dart`).
- [x] SOC-basierte Abschaltung: `MicroInverterBank.minSocShutdown` und per-Schritt-Shortfall-Zeitreihe in `SimulationStep.microInverterShortfallsKwh` / `microInverterShortfallKwh` (`packages/pv_engine/lib/src/energy_router.dart`).
- [x] UI: 24h-Ausgang konfigurierbar (`widgets/forms/micro_inverter_banks_section.dart`), Laufzeit-Chart pro Bank (`widgets/results/bank_runtime_chart.dart` + `SummaryAggregator.bankRuntime` / `bankDaily`) – tägliche Stunden-Aktiv vs. Plan-Stunden, plus Coverage- und Ø-Stunden-Stat im Auswertung-Tab.
- [x] Warnung im UI, wenn ein als `microInverter800W` deklarierter Wechselrichter gleichzeitig PV-Module trägt und eine Bank konfiguriert ist (Architektur §5.3, PRD R-01/FR-16): roter Banner in der `MicroInverterBanksSection` mit Inverter-Id.
- [x] Tests: `packages/pv_engine/test/bank_runtime_test.dart` deckt leeren Speicher (zero discharge, voller Shortfall), `minSocShutdown` oberhalb des aktuellen SOC, mittnachtsumschlagendes Zeitfenster (22–06 Uhr) sowie die neuen `bankRuntime` / `bankDaily`-Aggregatoren ab. `app/flutter_app/test/micro_inverter_banks_section_test.dart` deckt die konditionale Warnung (positiv & negativ).

---

## Phase 7 – Projektmanagement & Szenariovergleich ✓

Ziel: Projekte, Standorte, Szenarien anlegen, duplizieren, vergleichen (PRD FR-01, FR-14).

- [x] Persistenz-Schema: `projects`, `sites`, `scenarios`, `simulation_runs` über `package:sqlite3` (Architektur Kap. 7). Implementierung in `app/flutter_app/lib/persistence/{schema,database,project_repository,scenario_repository,simulation_run_repository}.dart`. Statt Drift mit Codegen wird reines SQL verwendet — gleiche Datei-/Web-Persistenz (OPFS/IndexedDB), aber ohne Build-Runner-Overhead.
- [x] Szenarien duplizieren und Parameter variieren: `ScenarioRepository.duplicate` klont `config_json`, frischt `input_hash`/`engine_version`/Timestamps auf. UI: Duplizieren-Button pro Szenario im Projekte-Tab (`pages/projects_tab.dart`).
- [x] Szenariovergleich: KPIs nebeneinander als Tabelle und Chart (`pages/scenario_compare_page.dart`, `widgets/results/scenario_compare_table.dart`, `widgets/results/scenario_compare_chart.dart`). Selektion über Checkboxen am Szenario, „Vergleichen (N)"-Button im Toolbar. Resolver (`ScenarioComparisonController`) re-uses cached `simulation_runs` solange `input_hash` passt.
- [x] JSON-Projektdatei-Export mit Engine-Version und Input-Hash (NFR-05): `buildExportEnvelope` / `parseImportedConfig` in `persistence/file_io.dart`. Pre-Phase-7-JSON ohne Envelope wird transparent erkannt und geladen.
- [x] Schema-Migration: `app_meta('schema_version')`-Marker plus `_upgrade`-Ladder in `persistence/database.dart`. SP-Bestandsdaten werden einmalig durch `SharedPreferencesMigration` in das neue Schema importiert; die alten `pv_project:*`-Keys bleiben als Read-only-Fallback erhalten.
- [x] **Lokaler Einstrahlungs-Cache** (Schema v3). `irradiance_cache`-Tabelle keyed auf `(lat₄, lon₄, jahr, radDatabase)` über alle Projekte hinweg geteilt; `IrradianceCacheRepository` (`lib/persistence/irradiance_cache_repository.dart`) plus `HorizontalIrradianceSeries.toJson/fromJson` (Engine `src/weather.dart`). `ProjectController.loadSiteIrradiance()` prüft erst den lokalen Cache (kein Netzwerk) und schreibt API-Antworten zurück; `loadDraft()` triggert die Wiederherstellung beim Öffnen automatisch. `ProjectRepository.updateSite()` und `projects_tab._saveCurrent` halten die `sites`-Zeile mit der aktiven Draft-Location synchron; `_newScenario` erbt Lat/Lon vom Projekt-Standort statt vom Demo-Default.

### Verschoben

- **Persistierte Zeitreihen** (Architektur §7 `result_points`): aktuell speichern wir nur `SimulationSummary` als JSON-Blob in `simulation_runs.summary_json`. Per-Step-Reihen würden auf 365×24×N(scenarios) Floats wachsen; Architektur-Empfehlung war ohnehin „bei Bedarf rekonstruieren". Frühestens Phase 9 (Performance / 15-Minuten-Mode), wenn ein Float64List-basierter Streaming-Speicher steht.
- **OPFS-Persistenz im Web**: IndexedDB-VFS (`IndexedDbFileSystem`) ist in `connection_web.dart` aktiv — Projekt-/Szenario-Daten überleben Reloads auf derselben Origin. Offen bleibt der Wechsel auf OPFS (`SimpleOpfsFileSystem`), der das asynchrone Flush-Fenster zwischen sqlite-Write und IDB-Commit schließt und größere Datenbanken effizienter schreibt; er braucht einen Worker-Bootstrap, der noch fehlt. Trigger: wenn der Datenverlust im Reload-Edge-Case (Tab-Close direkt nach Write) in Praxis auftritt oder die Datenbank > ~50 MB wächst.

---

## Phase 8 – Produktqualität & UX *(entspricht bisheriger Phase 4)*

Ziel: App für Endnutzer nutzbar, validiert, barrierefrei (PRD Kap. 7, 8.1).

- [x] **Slice 1: Wizard für Schnell-Einstieg + Expertenmodus** (NFR-06, R-04). Modaler 5-Schritt-Stepper (`widgets/quick_start_wizard.dart`) als Eintrittspunkt aus dem Projekte-Tab; der bisherige `ConfigDraft.demo()`-Pfad bleibt nur noch für interne Resets bestehen. Expertenmodus als runtime-Flag in `SettingsController` (Default OFF, persistiert via `pv_expert_mode`-Key); im Auswertung-Tab werden `TopologySection`, `MicroInverterBanksSection` und `DispatchPolicySection` über `ExpertOnly` weggeblendet und durch eine Hinweis-Karte ersetzt. Auto-Detect-Banner (`Key('advanced-scenario-banner')`) erscheint, sobald ein geladenes Szenario bereits eine erweiterte Funktion nutzt (`ConfigDraft.usesAdvancedFeatures`).
- [x] **Slice 2: Validierungs-Hinweise im UI**. `ConfigDraft.validationWarnings()` liefert nicht-blockierende Warnungen (Inverter-Oversizing > 1.3 DC/AC, Bank-AC > Battery-Discharge, minSOC > 50% der Kapazität) und Hinweise (fehlende Einstrahlung). Render in `ResultsTab` als eigener Abschnitt zwischen Engine-Fehlerkarten und Sim-Parametern; Hint-Cards nutzen tertiäre Farbe, Warn-Cards die `secondaryContainer`-Palette. Stabile Test-Keys `Key('warning-<code>')`.
- [x] **Slice 3: CSV-Zeitreihen-Export mit Array-Aufschlüsselung**. `SimulationStep` um `dcKwhByArray` / `acKwhByArray` erweitert (per-Array-AC entsteht durch Skalierung mit dem Inverter-Verlust-Verhältnis, Energieerhaltung im Test `sums to step.pvDcKwh/pvAcKwh`). `stepsCsv(arrayIds: [...])` ergänzt eine `dcKwh_<id>` / `acKwh_<id>`-Spalte pro Array; Identifier werden auf `[A-Za-z0-9_\-]` sanitisiert. Call-Site in `ResultsTab` reicht `draft.arrays.map((a) => a.id)` durch.
- [x] **Slice 4: Release-Prozess**. `appVersion` in `lib/app_info.dart` (0.1.0 → 0.2.0) synchronisiert mit `pubspec.yaml`; About-Dialog zeigt jetzt `appVersion (engine kEngineVersion)`. Neue Datei `pv_calculator_dexus_overlay/CHANGELOG.md` (Keep a Changelog, SemVer) listet die Phase-8-Slices.
- [x] **Slice 5: Erste a11y-Schicht**. `_KpiCard` bündelt Label + Wert in einem `Semantics`-Knoten (`excludeSemantics: true` auf den `Text`-Kindern), damit Screenreader „Eigenverbrauch, 1234 kWh" statt zweier losgelöster Text-Knoten lesen. PRD NFR-07; weitere Designsystem-Schritte (Kontrast, skalierbare Schrift) folgen in einer eigenen Slice.
- [x] **PDF-Bericht (Pro)**: `lib/services/pdf_report.dart` rendert A4-Bericht (Titel, KPI-Tabelle, Per-Jahr-Aufschlüsselung, Monatswerte, Arrays, Bank-Coverage, Warnungen, AGPL-Footer mit Synth-Hinweis). Über `package:pdf` + `package:printing`; Engine bleibt runtime-dep-free. Eintrag „Bericht exportieren (PDF)" im Auswertung-Tab, im Free-Build deaktiviert mit `(Pro)`-Tooltip. DOCX-Variante verschoben (siehe unten).
- [x] **Auto-Enable Expertenmodus beim Laden eines Expert-Szenarios** (Slice 1 Follow-up). `ProjectController.loadDraft` schaltet `SettingsController.expertMode` automatisch auf `true`, wenn das geladene Szenario `ConfigDraft.usesAdvancedFeatures` erfüllt (Topologie aktiviert, Mikro-WR-Banken, abweichende Dispatch-Policy oder Ladegerät-Liste) und Expertenmodus aktuell aus ist. Banner (`_ExpertOffHint`) bleibt als Fallback bestehen, ist aber für diesen Pfad nicht mehr nötig. SettingsController wird über das bestehende MultiProvider-`ctx.read` in den ProjectController gereicht; Regression in `test/state/project_controller_expert_mode_test.dart`.

### Verschoben

- **Vollständiges Design-System & Schrift-Skalierung** (NFR-07): die jetzt eingezogene `_KpiCard`-Semantik ist ein erster Schritt. Es fehlen kontrastsichere Theme-Tokens, MediaQuery-gestützte `textScaleFactor`-Anpassungen und VoiceOver/TalkBack-Labels auf Formular-Feldern. Nächste Triggerschwelle: erstes externes UX-Audit.
- **CSV-Übersetzung der Engine-Fehlertexte**: `ArgumentError.message`-Strings sind weiterhin englisch; UI-Karten haben lokalisierte Titel und englische Bodies. Trigger: erste echte fremdsprachige Anwender-Beschwerde.
- **DOCX-Variante des Berichts**: Phase 8 listete „PDF/DOCX". Geliefert ist nur PDF — DOCX-Roundtrip mit Word/LibreOffice erfordert eine separate Dart-Bibliothek (Stand 05/2026 keine etablierte). Trigger: erster Kunde, der explizit eine editierbare Office-Version verlangt.
- **Konsolidierung der Form-Field-Widgets**: Der `CatalogEntryEditor` (PR #30, App 0.7.0) hat eigene controllerbasierte `_stringField` / `_numberField` Helfer, weil die shared Widgets in `widgets/forms/_field.dart` (`StringField`, `NumberField`) callback-getrieben sind (`onChanged(value)`). Die konkreten UX/Korrektheits-Bugs aus dem PR-#30-Review (Flicker auf '-', NaN/Inf, fehlender Minus-Key auf Mobile) sind in commit 5d5a8fc bereits inline behoben. Offen: vollständiger Wechsel auf die Shared-Widgets — erfordert State-Restrukturierung im Editor (per-Feld `setState`-Werte statt Read-at-Save), plus eines Custom-Widgets für das Inverter-Rolle-Dropdown (keine Shared-Variante). Trigger: nächste form-lastige Seite oder neue Feldtypen (z. B. Boolean-Toggles) im Editor.
- ~~**JSON-Export auf Android/iOS**~~ — erledigt in App 0.9.3. `FileIo._saveString` und `CatalogFileIo.exportUserCatalog` branchen jetzt auf `share.kIsMobilePlatform` (via Conditional-Import-Helper `lib/persistence/share_helper.dart` / `share_helper_io.dart`, gleiche Form wie `services/simulation_runner.dart`). Auf Android/iOS wird die Datei via `SharePlus.instance.share(ShareParams(files: [XFile.fromData(...)]))` an das System-Share-Sheet gereicht; Linux/macOS/Windows behalten den bestehenden `file_selector.getSaveLocation`-Pfad byte-identisch (engine-/schema-unverändert). `projects_tab._exportScenario`, `results_tab._exportCsv` und `catalog_management_page._onExport` reichen einen `Rect? sharePositionOrigin` aus dem aktuellen `BuildContext` durch (iPad-Popover-Anchor; auf Android/iPhone/Desktop/Web ignoriert); fällt das in `shareOriginFromContext` auf `null` zurück, setzt `share_helper_io.dart` für iOS einen `Rect.fromLTWH(0, 0, 1, 1)`-Fallback, weil `share_plus` auf dem iPad ohne Origin crasht (siehe dessen README). `_exportPdf` reicht keinen Origin durch — `Printing.sharePdf` aus `package:printing` bringt sein eigenes plattform-spezifisches Share-Sheet mit (im Free-Build sowieso gated), die SnackBar-Texte werden aber denselben `FileIo.isMobile`-Branch nutzen. Neue lokalisierte SnackBar-Zeilen `projectListShared` / `catalogManagerExportShared` in de/en/es/fr. `ShareResultStatus.unavailable` (laut share_plus „platform succeeded, user action cannot be determined") wird als Erfolg behandelt; nur `dismissed` ist ein echtes Cancel. **Weiter offen**: integrationstest gegen einen echten `share_plus` Method-Channel-Mock (würde `flutter_test` mit Mock-Channels brauchen). Trigger: erster Mobile-Build mit echten Nutzern, der einen aussagekräftigeren Mock-basierten Regression-Guard braucht.

---

## Phase 9 – Performance & 15-Minuten-Auflösung (Pro) ✓

Ziel: 35 040 Schritte/Jahr auf Mittelklasse-Smartphone unter 5 s (PRD NFR-01, FR-12; Architektur Kap. 10).

- [x] **Simulation in Flutter Isolate ausgelagert, Streaming-Progress über `ReceivePort`** (C2). `services/simulation_runner.dart` spawnt einen Worker-Isolate auf Native; auf Web läuft sie in-process (kein `Isolate.run` verfügbar). `SimulationProgress`-Events fließen über einen `SendPort` zurück und treiben einen determinten Fortschrittsbalken im Auswertung-Tab.
- [x] **Precompute: Sonnenstand** (C3). `HorizontalToPoaSource` cached `SolarPosition` pro `(dayOfYear, hourOfDay)`; mehrere Arrays am selben Zeitpunkt teilen sich einen Trig-Pass. `transposeToPoa` akzeptiert die vorgerechnete Position; neue öffentliche Helper `solarPositionFor()` + `SolarPosition`.
- [x] **Aggregation on-the-fly** (C4). Neue private `_StepAccumulator`-Klasse summiert die 14 Summary-Felder im Hauptloop; `_summarize` liest Skalare statt über die kept-steps-Liste zu folden.
- [x] **`Float64List`-basierte Zeitreihen statt Objekt-Listen** (C4a). Private `_StepBuffer` mit parallelen `Float64List`/`Int32List`-Spalten plus row-major 2D-Buffern für Batterien/Banks/Arrays. Der Simulator-Hauptloop schreibt direkt in den Buffer — **keine** `SimulationStep`-Allokationen mehr im Hot-Path (vorher: 35 040 Step-Objekte + ~245 000 `List<double>`-Wrapper pro Quarter-Hourly-Jahr). `_StepListView` materialisiert `SimulationStep`-Instanzen lazy beim Indexzugriff (mit non-copying `Float64List.sublistView` für die 2D-Spalten); öffentliche API von `SimulationResult.steps` bleibt unverändert.
- [x] **Scenario-Hash-Cache** (C5). In-Memory-LRU (Größe 3) im `ProjectController`, Key = `(inputHash, kEngineVersion)`. Wiederholter Run auf unveränderten Draft liefert sofort. Der Vergleichsmodus nutzt weiterhin den DB-Cache aus Phase 7 (`simulation_runs`).
- [x] **15-Minuten-Modus aktiviert, Schrittweite parametrierbar** (C1). `TimeStep.quarterHourly` war bereits API-seitig vorhanden; Phase 9 verifiziert die Energieerhaltung auf 15-min-Ebene (`test/quarter_hourly_parity_test.dart`) und dokumentiert die Quantisierung (`LoadProfile`-Shape bleibt stündlich, `HourlyWeatherSeries.sampleFor` liefert für alle 4 Quartale einer Stunde denselben Sample — energieerhaltend bei konstanter Leistung).
- [x] **`keepSteps`-Opt-out** (C4, zusätzlich zur Roadmap-Liste). `SimulationConfig.keepSteps: false` überspringt die Per-Step-Liste vollständig — KPIs bleiben identisch, ~35 040 `SimulationStep`-Allokationen pro Szenario entfallen. Nützlich für Vergleichs- und Batch-Läufe.
- [x] **Benchmark-Harness** (C3, erweitert in C4a). `packages/pv_engine/benchmark/year_sim.dart` — manueller Lauf, nicht in CI. Misst Sim-Laufzeit für `hourly`/`quarterHourly` × `keepSteps`/`no-steps` plus die separate Report-Render-Kosten. Verlauf auf einem Desktop-Dev-Rechner mit 3 Arrays × 365 Tagen:
  - Pre-Phase-9 Baseline:           hourly 64.8 ms,  quarterHourly 251.2 ms
  - Nach C3 (Sonnenstand-Cache):    hourly 60.2 ms,  quarterHourly 225.5 ms
  - Nach C4 (Akkumulator):          hourly 55.7 ms,  quarterHourly 219.1 ms
  - Nach C4a (Float64List-Buffer):  hourly 41.0 ms,  quarterHourly 170.8 ms
  - Nach C4b (Buffer-Spalten direkt im Aggregator): Report-Render `monthly + bankRuntime` auf 35 040 Schritten von ~10.5 ms → ~0.4 ms (≈ 27×), Simulator-Pfad unverändert.
  Report-Render (`monthly + bankRuntime` über 35 040 Steps): 10.5 ms vor C4b, ~0.4 ms danach.

---

## Phase 10 – Erweiterte Datenquellen & Backend (Pro/Commercial)

Ziel: Reale Wetterdaten, Komponentenbibliothek, optional Cloud (PRD FR-02, FR-04; Architektur Kap. 9).

- [x] **Weather-Proxy-Backend (PVGIS)**: Cloudflare-Worker + R2-Bucket vor `re.jrc.ec.europa.eu/api/v5_{2,3}/seriescalc`. SHA-256-Cache-Key über 14 kanonisierte Parameter, `X-Cache: HIT|MISS`-Header, transparente v5.2-Route für `PVGIS-SARAH2` (v5.3 dropt diese Datenbank). Worker-Quelle unter `cloudflare-pvgis-proxy/`, GitHub-Actions-Test-Gate in `.github/workflows/ci.yml`, manueller Deploy-Fallback in `.github/workflows/proxy-deploy.yml` (Day-to-day-Deploys gehen über Cloudflares eigene GitHub-Integration). Flutter-Integration optional via `--dart-define=PVGIS_PROXY=<worker-url>` (`lib/config.dart` → `lib/services/pvgis_api.dart`); ohne Secret bleibt der direkte PVGIS-Pfad aktiv (Pages-Workflow injiziert das Define nur, wenn das Repo-Secret gesetzt ist). Setup-Anleitung in `docs/CLOUDFLARE_SETUP.md`. Normalisierung auf ein gemeinsames Schema oder weitere Datenquellen (Global Solar Atlas) sind verschoben — siehe unten.
- [x] **Komponentenbibliothek (lokal)**: Neues pure-Dart-Paket `packages/component_catalog/` (`CatalogEntry`-Hierarchie, `CatalogSource`-Interface, `MergedCatalog`, Seed-Parser). Mitgelieferter Seed-Katalog (`assets/components_seed_v1.json`, 3–5 generische Module / Wechselrichter / Batterien). App-seitige Adapter (`BundledSeedCatalogSource`, `SqliteUserCatalogSource`) und `CatalogRepository` mit User-Overrides via sqlite (Schema v1 → v2). Picker-Knopf „Aus Bibliothek wählen" in den vier Formular-Sektionen (Arrays / Wechselrichter / Batterien / Micro-Bank). Engine `0.10.0 → 0.11.0`, App `0.5.0 → 0.6.0`, neues Paket `component_catalog 0.1.0`.
- [x] **CSV-Lastprofile aus Smartmeter/Home Assistant/Shelly importieren.** `parseLoadProfileCsv` in `packages/pv_engine/lib/src/load_profile_csv.dart` erkennt Delimiter (`;`, `,`, Tab), Header-Zeile und Wert-Spaltentyp (Leistung W/kW oder Energie Wh/kWh) automatisch; unterschiedliche Tagesproben werden zu einem 24-Stunden-Mittel verdichtet. UI-Knopf „CSV importieren" in `widgets/forms/load_section.dart`. Engine `0.9.0 → 0.10.0`.
- [x] **Mehrjährige Simulation mit Degradationsmodell** (Pro): `SimulationConfig.simulationYears` (1..30) + `PvArray.degradationPctPerYear`. Engine läuft den existierenden Linear-Pfad pro Jahr mit deratiertem `peakKw` und SOC-Carry-over; Per-Jahr-KPIs in `SimulationSummary.perYearSummaries`. Im UI Pro-gated (Free-Build clamped auf `1`). Schema v4. Engine `0.7.0 → 0.8.0`.
- [x] **Tarifmodell** (Free: Pauschalpreise · Pro: 24-Slot-TOU): `TariffConfig` in `lib/src/tariff.dart`, optionale `SimulationConfig.tariff`. Im UI `widgets/forms/tariff_section.dart` mit Master-Switch und Pro-gated TOU-Grid. Neue €-KPIs `importCostEur`/`exportRevenueEur`/`netCostEur` im Auswertung-Tab. Schema v5. Engine `0.8.0 → 0.9.0`.
- [x] **Optimierer: Speichergröße, Ausgangsleistung, Array-Mix automatisch variieren (Budget-begrenzt)** (Pro). Engine: pure-Dart `Optimizer` / `OptimizerSpec` / `OptimizerPrices` / `OptimizerCandidate` / `OptimizerResult` in `packages/pv_engine/lib/src/optimizer.dart`. Kartesisches Sweep über `(batteryKwh × inverterKw × pvScale × Array-Teilmenge)`, lineares Investmentmodell, Budget-Cap, Ziel `maxAutarky` oder `minNetCost`. C-Rate und SOC-Floor-Anteil bleiben über Skalierung erhalten; nicht serialisierte `weatherSource` / `temperatureModel` werden vom Baseline beibehalten. App: `OptimizerController` + `pages/optimizer_page.dart` + `widgets/results/optimizer_results_table.dart` + Eintrag „Optimieren (Pro)" im Auswertung-Tab. Engine `0.11.0 → 0.12.0`, App `0.7.0 → 0.8.0`.
- [x] **Optimierer: Diskontierungssatz + Strompreis-Eskalation** (Pro). `OptimizerSpec.discountRatePct` und `OptimizerSpec.priceEscalationPctPerYear` (beide Default `0`) erweitern das undiskontierte `investment + horizonYears × netCostEur` zu `investment + Σ_{y=1..N} netCostEur · (1+e)^(y-1) / (1+r)^y`. Bei beiden Raten = 0 % bleibt das Ergebnis bitidentisch zur alten Formel — Engine 0.12.0-Resultate werden also nicht entwertet. UI: zwei Number-Fields plus Hinweis-Zeile im Preise-Block. Engine `0.12.0 → 0.13.0`, App `0.8.1 → 0.8.2`.
- [ ] Lizenz/Account-Service (Freemium/Abo), opt-in Cloud-Sync.

### Verschoben

- ~~**Persistierte Per-Jahr-Zeitreihen für Multi-Year**~~ — erledigt 2026-05-19 (Engine 0.17.0 / App 0.9.2). `SimulationSummary.perYearMonthly: List<List<MonthlyBucket>>` wird von einem engine-privaten `_MonthlyAccumulator` (Float64List × 12 Monate × 12 Felder) parallel zum bestehenden `_StepAccumulator` im Step-Loop befüllt. `_runMultiYear` ruft `_runLinear` direkt auf (sicher, weil `cyclicConvergence + simulationYears > 1` an `validate()` scheitert), reicht je Jahr einen frischen Accumulator durch und behält die Phase-9-Optimierung `keepSteps: config.keepSteps && y == years - 1` — d. h. `keepSteps:false`-Multi-Year-Runs zahlen weiterhin nur den 1-Slot-Scratch-Buffer pro Jahr und keine Vollband-Allokation. `MonthlyBucket.toJson()/fromJson()` plus `SimulationSummary.toJson()`-Gate (`perYearSummaries.length >= 2 && perYearMonthly.isNotEmpty`) sorgen für stabile Persistenz in `simulation_runs.summary_json` (Schema v4 → v5, kein DDL; der Bump existiert nur als Forward-Compat-Zaun). UI: neuer Auswertung-Tab-Block „Monatswerte pro Jahr" mit Jahr-Dropdown, der die bestehende `MonthlyTable` per Year auswählt; CSV-Button „Monatswerte pro Jahr (CSV)" via `perYearMonthlyCsv()`. **Weiter offen**: voll persistierte Per-Step-Reihen (8760×N pro Jahr) — bleibt verschoben unter Phase 7 „Persistierte Zeitreihen", weil 30-Jahres-Runs > 10 M Floats schreiben müssten.
- **Komponentenbibliothek v2 — externe Datenquellen & Anhänge**: das Paket `packages/component_catalog/` lädt aktuell den mitgelieferten Seed-Katalog plus sqlite-Userzeilen, und seit App `0.7.0` gibt es eine In-App-Verwaltung (`CatalogManagementPage`) sowie JSON-Import/Export ganzer User-Kataloge im Seed-Format (siehe CHANGELOG). Offen: weitere `CatalogSource`-Implementierungen (PVsol-Export-Importer, NREL SAM Library Konverter, Remote-HTTP-Source gegen ein zukünftiges Weather-/Catalog-Backend, Community-Datensatz) und Anhang von Datenblättern (Binärspeicher-Entscheidung). Trigger: konkreter externer Datensatz zum Importieren bzw. erste Kundenanforderung nach PDF-Datenblättern pro Eintrag.
- ~~**Optimierer-Sweep im Isolate**~~: erledigt in App 0.8.1. `OptimizerRunner` in `app/flutter_app/lib/services/optimizer_runner.dart` (+ `_io.dart` / `_web.dart`) spiegelt den Phase-9-`SimulationRunner`: Worker-Isolate auf Native, In-Process auf Web. Engine-`onProgress(done, total)` wird als `OptimizerProgress` an die UI gereicht, der Auswertung-Tab zeigt jetzt eine determinate Progress-Bar mit „X / N Kandidaten" und einen Cancel-Button (auf Web disabled, weil Dart einen synchronen Loop nicht unterbrechen kann). Engine unverändert (siehe Changelog 0.8.1).
- ~~**Pareto-Frontier für Optimierer (Kosten × Autarkie)**~~: erledigt in Engine 0.14.0 / App 0.9.0. `OptimizerResult.paretoFrontier` listet die nicht dominierten Kandidaten über (`lifetimeNetCostEur` × `autarkyRate`), nach Kosten aufsteigend sortiert; unabhängig von `topN` (aus der vollständigen Sweep-Menge vor der Trunkierung berechnet). Die Optimizer-Page rendert dazu eine Scatter-Chart mit hervorgehobener Front (`OptimizerParetoChart`) plus eine kompakte Tabelle (`OptimizerParetoTable`). Bei deaktiviertem Tarif bleibt die Front leer und die Karte wird ausgeblendet — Single-Objective-Verhalten ist unverändert. Pareto-Rang-Annotation in der Haupt-Tabelle ergänzt in App 0.9.1: `OptimizerResultsTable` blendet eine `Pareto`-Spalte ein (Stern für Frontier-Mitglieder, em-dash sonst), sobald `result.paretoFrontier` nicht leer ist. **Weiter offen**: Pareto-Front mit ≥3 Zielen (z. B. zusätzlich Investment). Trigger: erster konkreter Bedarf an mehrdimensionaler Optimierung.
- ~~**NPV / Diskontierungssatz für Optimierer**~~: erledigt in App 0.8.2 / Engine 0.13.0. `OptimizerSpec.discountRatePct` und `OptimizerSpec.priceEscalationPctPerYear` (beide Default `0`) machen aus dem alten `lifetimeNetCostEur = investment + horizonYears × netCostEur` einen diskontierten, eskalierten Geometrie-Summen-NPV. Bei beiden Raten 0 % bleibt die Formel byte-identisch zum Vorgänger. **Weiter offen**: IRR / Amortisationszeit — beide brauchen ein „PV ein/aus"-Vergleichs­szenario oder zumindest eine Annahme über die kontrafaktischen Stromkosten, die der Optimierer derzeit nicht hat. Trigger: erster Wunsch nach Payback-Anzeige.
- **Preiskatalog je Komponente** (teilweise erledigt): `CatalogEntry` trägt seit `component_catalog` v2 ein optionales `unitPriceEur`-Feld (€/Modul · €/Wechselrichter · €/Speichereinheit · €/Laderegler), der gebündelte Seed-Katalog ist mit illustrativen Listenpreisen befüllt und der `CatalogEntryEditor` erfasst den Wert. Picker-/Manager-Liste zeigt den Preis als zusätzliches Subtitle-Segment. **Weiter offen**: Der Optimierer liest die Preise noch nicht — `OptimizerPrices` bleibt bei drei Pauschal­werten (€/kWp PV, €/kW WR, €/kWh Speicher). Dazu brauchen `PvArray` / `Inverter` / `BatteryConfig` in `pv_engine` eine Rückreferenz auf den Katalog­eintrag (z. B. `catalogEntryId`), damit der Optimierer pro Kandidat die zugehörigen Einzel­preise nachschlagen kann. Trigger: nächstes Optimizer-Usability-Feedback, oder wenn ein externer Preiskatalog-Import (PVsol / NREL SAM Library) landet — dann lohnt sich die End-to-End-Verkabelung in einem Schritt.
- **Optimierer-Sweep weiterer Wechselrichter / Batterien**: derzeit variiert der Optimierer **nur** `batteries[0]` und `inverters[0]`. Mehrgeräte-Konfigurationen werden über die Sweep-Dimensionen nicht erreicht. Trigger: erstes konkretes Projekt mit mehreren Speichern, das gezielt einen davon optimieren möchte.
- **Weather-Proxy: weitere Datenquellen & Normalisierung**: der aktuelle Worker fronted **nur** PVGIS-`seriescalc` und reicht die Antwort byte-für-byte weiter (keine Normalisierung auf ein gemeinsames Schema, kein Re-Encoding). Offen: paralleler Adapter für **Global Solar Atlas** (eigener API-Key, andere Antwortform — gehörte ursprünglich in die obige Phase-10-Zeile, ist aber nicht gebaut), gemeinsame `IrradianceSource`-Normalisierung im Worker, optional kompakter Binär-Cache statt JSON-Roh-Bytes. Trigger: erste konkrete Region in der PVGIS schlecht abdeckt (z. B. Teile Süd­amerikas / Australiens, wo NSRDB/ERA5 mit GSA divergieren) oder R2-Speicherkosten überschreiten ~5 €/Monat.

---

## Nicht-Ziele (alle Phasen)

- Keine verbindliche technische Ertragsprognose oder Netzanschlussberatung.
- Keine API-Keys im Client-Code.
- Keine Herstellergarantie für Gerätekennlinien.
- Synthetisches Irradianz-Modell immer als Demo/Fallback kennzeichnen.
- Keine neuen Runtime-Abhängigkeiten in `pv_engine` ohne Begründung.
