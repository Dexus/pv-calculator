# Architektur – PV Calculator

## Prinzip

Domain first: Die Simulationslogik liegt in `packages/pv_engine` und bleibt unabhängig von Flutter testbar. Die Flutter-App sammelt Eingaben, zeigt Ergebnisse und speichert Projekte.

```text
Flutter UI
  ↓
Application State / View Models
  ↓
packages/pv_engine
  ├─ Domain Models
  ├─ Synthetic Solar Fallback
  ├─ Inverter Limiting
  ├─ Battery Dispatch
  └─ Simulation Summary
  ↓
Data Adapters / Persistence / APIs
```

## Module

- `packages/pv_engine`: PV-Arrays, Wechselrichter, Batterie, Lastprofil, SimulationConfig, PvSimulator, Ergebniszusammenfassung.
- `app/flutter_app`: Eingabeformulare, KPI-Ausgabe, Tabellen/Charts, Projekt-Speichern/Laden.
- `docs`: Anforderungen, Architektur, Roadmap, technische Entscheidungen.

## Externe Datenquellen

PVGIS, Wetterdaten, reale Gerätekennlinien und Lastprofilimporte sollen später als Adapter ergänzt werden. Die Engine darf nicht direkt von UI oder API-Implementierungen abhängen.

## Teststrategie

- Unit-Tests für Dispatch, SOC-Grenzen, Wechselrichterkappung, Export-Limit und Lastprofil.
- Widget-Tests für wichtigste UI-Zustände.
- Regressionstests mit Beispielkonfigurationen.
