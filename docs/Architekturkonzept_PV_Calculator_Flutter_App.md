__Technisches Architekturkonzept  
__Flutter PV Calculator: Multi\-Array, Batterie, SOC\-Carry\-Over und 24h\-Ausgaenge

*Version: 0\.1 | Stand: 15\. Mai 2026 | Sprache: Deutsch*

Dieses Dokument beschreibt eine robuste Architektur fuer eine Flutter\-App, deren Simulationskern bewusst von UI, Persistenz und Datenquellen entkoppelt ist\. Der Kern muss deterministisch, testbar und performant sein, weil er 8760 bis 35040 Zeitschritte pro Szenario mehrfach auswerten koennen muss\.

# Inhaltsverzeichnis

- 1\. Architekturziele
- 2\. Systemkontext und Schichten
- 3\. Domain\-Modell
- 4\. Topologie\- und Energieflussmodell
- 5\. Simulations\-Engine
- 6\. SOC\-Pre\-Run und Jahresgrenzen
- 7\. Datenmodell und Persistenz
- 8\. Flutter\-State\-Management
- 9\. Datenquellen und Backend\-Optionen
- 10\. Performance\-Strategie
- 11\. Tests, Validierung und Betrieb
- 12\. Quellen

# 1\. Architekturziele

- Deterministische Simulation: gleiche Eingaben plus Engine\-Version ergeben gleiche Ergebnisse\.
- Domain\-first: Simulationskern in reinem Dart ohne Flutter\-Abhaengigkeit\.
- Offline\-first: Projekte und Simulationen lokal; Netzwerk nur fuer optionale Datenquellen und Updates\.
- Erweiterbare Topologien: mehrere PV\-Arrays, MPPTs, Inverter, DC\-/AC\-Busse, Speicher und Lasten\.
- Energieerhaltung: alle Energiepfade werden bilanziert und testbar gemacht\.
- Warn\- statt Bastelanleitung: kritische Hardwareannahmen werden als Modellannahmen markiert, nicht als Installationsanweisung\.

# 2\. Systemkontext und Schichten

Empfohlene Schichtenarchitektur:

Flutter UI  
  \-> Application Layer / Use Cases / State Notifiers  
      \-> Domain Layer: Entities, Value Objects, Policies, SimulationEngine  
          \-> Infrastructure: Repositories, SQLite/Drift, Weather Clients, CSV/JSON, Report Export  
              \-> Optional Backend: Weather proxy, license, catalog sync, shared projects

Die UI darf keine Simulationslogik enthalten\. Sie sammelt Eingaben, startet Use Cases und visualisiert Ergebnisse\. Der Domain Layer kennt keine Widgets, keine Datenbanktabellen und keine HTTP\-Clients\.

## 2\.1 Paketstruktur

lib/  
  app/                    \# Routing, Dependency Injection, Theme, Localization  
  features/project/        \# Screens und Controller fuer Projektverwaltung  
  features/scenario/       \# Wizard, Topologie\-Editor, Ergebnisse  
  domain/  
    energy/                \# Einheiten, Power, Energy, Efficiency  
    pv/                    \# PVArray, ModuleSpec, IrradianceModel  
    inverter/              \# InverterSpec, EfficiencyCurve, MicroInverterBank  
    battery/               \# BatterySpec, BatteryState, SocPolicy  
    load/                  \# LoadProfile, LoadSchedule  
    simulation/            \# SimulationEngine, DispatchPolicy, ResultSeries  
  infrastructure/  
    persistence/           \# Drift/SQLite Repositories  
    weather/               \# Provider, CSV, Cache  
    export/                \# CSV/JSON/PDF spaeter  
  shared/                  \# Common widgets, validation, formatting

# 3\. Domain\-Modell

__Entity__

__Wichtige Felder__

__Rolle__

Project

id, name, createdAt, updatedAt, defaultSiteId

Container fuer Standorte und Szenarien\.

Site

lat, lon, elevation, timezone, countryProfile

Basis fuer Wetterdaten, Sonnenstand und regulatorische Hinweise\.

Scenario

projectId, name, simulationConfig, topologyId

Eine berechenbare Variante\.

PVArray

name, moduleSpecId, moduleCount, installedKWp, tilt, azimuth, losses, mpptId

Ein Array mit eigener Ausrichtung und Verlustannahme\.

ModuleSpec

pStc, tempCoeff, noct, area, bifacialFactor?

Optionale Modulbibliothek\.

InverterSpec

ratedPowerW, maxDcVoltage, mpptCount, efficiencyCurve, standbyW

Allgemeiner Wechselrichter\.

MicroInverterBank

count, unitRatedPowerW, schedule, sourceBusId, minSocShutdown

Mehrere kleine AC\-Ausgaenge, z\. B\. 800\-W\-Klasse\.

BatterySpec

capacityKWh, usableKWh, minSoc, maxSoc, maxChargeKW, maxDischargeKW, etaCharge, etaDischarge, standbyW

Speicherparameter\.

BatteryState

energyKWh, soc, throughputKWh, cycleEstimate

Laufzeitstatus waehrend Simulation\.

LoadProfile

timeSeriesW, fallbackBaseLoadW, schedule

Verbrauchslast fuer Eigenverbrauch/Autarkie\.

WeatherSeries

timestamp, ghi/dni/dhi or poa, temp, wind?

Einstrahlung und Wetter je Zeitschritt\.

SimulationResult

series, aggregates, warnings, engineVersion

Zeitreihen und Kennzahlen\.

## 3\.1 Value Objects und Einheiten

- PowerW, EnergyWh, EnergyKWh, Efficiency, Percent, AngleDeg und TimeStepDuration als Value Objects oder mindestens klar benannte Typen verwenden\.
- Keine nackten double\-Werte in der Simulations\-API, wenn Einheit oder Richtung missverstaendlich ist\.
- Alle internen Berechnungen in SI\-nahen Einheiten: W, Wh, kWh, Grad, Sekunden/Stunden\.
- Rundung nur in UI und Export, nie im Simulationskern\.

# 4\. Topologie\- und Energieflussmodell

Die App sollte die Anlage nicht als eine monolithische PV\-Leistung modellieren, sondern als gerichteten Energiegraphen\. Dadurch koennen mehrere Arrays, getrennte MPPTs, DC\-/AC\-Kopplung und mehrere Ausgaenge sauber abgebildet werden\.

PVArray\(s\) \-> MPPT/DC Controller \-> DC Bus \-> Battery Charge Controller \-> Battery  
PVArray\(s\) \-> Grid Inverter \-> AC Bus \-> Load / Grid Export  
Battery \-> DC Output Controller \-> MicroInverterBank\(s\) \-> AC Bus \-> Load / Grid Export  
Grid \-> AC Bus \-> Load  \(falls Netzimport erlaubt\)

- DC\-gekoppelt: PV laedt Batterie vor AC\-Wandlung; Micro\-Inverter\-Ausgaenge ziehen aus Batterie/DC\-Bus\.
- AC\-gekoppelt: PV erzeugt AC; Batterie wird ueber Batterie\-Wechselrichter geladen/entladen\.
- Hybrid: einzelne Arrays koennen unterschiedlichen Bussen/MPPTs zugeordnet werden\.
- Jede Kante besitzt Wirkungsgrad, maximale Leistung und optional Standby\-/Umwandlungsverlust\.

## 4\.1 Dispatch\-Policies

__Policy__

__Prioritaet__

__Einsatz__

SelfConsumptionFirst

PV \-> Last \-> Batterie \-> Export

Standard fuer Eigenverbrauch\.

BatteryReserve

PV \-> Last \-> Batterie bis Reserveziel \-> Export

Speicherreserve fuer Nacht/Notfall\.

ConstantFeed24h

PV \-> Batterie; Batterie \-> Micro\-Inverter\-Sollleistung

24h\-Grundlast\-/Einspeisemodell\.

TimeWindowFeed

Batterieausgang nur in Zeitfenstern

Abend\-/Nachtoptimierung\.

GridAssist

Wenn Batterie leer, optional Netzimport fuer Last; nicht fuer Einspeisung\.

Vermeidet nicht gedeckte Lasten\.

# 5\. Simulations\-Engine

Die Engine wird als pure Dart Library implementiert\. Sie nimmt ein vollständig validiertes SimulationInput\-Objekt an und liefert SimulationResult\. Die Engine hat keine Seiteneffekte ausser optionalem Progress\-Callback\.

SimulationResult simulate\(SimulationInput input\) \{  
  state = initialState\(input\);  
  for \(t in input\.timeIndex\) \{  
    weather = input\.weather\.at\(t\);  
    loads = input\.loadProfile\.powerAt\(t\);  
  
    pvDcByArray = pvModel\.computeArrays\(input\.arrays, weather, t\);  
    pvAfterMppt = mpptModel\.applyLimits\(pvDcByArray, input\.topology\);  
  
    dispatch = input\.dispatchPolicy\.plan\(  
      time: t,  
      pv: pvAfterMppt,  
      loads: loads,  
      battery: state\.battery,  
      outputs: input\.microInverterBanks,  
    \);  
  
    flows = energyRouter\.apply\(dispatch, input\.topology, state, input\.dt\);  
    state = state\.advance\(flows, input\.dt\);  
    result\.append\(t, flows, state, warnings\);  
  \}  
  return result\.finalize\(engineVersion\);  
\}

## 5\.1 PV\-Modell

Fuer MVP reicht ein vereinfachtes PV\-Modell, solange Datenquelle, Annahmen und Verluste transparent sind\. Fuer Pro kann die Modellkette an pvlib\-artige Schritte angenaehert werden: Einstrahlung, Sonnenstand, Transposition auf Array\-Ebene, Temperaturmodell, DC\-Leistung, MPPT, Wechselrichter und AC\-Verluste \[S3\]\.

- Minimalmodell: Pdc = kWp \* POA\_irradiance / 1000 \* Verlustfaktor \* Temperaturfaktor\.
- Wenn nur globale Ertragsdaten vorhanden sind, kann ein normalisierter Ertragsfaktor pro Zeitschritt verwendet werden\.
- Array\-spezifische Verluste: Verschattung, Kabel, Verschmutzung, Mismatch, Degradation\.
- Inverter\-Clipping separat ausweisen, nicht als unsichtbaren Verlust verstecken\.

## 5\.2 Batterie\- und SOC\-Modell

dt\_h = timestep\_hours  
charge\_kWh    = min\(requestChargeKW, maxChargeKW, remainingCapacity / dt\_h\) \* dt\_h \* etaCharge  
discharge\_kWh = min\(requestDischargeKW, maxDischargeKW, availableEnergy / dt\_h\) \* dt\_h / etaDischarge  
standby\_kWh   = standbyW / 1000 \* dt\_h  
energyNext    = clamp\(energyNow \+ charge\_kWh \- discharge\_kWh \- standby\_kWh, minEnergy, maxEnergy\)  
socNext       = energyNext / nominalCapacityKWh

- SOC ist abgeleitet aus Energieinhalt und Nennkapazitaet; nutzbare Kapazitaet ergibt sich aus minSOC/maxSOC\.
- Lade\- und Entladeleistung werden durch C\-Rate bzw\. maxChargeKW/maxDischargeKW begrenzt\.
- Durchsatz zaehlen: throughputKWh \+= chargeAbs \+ dischargeAbs; Zyklen grob als throughput/\(2\*usableCapacity\)\.
- Alterungsmodell im MVP nur optional anzeigen; Pro kann Kapazitaetsdegradation und Wirkungsgradveraenderung ueber Jahre modellieren\.

## 5\.3 Micro\-Inverter / 24h\-Ausgangsmodell

Die 800\-W\-Klasse wird als AC\-Ausgangsprofil modelliert, nicht als Aussage ueber die elektrische Zulässigkeit eines konkreten Geräts\. Fuer echte Hardware ist ein zertifizierter Batterieausgang bzw\. ein vom Hersteller freigegebenes System erforderlich\.

targetPowerW = sum\(bank\.count \* bank\.unitRatedPowerW \* scheduleFactor\(t\)\)  
allowedPowerW = min\(targetPowerW, battery\.maxDischargeW, inverterLimitW\)  
if battery\.soc <= bank\.minSocShutdown:  
    deliveredPowerW = 0  
else:  
    deliveredPowerW = min\(allowedPowerW, energyAvailableThisStep / dt\_h \* etaDischargePath\)  
shortfallW = targetPowerW \- deliveredPowerW

# 6\. SOC\-Pre\-Run und Jahresgrenzen

Der Pre\-Run loest das Problem, dass eine Jahressimulation sonst willkuerlich mit leerem, vollem oder halbvollem Speicher startet\. Gerade bei Speichergrößen im Bereich mehrerer Tage oder bei kleinen 24h\-Ausgaengen kann ein Anfangs\-SOC die Jahreswerte deutlich verzerren\.

__Methode__

__Beschreibung__

__Bewertung__

Single Warm\-Up

Jahr einmal vorrechnen; End\-SOC als Start fuer Ergebnisjahr\.

MVP, schnell, gut erklaerbar\.

Cyclic Convergence

Gleiches Jahr wiederholen, bis Start\-/End\-SOC konvergiert\.

Pro, fuer saisonal stabile Jahresprofile\.

Previous\-Year Weather

Tatsaechliches Vorjahr als Warm\-Up, Ergebnis aktuelles Jahr\.

Pro, wenn Datenquelle mehrere Jahre liefert\.

Manual Carry\-Over

Nutzer setzt Start\-SOC manuell oder aus realem Speicherwert\.

MVP, fuer reale Anlagen\.

Technische Regel: Der Pre\-Run wird nicht in Jahres\-KPIs eingerechnet\. Er liefert nur den Startzustand und optional Debug\-Informationen\.

# 7\. Datenmodell und Persistenz

Empfehlung: Drift/SQLite fuer lokale Persistenz, weil relationale Szenarien, Zeitreihen\-Metadaten, Versionierung und Migrationen sauber abbildbar sind\.

__Tabelle__

__Felder__

__Zweck__

projects

id, name, created\_at, updated\_at, schema\_version

Projektcontainer

sites

id, project\_id, lat, lon, timezone, country\_code

Standorte

scenarios

id, project\_id, name, config\_json, engine\_version

Berechenbare Varianten

pv\_arrays

id, scenario\_id, spec\_json, topology\_node\_id

Arrays

inverters

id, scenario\_id, spec\_json, topology\_node\_id

Wechselrichter/Micro\-Inverter\-Banks

batteries

id, scenario\_id, spec\_json, topology\_node\_id

Speicher

load\_profiles

id, project\_id, source, metadata\_json

Lastdaten

weather\_series

id, site\_id, source, resolution, hash, metadata\_json

Wetterdaten\-Metadaten

simulation\_runs

id, scenario\_id, started\_at, finished\_at, input\_hash, result\_summary\_json

Reproduzierbare Laeufe

result\_points

run\_id, t\_index, timestamp, values\_blob

Optional gespeicherte Zeitreihen

- Projektdatei als JSON exportieren: alle Szenarien, Komponenten, Datenquellen\-Hashes und Engine\-Version\.
- Große Zeitreihen nicht zwingend dauerhaft speichern; bei Bedarf aus Run rekonstruieren oder als komprimierte Blobs ablegen\.
- Schema\-Migrationen ab Version 1 einplanen\. Komponentenbibliotheken muessen versioniert werden\.

# 8\. Flutter\-State\-Management

Empfehlung: Riverpod oder BLoC sind beide geeignet\. Fuer diese App ist Riverpod pragmatisch, weil Use Cases, Repositories, Async\-Provider, Simulation\-Isolates und Tests sauber injizierbar sind\.

- UI\-State: Wizard\-Schritte, Formularvalidierung, Chart\-Auswahl\.
- Domain\-State: ScenarioDraft als immutable Objekt, nur ueber Commands aendern\.
- Simulation\-State: idle/running/progress/completed/failed; Ergebnis als separater Provider\.
- Keine direkte Datenbanklogik in Widgets\. Widgets rufen Use Cases auf\.
- Lange Simulationen in Isolate auslagern; Progress ueber Stream/ReceivePort\.

# 9\. Datenquellen und Backend\-Optionen

## 9\.1 Lokale und externe Datenquellen

- CSV\-Wetterdaten: robust fuer MVP, gut fuer Power\-User\.
- CSV\-Lastprofile: Smartmeter, Home Assistant, Shelly, eigene Logger\.
- PVGIS/Global\-Solar\-Atlas\-artige Quellen: Standortdaten und PV\-Ertragsdaten; die App muss Quelle, Zeitraum und Aufloesung anzeigen \[S1\]\[S2\]\.
- Komponentenbibliothek: lokal editierbar; spaeter remote aktualisierbar\.
- Manuelle Profile: Grundlast, Tages\-/Wochenprofile, Saisonfaktoren\.

## 9\.2 Backend\-Optionen

__Option__

__Phase__

__Nutzen__

Kein Backend

MVP

Maximaler Datenschutz, einfache Entwicklung, offline\-first\.

Weather Proxy

Pro

API\-Keys schuetzen, Datenquellen normalisieren, Caching\.

Catalog Service

Pro

Module/Inverter/Speicher aktualisieren, Herstellerdaten pflegen\.

License/Account

Commercial

Abo/Freemium, Sync, geteilte Projekte\.

Simulation Backend

Spaeter

Optimierungsläufe, 15\-Minuten/Mehrjahreslaeufe auf Server auslagern\.

# 10\. Performance\-Strategie

- Typed Arrays: Float64List/Float32List fuer Zeitreihen statt Listen aus komplexen Objekten pro Zeitschritt\.
- Precompute: Sonnenstand, Zeitindex, Schedule\-Faktoren, Temperaturfaktoren und statische Verluste vor dem Loop berechnen\.
- Isolates: Simulation in separatem Isolate; UI bleibt reaktiv\.
- Streaming Progress: Ergebnis nicht erst am Ende anzeigen, sondern Fortschritt und Zwischensummen liefern\.
- Aggregation on the fly: Monats\-/Jahreswerte im Loop akkumulieren, Rohdaten optional speichern\.
- Scenario Hash: bei unveränderten Eingaben Ergebnis aus Cache verwenden\.
- Optimizer begrenzen: Parameter\-Sweeps mit Budget, Abbruch, Prioritaeten und optional Backend\.

Komplexitaet: Stundenmodus = 8760 Schritte pro Jahr; 15\-Minuten\-Modus = 35040 Schritte\. Selbst 100 Szenarien bleiben algorithmisch leicht, solange der Loop allokationsarm ist\. Teuer werden Wetterabruf, Charting grosser Zeitreihen und Optimierungslaeufe, nicht die reine Energiebilanz\.

# 11\. Tests, Validierung und Betrieb

- Unit Tests fuer Value Objects, SOC\-Grenzen, Wirkungsgrade, Dispatch und Energieerhaltung\.
- Property Tests: SOC nie ausserhalb Grenzen, Energiefluss nie negativ, keine Erzeugung aus dem Nichts\.
- Golden Scenarios: einfache PV ohne Speicher, PV mit Speicher, 24h\-Ausgang, mehrere Arrays, leerer Speicher, voller Speicher\.
- Vergleich gegen Referenzdaten: PVGIS\-/Global\-Solar\-Atlas\-/pvlib\-aehnliche Ertraege fuer vereinfachte Szenarien plausibilisieren\.
- Regression: Jede Engine\-Version speichert Input\-Hash und Result\-Hash\.
- UX\-Tests: Wizard muss technische Fehler verhindern, ohne Power\-User zu blockieren\.
- Crash\-/Telemetry nur opt\-in; keine Projektdaten ohne Zustimmung senden\.

## 11\.1 Validierungsregeln im UI

- PVArray ohne Ausrichtung/Tilt: Warnung oder Default kennzeichnen\.
- Batterie minSOC >= maxSOC: blockierender Fehler\.
- Micro\-Inverter\-Ausgang > Batterieentladeleistung: Warnung und Simulations\-Clipping\.
- 800\-W\-Grenze: als Landesprofil anzeigen, nicht hart global erzwingen\.
- Unbekannte Hardwarefreigabe fuer Batterie\->Micro\-Inverter: Warnung mit Disclaimer\.
- Fehlende Wetterdaten: Simulation blockieren oder nur Demo\-/Schätzdaten klar markieren\.

# Quellen und Recherchebasis

Die Quellen dienen als Recherchebasis für Funktionsumfang und Modellierungsansätze\. PV Calculator Pro selbst konnte in dieser Recherche nicht zuverlässig über eine offizielle Quelle verifiziert werden; die Produktanforderungen orientieren sich daher an der Funktionsklasse typischer PV\-Rechner und an den unten genannten Modellierungsquellen\.

__ID__

__Quelle__

__Relevanz__

__URL__

S1

Global Solar Atlas

Online map\-based application for solar resource and PV power potential; includes simplified PV calculator, reporting and downloads\.

[https://en\.wikipedia\.org/wiki/Global\_Solar\_Atlas](https://en.wikipedia.org/wiki/Global_Solar_Atlas)

S2

PVGIS example overview

PVGIS is used for location\-based PV yield estimation with inputs such as installed kWp, losses, tilt and azimuth\.

[https://en\.wikipedia\.org/wiki/Photovoltaic\_system](https://en.wikipedia.org/wiki/Photovoltaic_system)

S3

pvlib python

Open source PV simulation library; modeling chain covers irradiance, solar position, transposition, shading/soiling, cell temperature, DC power, MPPT, inverter and AC losses\.

[https://en\.wikipedia\.org/wiki/Pvlib\_python](https://en.wikipedia.org/wiki/Pvlib_python)

S4

Optimal sizing of solar PV and lithium battery storage

Example of sizing PV and storage using demand and generation data, iterative sizing and grid import / cost metrics\.

[https://arxiv\.org/abs/2306\.03581](https://arxiv.org/abs/2306.03581)

S5

PV self\-consumption and ramp\-rate control with battery

Shows EMS variants and the importance of maintaining SOC range for PV\+battery control\.

[https://arxiv\.org/abs/2012\.11955](https://arxiv.org/abs/2012.11955)

S6

Balkonkraftwerk / Steckersolargerät

German context for plug\-in PV systems, 800 W inverter class and registration notes including storage data\.

[https://de\.wikipedia\.org/wiki/Balkonkraftwerk](https://de.wikipedia.org/wiki/Balkonkraftwerk)

S7

State of charge

SOC is the remaining capacity of a battery relative to its capacity, commonly expressed as a percentage\.

[https://en\.wikipedia\.org/wiki/State\_of\_charge](https://en.wikipedia.org/wiki/State_of_charge)

S8

Quasi\-dynamic load and battery sizing

MILP\-based sizing/scheduling model including battery charge/discharge constraints and load scheduling\.

[https://arxiv\.org/abs/1607\.07362](https://arxiv.org/abs/1607.07362)

