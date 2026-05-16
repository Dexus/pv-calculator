# Architektur: PV Calculator Flutter App

## 1. Architekturprinzip

Die App folgt einer klaren Trennung zwischen UI, Anwendungslogik, Domain-Modellen und Infrastruktur. Dadurch kann die Simulationslogik getestet und spaeter auch in einem Backend oder CLI-Werkzeug wiederverwendet werden.

```text
Presentation/UI
  ↓
Application Services
  ↓
Domain Models + Simulation Engine
  ↓
Infrastructure: Storage, Import/Export, external PV data adapters
```

## 2. Schichten

### 2.1 Presentation

Flutter-Screens, Formulare, Charts und Ergebnisansichten. Diese Schicht darf keine fachliche Simulationslogik enthalten, sondern nur Eingaben validieren, Services aufrufen und Ergebnisse anzeigen.

### 2.2 Application Services

Koordiniert Use-Cases wie:

- Projekt laden/speichern,
- Simulation starten,
- Export erzeugen,
- Annahmen validieren,
- spaeter Datenquellen synchronisieren.

### 2.3 Domain

Enthaelt die Kernobjekte:

- `PvArray`,
- `Inverter`,
- `Battery`,
- `LoadProfile`,
- `SimulationConfig`,
- `SimulationStep`,
- `SimulationSummary`.

### 2.4 Infrastructure

- lokale Persistenz,
- CSV-/JSON-Export,
- Adapter fuer PVGIS, Global-Solar-Atlas-artige Quellen oder pvlib-inspirierte Modellketten,
- spaeter Auth/Backend, falls benoetigt.

## 3. Simulationspipeline

1. Eingaben normalisieren.
2. PV-Rohproduktion je Array berechnen.
3. Wechselrichterlimits und Rollen anwenden.
4. Haushaltslast je Zeitschritt bestimmen.
5. PV direkt fuer Last nutzen.
6. Ueberschuss in Batterie laden.
7. Batterie bei Bedarf entladen.
8. Netzbezug, Einspeisung und Abregelung berechnen.
9. SOC fortschreiben.
10. KPIs aggregieren.

## 4. Dispatch-Logik im MVP

Prioritaet pro Zeitschritt:

1. PV deckt aktuelle Last.
2. PV-Ueberschuss laedt Batterie.
3. Restlicher PV-Ueberschuss wird eingespeist oder abgeregelt.
4. Batterie deckt verbleibende Last, soweit SOC und Leistung reichen.
5. Restlast wird aus dem Netz bezogen.

Spaeter koennen alternative Strategien hinzukommen, z. B. zeitvariable Tarife, prognosebasiertes Laden oder 24h-Batterieausgang fuer Micro-Inverter.

## 5. Datenhaltung

Empfohlenes Format fuer Projektdateien:

- JSON fuer Konfiguration,
- CSV fuer Zeitreihen,
- Markdown fuer Dokumentation,
- Tests als Teil des App-Codes.

## 6. Teststrategie

- Unit-Tests fuer Domain-Modelle und Simulation.
- Golden-/Widget-Tests fuer UI spaeter.
- CSV-/JSON-Exporttests.
- Smoke-Test fuer HTML-Prototyp.
- Regressionsdaten fuer Beispielprojekte.

## 7. Erweiterung auf reale PV-Daten

Die aktuelle Simulation verwendet bewusst einfache synthetische Erzeugungsmodelle. Fuer Produktionsqualitaet werden spaeter Adapter benoetigt:

- standortbasierte Einstrahlungsdaten,
- Temperatur-/Verlustmodelle,
- Modul- und Wechselrichterkennlinien,
- Verschattungs- und Horizontdaten,
- reale Lastprofile.
