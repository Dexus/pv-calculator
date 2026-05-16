# Overlay in `Dexus/pv-calculator` einspielen

Dieses Paket ist ein Overlay für das bestehende Repository `Dexus/pv-calculator`. Es soll die vorhandene Datei `pv_calculator_pvgis_clientv4pgis.html` nicht ersetzen.

## Variante A: GitHub-Weboberfläche

1. ZIP entpacken.
2. Repository öffnen: `Dexus/pv-calculator`.
3. `Add file` → `Upload files` wählen.
4. Inhalt des entpackten Ordners hochladen.
5. Commit idealerweise auf einem neuen Branch, z. B. `initial-flutter-engine`.
6. Pull Request öffnen.

Empfohlene Commit-Nachricht:

```text
Add Flutter/Pure Dart starter structure for PV Calculator
```

## Variante B: lokal per Git

```bash
git clone https://github.com/Dexus/pv-calculator.git
cd pv-calculator

git checkout -b initial-flutter-engine
# Inhalt dieses Overlay-Ordners in den Repo-Root kopieren.
git add .
git commit -m "Add Flutter/Pure Dart starter structure for PV Calculator"
git push -u origin initial-flutter-engine
```

Danach in GitHub einen Pull Request von `initial-flutter-engine` nach `main` öffnen.

## Erster Codex-Prompt nach dem Upload

```text
Lies AGENTS.md, docs/PRD.md, docs/ARCHITECTURE.md und pv_calculator_pvgis_clientv4pgis.html. Prüfe packages/pv_engine und app/flutter_app. Führe dart pub get, dart analyze, dart test sowie flutter pub get, flutter analyze und flutter test aus. Behebe Compile-, Analyzer- und Testfehler minimalinvasiv. Verschiebe keine Simulationslogik in die Flutter-UI. Erstelle danach einen Pull Request mit einem stabilen ersten Entwicklungsstand.
```
