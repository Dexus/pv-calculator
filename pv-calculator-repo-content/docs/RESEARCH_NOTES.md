# Recherche- und Annahmennotizen

## Modellierungsrahmen

Die App orientiert sich an der Funktionsklasse typischer PV-Ertragsrechner und PV-Simulationstools. Relevante Bausteine fuer spaetere Produktionsqualitaet:

- standortbezogene Solar-/Einstrahlungsdaten,
- PV-Modellkette von Einstrahlung bis AC-Ausgang,
- Speicherdispatch und SOC-Management,
- Lastprofile und Eigenverbrauchsoptimierung,
- 800-W-Steckersolar-/Micro-Inverter-Kontext.

## Aktuelle Annahmen im Prototyp

- Synthetische Tages- und Saisonkurve statt realer Wetterdaten.
- Vereinfachter Orientierungsfaktor aus Dachneigung und Azimut.
- Einfache Wechselrichterlimits.
- Einfache Batterie-Wirkungsgrade.
- Keine Verschattung und keine realen Modulkennlinien.

## Spaetere Datenquellen/Modelle

- PVGIS- oder Global-Solar-Atlas-artige Standortdaten.
- pvlib-inspirierte Modellkette.
- Reale Lastprofile, z. B. CSV-Import.
- Geraetedatenbank fuer Module, Wechselrichter und Speicher.
