# PVGIS Caching-Proxy (Cloudflare Worker + R2)

Cloudflare Worker, der als transparenter Caching-Proxy vor der öffentlichen
PVGIS-API sitzt. Jede Anfrage wird durch einen SHA-256-Hash der kanonischen
Parameter identifiziert; bei einem Treffer antwortet der Worker direkt aus
dem R2-Bucket ohne die PVGIS-API zu kontaktieren.

## Warum dieser Proxy?

Die öffentliche PVGIS-API (`re.jrc.ec.europa.eu`) hat keine publizierten
Rate-Limits, reagiert jedoch bei Last langsam (10–30 s pro Anfrage) und ist
gelegentlich nicht erreichbar. Für eine Browser-App kommen zwei weitere
Einschränkungen hinzu:

- **CORS** – Die API liefert zwar `Access-Control-Allow-Origin: *`, aber
  managed Hosting-Umgebungen (z. B. GitHub Pages hinter einem CDN) können
  das Preflight blockieren.
- **Wiederholte identische Anfragen** – Dieselben Koordinaten, Azimut- und
  Neigungs-Werte werden von verschiedenen Nutzern und bei jedem App-Reload
  neu angefragt, obwohl sich PVGIS-Wetterdaten nicht täglich ändern.

Der Proxy löst beides: Er liefert gecachte Antworten in < 50 ms und setzt
die nötigen CORS-Header.

## Ablauf

```
Flutter App
    │
    │ GET https://<worker>.workers.dev?lat=…&lon=…&…
    ▼
Cloudflare Worker (src/index.ts)
    │
    ├─ 1. Kanonische Parameter extrahieren & sortieren
    ├─ 2. SHA-256-Hash berechnen → Cache-Key = pvgis/<hash>.json
    │
    ├─ R2-Lookup ──▶ HIT → JSON direkt zurückgeben (X-Cache: HIT)
    │
    └─ MISS → Upstream-Request an re.jrc.ec.europa.eu
                   │
                   ├─ OK (2xx) → Antwort in R2 speichern
                   └─ Antwort an Client weiterleiten (X-Cache: MISS)
```

### Cache-Schlüssel

Nur die Parameter, die das PVGIS-Ergebnis inhaltlich bestimmen, gehen in den
Hash ein. Sie werden alphabetisch sortiert, bevor der Hash berechnet wird,
sodass reihenfolge-verschiedene aber inhaltlich gleiche Anfragen denselben
Schlüssel erzeugen:

| Parameter | Bedeutung |
|-----------|-----------|
| `angle` | Neigung der Module (°) |
| `aspect` | Azimut im PVGIS-Koordinatensystem |
| `endyear` | Letztes Jahr der Zeitreihe |
| `lat` | Breitengrad |
| `lon` | Längengrad |
| `loss` | Systemverluste (%) |
| `mountingplace` | `building` oder `free` |
| `outputformat` | Immer `json` (vom Worker erzwungen) |
| `peakpower` | Spitzenleistung in kWp |
| `pvcalculation` | Immer `1` (vom Worker erzwungen) |
| `raddatabase` | Strahlungsdatenbank, z. B. `PVGIS-SARAH3` |
| `startyear` | Erstes Jahr der Zeitreihe |
| `usehorizon` | Horizont-Abschattung (`0`/`1`) |

Zusätzliche Parameter, die der Client schickt, werden an den Upstream
weitergeleitet, **gehen aber nicht in den Hash ein** – sie beeinflussen also
nicht den Cache-Key.

### R2-Objektstruktur

```
pvgis/
  <64 Zeichen Hex-Hash>.json   ← JSON-Antwort von PVGIS
```

Jedes Objekt trägt zwei Custom-Metadata-Felder:

| Feld | Inhalt |
|------|--------|
| `canonical` | Der kanonische Query-String, aus dem der Hash berechnet wurde |
| `fetchedAt` | ISO-8601-Zeitstempel des ersten Upstream-Abrufs |

## Voraussetzungen

- **Cloudflare-Account** mit aktiviertem R2 (kostenloses Tier reicht für
  den Anfang: 10 GB Storage, 1 Mio. Klassen-A-Operationen/Monat gratis).
- **Node.js** ≥ 18 (für `wrangler`).
- **Wrangler CLI** wird über `npm install` lokal installiert; ein globales
  `npm install -g wrangler` ist nicht nötig.

## Ersteinrichtung

### 1. Abhängigkeiten installieren

```bash
cd pv_calculator_dexus_overlay/cloudflare-pvgis-proxy
npm install
```

### 2. Bei Cloudflare anmelden

```bash
npx wrangler login
```

Der Browser öffnet die OAuth-Seite. Nach der Anmeldung speichert Wrangler
ein Token lokal.

### 3. R2-Bucket anlegen

```bash
npx wrangler r2 bucket create pvgis-cache
```

Der Bucket-Name `pvgis-cache` muss mit dem `bucket_name`-Feld in
`wrangler.toml` übereinstimmen. Soll ein anderer Name verwendet werden, beide
Stellen gleichzeitig anpassen.

### 4. Worker deployen

```bash
npx wrangler deploy
```

Wrangler gibt nach dem Deploy die Worker-URL aus, z. B.:
```
https://pvgis-proxy.<subdomain>.workers.dev
```

Diese URL wird für die Flutter-Integration benötigt (siehe unten).

## Lokale Entwicklung

```bash
npx wrangler dev
```

Der Worker läuft auf `http://localhost:8787`. R2-Zugriffe gehen dabei gegen
den echten Cloudflare-Account (nicht lokal simuliert), es sei denn, es wird
`--local` übergeben – dann wird ein lokales R2-Verzeichnis verwendet:

```bash
npx wrangler dev --local
```

Testaufruf:

```bash
curl -v "http://localhost:8787?lat=48.137154&lon=11.576124&peakpower=5&loss=14&angle=30&aspect=0&startyear=2020&endyear=2022&pvcalculation=1&outputformat=json&usehorizon=1"
```

Der Header `X-Cache: MISS` erscheint beim ersten Aufruf, `X-Cache: HIT` bei
jedem weiteren mit denselben Parametern.

## TypeScript prüfen (ohne Deploy)

```bash
npm run typecheck
```

## Flutter-App integrieren

Die Flutter-App liest den Proxy-Endpunkt zur Build-Zeit aus dem
`--dart-define`-Parameter `PVGIS_PROXY`. Ohne diesen Parameter fällt die App
auf die öffentliche PVGIS-API zurück.

### Web-Build

```bash
flutter build web \
  --dart-define=PVGIS_PROXY=https://pvgis-proxy.<subdomain>.workers.dev
```

### Lokale Entwicklung mit dem Worker

```bash
# Terminal 1: Worker lokal starten
cd pv_calculator_dexus_overlay/cloudflare-pvgis-proxy
npx wrangler dev --local

# Terminal 2: Flutter Web mit lokalem Proxy
cd pv_calculator_dexus_overlay/app/flutter_app
flutter run -d chrome \
  --dart-define=PVGIS_PROXY=http://localhost:8787
```

### GitHub Pages / CI

In `.github/workflows/pages.yml` (oder dem zuständigen Deployment-Job) den
`--dart-define`-Parameter als Secret übergeben:

```yaml
- name: Build Flutter Web
  run: |
    flutter build web \
      --dart-define=PVGIS_PROXY=${{ secrets.PVGIS_PROXY_URL }}
```

Das Secret `PVGIS_PROXY_URL` im GitHub-Repository unter
**Settings → Secrets and variables → Actions** anlegen.

## Antwort-Header

Jede Worker-Antwort enthält zwei Diagnose-Header:

| Header | Werte | Bedeutung |
|--------|-------|-----------|
| `X-Cache` | `HIT` / `MISS` | Ob die Antwort aus R2 kam |
| `X-Cache-Key` | 64-stelliger Hex-String | SHA-256 der kanonischen Parameter |

Mit dem `X-Cache-Key` lässt sich ein spezifisches Objekt manuell in R2
suchen oder löschen (siehe Cache-Verwaltung).

## Cache-Verwaltung

### Einzelnes Objekt löschen

```bash
npx wrangler r2 object delete pvgis-cache pvgis/<hash>.json
```

Den Hash entnimmt man dem `X-Cache-Key`-Header einer vorherigen Antwort oder
dem Custom-Metadata-Feld `canonical` im R2-Dashboard.

### Alle Cache-Einträge auflisten

```bash
npx wrangler r2 object list pvgis-cache --prefix pvgis/
```

### Gesamten Cache leeren

Cloudflare bietet kein Bulk-Delete über Wrangler. Variante über die API:

```bash
# Alle Keys abrufen und einzeln löschen (Beispiel mit jq + xargs)
npx wrangler r2 object list pvgis-cache --prefix pvgis/ --json \
  | jq -r '.[].key' \
  | xargs -I{} npx wrangler r2 object delete pvgis-cache {}
```

Alternativ: Bucket im Dashboard löschen und neu anlegen, dann
`npx wrangler deploy` erneut ausführen.

## Konfigurationsreferenz (`wrangler.toml`)

```toml
name = "pvgis-proxy"        # Worker-Name; beeinflusst die *.workers.dev-URL
main = "src/index.ts"       # Einstiegspunkt
compatibility_date = "2024-09-23"  # Cloudflare-Runtime-Snapshot

[[r2_buckets]]
binding = "PVGIS_CACHE"     # Name des Env-Bindings im TypeScript-Code
bucket_name = "pvgis-cache" # Tatsächlicher R2-Bucket-Name im Account
```

Für einen separaten Staging-Bucket:

```toml
[[env.staging.r2_buckets]]
binding = "PVGIS_CACHE"
bucket_name = "pvgis-cache-staging"
```

Deploy auf Staging: `npx wrangler deploy --env staging`

## Sicherheitshinweise

- Der Worker leitet **alle** Anfrage-Parameter unverändert an PVGIS weiter.
  Eingabe-Validierung findet auf Client-Seite im Dart-Code statt
  (`PvgisRequest.validate()` in `pv_engine`). Wer den Worker öffentlich
  betreibt, sollte prüfen, ob er als offener Proxy für beliebige
  Upstream-URLs missbraucht werden kann – das ist hier ausgeschlossen, da
  `PVGIS_UPSTREAM` hart kodiert ist.
- **Keine API-Keys** – PVGIS ist keyless. Der Worker speichert keine
  Credentials und überträgt keine.
- CORS ist auf `*` gesetzt, weil die App als statische Web-App von
  beliebigen Origins geladen werden kann. Soll der Worker nur von einer
  bestimmten Domain erreichbar sein, `Access-Control-Allow-Origin` auf diese
  Domain einschränken.

## Lizenz

AGPL-3.0 – wie das restliche Repository. Wer den Worker als SaaS betreibt,
muss den Quellcode der Nutzerschaft zugänglich machen.
