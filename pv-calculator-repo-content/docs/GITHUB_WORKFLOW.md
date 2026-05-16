# GitHub Workflow

## Ziel

`Dexus/pv-calculator` ist die zentrale Ablage fuer Projektunterlagen und Code.

## Erstimport aus diesem Paket

1. ZIP entpacken.
2. Inhalt des Ordners `pv-calculator-repo-content` in die lokale Arbeitskopie von `Dexus/pv-calculator` kopieren.
3. Aenderungen pruefen.
4. Commit erstellen und nach `main` pushen.

```bash
git clone https://github.com/Dexus/pv-calculator.git
cd pv-calculator
cp -R /pfad/zum/pv-calculator-repo-content/. .
git status
git add README.md docs prototypes app scripts
git commit -m "Add PV Calculator docs and starter code"
git push origin main
```

## Laufende Regeln

- Dokumente bevorzugt als Markdown speichern.
- Prototypen unter `prototypes/` ablegen.
- Flutter-App unter `app/` entwickeln.
- Chat-Ergebnisse zeitnah in Dateien ueberfuehren.
- Groessere Aenderungen ueber Branch + Pull Request.

## Empfohlene Branches

- `main`: stabiler Projektstand.
- `feature/flutter-domain`: Domain-Modelle und Simulation.
- `feature/html-prototype`: schnelle Prototyp-Aenderungen.
- `feature/export`: CSV/JSON/PDF-Export.
