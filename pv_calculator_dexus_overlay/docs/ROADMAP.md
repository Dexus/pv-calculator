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

## Phase 5 – SOC Pre-Run & Jahresgrenzen ✓

Ziel: Realistische Startzustände; keine künstlich verzerrten Januarwerte (PRD FR-11; Architektur Kap. 6; `docs/PRD_PV_Calculator_Flutter_App.md` §6.2; `docs/Architekturkonzept_PV_Calculator_Flutter_App.md` §6).

- [x] Single Warm-Up Pre-Run: Jahr N-1 vorrechnen, End-SOC als Start für Ergebnisjahr (`PreRunMode.singleWarmUp`, weiterhin über `preRunDays` steuerbar).
- [x] Cyclic Convergence (Pro): Gleiches Jahr wiederholen bis |Start-SOC − End-SOC| < `convergenceToleranceFraction` × nutzbare Kapazität (Default 0,5 %), max. `maxConvergenceIterations` Zyklen. Im UI über das Build-Flag `--dart-define=PRO_FEATURES=true` freigeschaltet (im Pages-Workflow automatisch aktiv).
- [x] Manuelle SOC-Eingabe als MVP-Option: `BatteryConfig.initialSocKwh` + `PreRunMode.manual`; UI-Checkbox in `widgets/forms/batteries_section.dart` unverändert.
- [x] Report-Feld: `SimulationSummary.preRunMode`, `.preRunActive`, `.startSocsUsedKwh`, `.convergenceIterations`, `.converged`; im Auswertung-Tab als eigene KPI-Sektion „SOC-Vorlauf".
- [x] Tests: `packages/pv_engine/test/pre_run_mode_test.dart` (leerer Speicher, voller Speicher, Konvergenz, Nicht-Konvergenz, Validierung), JSON-Roundtrip + Schema v3 in `json_roundtrip_test.dart`, Widget-Test `app/flutter_app/test/pre_run_widget_test.dart` (free + Pro).

### Verschoben

- **Previous-Year Weather Pre-Run** (Architektur §6, dritte Methode): tatsächliches Vorjahr als Warm-Up. Benötigt mehrjährige Wetterdaten und gehört in Phase 10 (erweiterte Datenquellen) — frühestens umsetzbar wenn ein Wetter-Proxy mit Mehrjahres-Cache vorliegt.

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

### Verschoben

- **Vollständiges Design-System & Schrift-Skalierung** (NFR-07): die jetzt eingezogene `_KpiCard`-Semantik ist ein erster Schritt. Es fehlen kontrastsichere Theme-Tokens, MediaQuery-gestützte `textScaleFactor`-Anpassungen und VoiceOver/TalkBack-Labels auf Formular-Feldern. Nächste Triggerschwelle: erstes externes UX-Audit.
- **Auto-Enable Expertenmodus beim Laden eines Expert-Szenarios**: Aktuell zeigt der Auswertung-Tab nur ein Banner. Ein automatisches Umschalten im `ProjectController.loadDraft`-Pfad wäre invasiver (UX-Preference vs. Szenario-State); im Banner-Status belassen, bis genug Telemetrie zeigt, dass Nutzer das Banner übersehen.
- **CSV-Übersetzung der Engine-Fehlertexte**: `ArgumentError.message`-Strings sind weiterhin englisch; UI-Karten haben lokalisierte Titel und englische Bodies. Trigger: erste echte fremdsprachige Anwender-Beschwerde.
- **DOCX-Variante des Berichts**: Phase 8 listete „PDF/DOCX". Geliefert ist nur PDF — DOCX-Roundtrip mit Word/LibreOffice erfordert eine separate Dart-Bibliothek (Stand 05/2026 keine etablierte). Trigger: erster Kunde, der explizit eine editierbare Office-Version verlangt.
- **Konsolidierung der Form-Field-Widgets**: Der `CatalogEntryEditor` (PR #30, App 0.7.0) hat eigene controllerbasierte `_stringField` / `_numberField` Helfer, weil die shared Widgets in `widgets/forms/_field.dart` (`StringField`, `NumberField`) callback-getrieben sind (`onChanged(value)`). Die konkreten UX/Korrektheits-Bugs aus dem PR-#30-Review (Flicker auf '-', NaN/Inf, fehlender Minus-Key auf Mobile) sind in commit 5d5a8fc bereits inline behoben. Offen: vollständiger Wechsel auf die Shared-Widgets — erfordert State-Restrukturierung im Editor (per-Feld `setState`-Werte statt Read-at-Save), plus eines Custom-Widgets für das Inverter-Rolle-Dropdown (keine Shared-Variante). Trigger: nächste form-lastige Seite oder neue Feldtypen (z. B. Boolean-Toggles) im Editor.
- **JSON-Export auf Android/iOS**: `FileIo.exportConfig` und `CatalogFileIo.exportUserCatalog` nutzen beide `file_selector.getSaveLocation`. Die offizielle file_selector-Plattform-Matrix listet „Choose a save location" nur für Linux/macOS/Windows und Web (über Browser-Download); auf Android/iOS schlägt der Aufruf fehl und der Nutzer sieht eine Export-Failed-SnackBar. Lösung wäre ein `share_plus`-Fallback (Share-Sheet mit dem temporären File) oder ein `SAF`-basiertes Save-Dialog-Plugin für Android. Trigger: erster Mobile-Build mit echten Nutzern, die exportieren wollen — bis dahin ist die Web-/Desktop-Story die primäre.

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

- [ ] Weather-Proxy-Backend: API-Keys serverseitig, Caching, Normalisierung (PVGIS, Global Solar Atlas).
- [x] **Komponentenbibliothek (lokal)**: Neues pure-Dart-Paket `packages/component_catalog/` (`CatalogEntry`-Hierarchie, `CatalogSource`-Interface, `MergedCatalog`, Seed-Parser). Mitgelieferter Seed-Katalog (`assets/components_seed_v1.json`, 3–5 generische Module / Wechselrichter / Batterien). App-seitige Adapter (`BundledSeedCatalogSource`, `SqliteUserCatalogSource`) und `CatalogRepository` mit User-Overrides via sqlite (Schema v1 → v2). Picker-Knopf „Aus Bibliothek wählen" in den vier Formular-Sektionen (Arrays / Wechselrichter / Batterien / Micro-Bank). Engine `0.10.0 → 0.11.0`, App `0.5.0 → 0.6.0`, neues Paket `component_catalog 0.1.0`.
- [x] **CSV-Lastprofile aus Smartmeter/Home Assistant/Shelly importieren.** `parseLoadProfileCsv` in `packages/pv_engine/lib/src/load_profile_csv.dart` erkennt Delimiter (`;`, `,`, Tab), Header-Zeile und Wert-Spaltentyp (Leistung W/kW oder Energie Wh/kWh) automatisch; unterschiedliche Tagesproben werden zu einem 24-Stunden-Mittel verdichtet. UI-Knopf „CSV importieren" in `widgets/forms/load_section.dart`. Engine `0.9.0 → 0.10.0`.
- [x] **Mehrjährige Simulation mit Degradationsmodell** (Pro): `SimulationConfig.simulationYears` (1..30) + `PvArray.degradationPctPerYear`. Engine läuft den existierenden Linear-Pfad pro Jahr mit deratiertem `peakKw` und SOC-Carry-over; Per-Jahr-KPIs in `SimulationSummary.perYearSummaries`. Im UI Pro-gated (Free-Build clamped auf `1`). Schema v4. Engine `0.7.0 → 0.8.0`.
- [x] **Tarifmodell** (Free: Pauschalpreise · Pro: 24-Slot-TOU): `TariffConfig` in `lib/src/tariff.dart`, optionale `SimulationConfig.tariff`. Im UI `widgets/forms/tariff_section.dart` mit Master-Switch und Pro-gated TOU-Grid. Neue €-KPIs `importCostEur`/`exportRevenueEur`/`netCostEur` im Auswertung-Tab. Schema v5. Engine `0.8.0 → 0.9.0`.
- [x] **Optimierer: Speichergröße, Ausgangsleistung, Array-Mix automatisch variieren (Budget-begrenzt)** (Pro). Engine: pure-Dart `Optimizer` / `OptimizerSpec` / `OptimizerPrices` / `OptimizerCandidate` / `OptimizerResult` in `packages/pv_engine/lib/src/optimizer.dart`. Kartesisches Sweep über `(batteryKwh × inverterKw × pvScale × Array-Teilmenge)`, lineares Investmentmodell, Budget-Cap, Ziel `maxAutarky` oder `minNetCost`. C-Rate und SOC-Floor-Anteil bleiben über Skalierung erhalten; nicht serialisierte `weatherSource` / `temperatureModel` werden vom Baseline beibehalten. App: `OptimizerController` + `pages/optimizer_page.dart` + `widgets/results/optimizer_results_table.dart` + Eintrag „Optimieren (Pro)" im Auswertung-Tab. Engine `0.11.0 → 0.12.0`, App `0.7.0 → 0.8.0`.
- [ ] Lizenz/Account-Service (Freemium/Abo), opt-in Cloud-Sync.

### Verschoben

- **Persistierte Per-Jahr-Zeitreihen für Multi-Year**: nur `perYearSummaries` (Skalare) wandern in `simulation_runs.summary_json`. Pro Jahr 8760×N Schritte wäre für eine 30-Jahres-Simulation untragbar (>10 M Floats). Trigger: erste konkrete Anforderung an Per-Jahr-Charts.
- **Komponentenbibliothek v2 — externe Datenquellen & Anhänge**: das Paket `packages/component_catalog/` lädt aktuell den mitgelieferten Seed-Katalog plus sqlite-Userzeilen, und seit App `0.7.0` gibt es eine In-App-Verwaltung (`CatalogManagementPage`) sowie JSON-Import/Export ganzer User-Kataloge im Seed-Format (siehe CHANGELOG). Offen: weitere `CatalogSource`-Implementierungen (PVsol-Export-Importer, NREL SAM Library Konverter, Remote-HTTP-Source gegen ein zukünftiges Weather-/Catalog-Backend, Community-Datensatz) und Anhang von Datenblättern (Binärspeicher-Entscheidung). Trigger: konkreter externer Datensatz zum Importieren bzw. erste Kundenanforderung nach PDF-Datenblättern pro Eintrag.
- **Optimierer-Sweep im Isolate**: aktuell läuft `Optimizer.run` synchron im aufrufenden Isolate, die UI zeigt während des Sweeps eine indeterminate Progress-Bar (kein Mid-Run-Repaint). Trigger: erste Nutzermeldung über UI-Freeze bei > 100 Kandidaten oder ein Wunsch nach abbrechbarem Sweep.
- **Pareto-Frontier für Optimierer (Kosten × Autarkie)**: aktuell rankt der Optimierer nach **einem** Ziel und liefert eine top-N-Liste. Eine kombinierte Pareto-Front würde Nutzer:innen die Trade-off-Kurve direkt zeigen. Trigger: erste Anwender-Beschwerde, dass beide Ziele gleichzeitig sichtbar sein müssen.
- **NPV / Diskontierungssatz für Optimierer**: `lifetimeNetCostEur = investmentEur + horizonYears × netCostEur` ist undiskontiert. Erweiterung um Diskontierung / Inflation / Tarif-Eskalation ist trivial datentechnisch, braucht aber UX-Entscheidungen. Trigger: erster Wunsch nach IRR / Amortisationszeit.
- **Preiskatalog je Komponente**: aktuell akzeptiert der Optimierer drei pauschale €/Einheit-Werte (€/kWp PV, €/kW WR, €/kWh Speicher). `CatalogEntry` trägt keine Preisdaten. Trigger: Preise sollen direkt mit den Komponenten gepflegt werden, oder externe Preis-Datenquelle.
- **Optimierer-Sweep weiterer Wechselrichter / Batterien**: derzeit variiert der Optimierer **nur** `batteries[0]` und `inverters[0]`. Mehrgeräte-Konfigurationen werden über die Sweep-Dimensionen nicht erreicht. Trigger: erstes konkretes Projekt mit mehreren Speichern, das gezielt einen davon optimieren möchte.

---

## Nicht-Ziele (alle Phasen)

- Keine verbindliche technische Ertragsprognose oder Netzanschlussberatung.
- Keine API-Keys im Client-Code.
- Keine Herstellergarantie für Gerätekennlinien.
- Synthetisches Irradianz-Modell immer als Demo/Fallback kennzeichnen.
- Keine neuen Runtime-Abhängigkeiten in `pv_engine` ohne Begründung.
