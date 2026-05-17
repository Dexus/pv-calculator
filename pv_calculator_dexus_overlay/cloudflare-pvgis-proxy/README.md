# PVGIS Caching-Proxy — Cloudflare Worker + R2

Transparenter Caching-Proxy vor der öffentlichen PVGIS-API.  
Jede Anfrage wird durch einen SHA-256-Hash der kanonischen Parameter
identifiziert; Treffer beantwortet der Worker direkt aus dem R2-Bucket
ohne PVGIS zu kontaktieren.

---

## Inhaltsverzeichnis

1. [Warum dieser Proxy?](#warum-dieser-proxy)
2. [Ablauf](#ablauf)
3. [Voraussetzungen](#voraussetzungen)
4. [Cloudflare-Konto einrichten](#cloudflare-konto-einrichten)
5. [R2-Bucket anlegen](#r2-bucket-anlegen)
6. [Worker deployen](#worker-deployen)
7. [Lokale Entwicklung](#lokale-entwicklung)
8. [Flutter-App einbinden](#flutter-app-einbinden)
9. [GitHub Actions – Secret einrichten](#github-actions--secret-einrichten)
10. [Antwort-Header & Observability](#antwort-header--observability)
11. [Cache-Verwaltung](#cache-verwaltung)
12. [Konfigurationsreferenz](#konfigurationsreferenz)
13. [Sicherheitshinweise](#sicherheitshinweise)
14. [Kosten](#kosten)
15. [Lizenz](#lizenz)

---

## Warum dieser Proxy?

| Problem | Lösung |
|---------|--------|
| PVGIS-Anfragen dauern 10–30 s | R2-Treffer antworten in < 50 ms |
| Identische Anfragen von vielen Nutzern belasten PVGIS | Einmalig cachen, beliebig oft abrufen |
| CORS-Restriktionen in verwalteten Hosting-Umgebungen | Worker setzt `Access-Control-Allow-Origin: *` |
| PVGIS gelegentlich nicht erreichbar | Gecachte Antworten bleiben verfügbar |
| `PVGIS-SARAH2` ist nur unter v5.2 erreichbar | Worker routet pro `raddatabase` auf v5.2 / v5.3 |

### API-Versionen je Strahlungsdatenbank

PVGIS v5.3 liefert `PVGIS-SARAH3`, `PVGIS-ERA5` und `PVGIS-NSRDB`. Die
ältere Datenbank `PVGIS-SARAH2` wurde in v5.3 entfernt und ist nur noch
unter v5.2 verfügbar. Der Worker wählt deshalb pro Anfrage anhand des
`raddatabase`-Parameters den richtigen Upstream:

| `raddatabase` | Upstream |
|---------------|----------|
| `PVGIS-SARAH2` | `https://re.jrc.ec.europa.eu/api/v5_2/seriescalc` |
| Alles andere (inkl. unbestimmt) | `https://re.jrc.ec.europa.eu/api/v5_3/seriescalc` |

Die gleiche Routing-Regel steckt im Dart-Engine
(`pvgisSeriesCalcEndpointFor`), damit Direktaufrufe ohne Proxy identisch
ankommen. Coverage-Hinweis: `PVGIS-SARAH3` deckt Europa/Afrika,
`PVGIS-NSRDB` Nord-/Mittelamerika, `PVGIS-ERA5` global – außerhalb des
jeweiligen Abdeckungsbereichs antwortet PVGIS mit „outside coverage“
(4xx), was der Worker unverändert weiterreicht und nicht cacht.

---

## Ablauf

```
Flutter App (Browser)
        │
        │  GET https://<worker>.workers.dev?lat=…&lon=…&…
        ▼
Cloudflare Worker  ──── src/index.ts ────────────────────────┐
        │                                                      │
        │  1. Kanonische Parameter extrahieren & sortieren     │
        │  2. SHA-256-Hash → R2-Key = pvgis/<hash>.json        │
        │                                                      │
        ├─── R2-Lookup ──▶  HIT  → JSON zurückgeben ──────────┘
        │                         (X-Cache: HIT)
        │
        └─── MISS → Upstream-Request ──▶ re.jrc.ec.europa.eu
                         │
                         ├─ 2xx → In R2 speichern, antworten
                         └─ Fehler → Fehler weitergeben
                                     (X-Cache: MISS in beiden Fällen)
```

### Cache-Schlüssel

Nur die 13 Parameter, die das PVGIS-Ergebnis inhaltlich bestimmen,
gehen alphabetisch sortiert in den SHA-256-Hash ein:

| Parameter | Beschreibung |
|-----------|-------------|
| `angle` | Neigung der Module (°) |
| `aspect` | Azimut im PVGIS-System (−180…+180, Süd = 0) |
| `endyear` | Letztes Datenjahr |
| `lat` | Breitengrad |
| `lon` | Längengrad |
| `loss` | Systemverluste (%) |
| `components` | Strahlungskomponenten ausgeben (`0`/`1`) — `1` liefert beim horizontalen Modus die Diffusanteile separat |
| `mountingplace` | `building` oder `free` |
| `outputformat` | Immer `json` (vom Worker erzwungen) |
| `peakpower` | Spitzenleistung in kWp |
| `pvcalculation` | `1` = PV-Leistung berechnen, `0` = nur Einstrahlung (horizontal). Beide Modi haben getrennte Cache-Einträge. |
| `raddatabase` | Strahlungsdatenbank, z. B. `PVGIS-SARAH3` |
| `startyear` | Erstes Datenjahr |
| `usehorizon` | Horizont-Abschattung (`0`/`1`) |

Zusätzliche Parameter werden an PVGIS weitergeleitet, gehen aber
**nicht** in den Cache-Key ein.

### R2-Objekte

```
pvgis/
  <64-stelliger-Hex-Hash>.json   ← PVGIS-JSON-Antwort
```

Jedes Objekt trägt Custom-Metadata:

| Feld | Inhalt |
|------|--------|
| `canonical` | Kanonischer Query-String, aus dem der Hash stammt |
| `fetchedAt` | ISO-8601-Zeitstempel des ersten Upstream-Abrufs |

---

## Voraussetzungen

- **Cloudflare-Konto** (kostenlos)
- **Node.js** ≥ 18 — nur für die lokale Entwicklung mit Wrangler
- **npm** ≥ 9

---

## Cloudflare-Konto einrichten

### 1. Konto erstellen

Falls noch kein Konto vorhanden:

1. [dash.cloudflare.com](https://dash.cloudflare.com/sign-up) öffnen
2. E-Mail-Adresse und Passwort eingeben → **Create Account**
3. E-Mail-Adresse bestätigen

Für diesen Worker wird **kein** Kauf einer Domain benötigt.
Das kostenlose Workers-Plan reicht aus.

### 2. R2 freischalten

R2 ist im Cloudflare-Dashboard unter **R2 Object Storage** verfügbar.
Beim ersten Aufruf wird die Zahlungsmethode hinterlegt (Kreditkarte oder
PayPal). Das **Free Tier** umfasst monatlich:

- 10 GB Storage
- 1 Mio. Klassen-A-Operationen (Schreibvorgänge)
- 10 Mio. Klassen-B-Operationen (Lesevorgänge)

Für den PVGIS-Cache reicht das Free Tier in der Regel aus — ein typisches
PVGIS-JSON-Objekt ist ~300 KB, also passen ~33.000 Standorte in 10 GB.

---

## R2-Bucket anlegen

### Option A — Dashboard (empfohlen für Ersteinrichtung)

1. Im Cloudflare-Dashboard → **R2 Object Storage** → **Create bucket**
2. Name: `pvgis-cache`
3. Region: **Automatic** (Cloudflare verteilt selbst)
4. **Create bucket**

### Option B — Wrangler CLI

```bash
cd pv_calculator_dexus_overlay/cloudflare-pvgis-proxy
npm install
npx wrangler login          # Browser öffnet OAuth-Seite
npx wrangler r2 bucket create pvgis-cache
```

Der Name `pvgis-cache` muss mit dem `bucket_name` in `wrangler.toml`
übereinstimmen. Soll ein anderer Name verwendet werden, beide Stellen
gleichzeitig ändern.

---

## Worker deployen

```bash
cd pv_calculator_dexus_overlay/cloudflare-pvgis-proxy
npm install
npx wrangler login          # nur beim ersten Mal nötig
npx wrangler deploy
```

Wrangler gibt nach dem Deploy die Worker-URL aus:

```
https://pvgis-proxy.<ihr-subdomain>.workers.dev
```

Diese URL wird in Schritt [Flutter-App einbinden](#flutter-app-einbinden)
und [GitHub Actions](#github-actions--secret-einrichten) benötigt.

### Worker-URL prüfen

```bash
curl -s "https://pvgis-proxy.<ihr-subdomain>.workers.dev?lat=48.14&lon=11.58\
&peakpower=5&loss=14&angle=30&aspect=0\
&startyear=2020&endyear=2022\
&pvcalculation=1&outputformat=json&usehorizon=1" \
  -o /dev/null -w "%{http_code}  X-Cache: %header{x-cache}\n"
```

Erwartete Ausgabe beim ersten Aufruf: `200  X-Cache: MISS`  
Beim zweiten Aufruf mit denselben Parametern: `200  X-Cache: HIT`

---

## Lokale Entwicklung

```bash
cd pv_calculator_dexus_overlay/cloudflare-pvgis-proxy
npm install
npx wrangler dev --local
```

`--local` simuliert R2 im Dateisystem (`.wrangler/state/`), sodass keine
echten Cloudflare-Ressourcen verbraucht werden.

Der Worker ist dann unter `http://localhost:8787` erreichbar:

```bash
curl "http://localhost:8787?lat=48.14&lon=11.58&peakpower=5&loss=14\
&angle=30&aspect=0&startyear=2020&endyear=2022\
&pvcalculation=1&outputformat=json&usehorizon=1"
```

**Flutter parallel starten:**

```bash
# Terminal 1 — Worker
cd pv_calculator_dexus_overlay/cloudflare-pvgis-proxy
npx wrangler dev --local

# Terminal 2 — Flutter Web
cd pv_calculator_dexus_overlay/app/flutter_app
flutter run -d chrome \
  --dart-define=PVGIS_PROXY=http://localhost:8787
```

### TypeScript-Typen prüfen

```bash
npm run typecheck
```

### Tests ausführen

```bash
npm test
```

Die Suite läuft unter `@cloudflare/vitest-pool-workers`; sie startet einen
isolierten Worker-Runtime mit demselben `wrangler.toml` und einem
in-memory R2-Bucket. Upstream-PVGIS-Aufrufe werden mit `fetchMock`
abgefangen, kein Netzwerkzugriff erforderlich.

---

## Flutter-App einbinden

Die App liest den Proxy-Endpunkt aus dem Dart-Define `PVGIS_PROXY`.
Ohne dieses Define fällt sie auf die öffentliche PVGIS-API zurück —
kein Fehler, nur kein Caching.

### Web-Release-Build

```bash
flutter build web \
  --release \
  --dart-define=PVGIS_PROXY=https://pvgis-proxy.<ihr-subdomain>.workers.dev \
  --base-href /pv-calculator/app/
```

### Entwicklungs-Server

```bash
flutter run -d chrome \
  --dart-define=PVGIS_PROXY=https://pvgis-proxy.<ihr-subdomain>.workers.dev
```

---

## GitHub Actions – Secret einrichten

Das GitHub-Actions-Workflow `pages.yml` baut den Flutter-Web-Client und
deployt ihn auf GitHub Pages. Es injiziert `PVGIS_PROXY` nur, wenn das
Secret im Repository gesetzt ist — ohne Secret funktioniert der Build
genauso, nur ohne Proxy.

### Secret anlegen

1. GitHub-Repository öffnen
2. **Settings** → **Secrets and variables** → **Actions**
3. **New repository secret**
4. Name: `PVGIS_PROXY`
5. Value: `https://pvgis-proxy.<ihr-subdomain>.workers.dev`
6. **Add secret**

Das war alles. Beim nächsten Push auf `main` wird das Secret automatisch
vom Workflow aufgegriffen.

### Wie der Workflow das Secret verwendet

```yaml
# Auszug aus .github/workflows/pages.yml
- name: Flutter build web
  env:
    PVGIS_PROXY: ${{ secrets.PVGIS_PROXY }}   # leer wenn nicht gesetzt
  run: |
    dart_defines=""
    if [ -n "$PVGIS_PROXY" ]; then
      dart_defines="--dart-define=PVGIS_PROXY=$PVGIS_PROXY"
    fi
    flutter build web --release \
      --base-href "/pv-calculator/app/" \
      $dart_defines
```

Ist das Secret nicht gesetzt, bleibt `$PVGIS_PROXY` leer, die
`if`-Bedingung schlägt fehl und `$dart_defines` bleibt leer → Build
ohne Proxy-Endpunkt.

### Secret löschen / ändern

Unter **Settings → Secrets → Actions → PVGIS_PROXY → Update / Remove**.  
Nach einer Änderung einfach einen neuen Push auf `main` auslösen oder den
Workflow manuell über **Actions → Deploy GitHub Pages → Run workflow**
starten.

---

## Antwort-Header & Observability

| Header | Werte | Bedeutung |
|--------|-------|-----------|
| `X-Cache` | `HIT` / `MISS` | Antwort aus R2 oder von PVGIS |
| `X-Cache-Key` | 64-stelliger Hex-String | SHA-256 der kanonischen Parameter |

Den `X-Cache-Key` kann man nutzen, um ein einzelnes Objekt in R2 zu
finden oder gezielt zu löschen (siehe Cache-Verwaltung).

**Loglevel im Cloudflare-Dashboard:**  
Dashboard → Workers & Pages → `pvgis-proxy` → **Logs** zeigt alle
Requests mit Status, Latenz und Worker-Logs in Echtzeit.

---

## Cache-Verwaltung

### Einzelnes Objekt löschen

```bash
npx wrangler r2 object delete pvgis-cache pvgis/<hash>.json
```

Den Hash entnimmt man dem `X-Cache-Key`-Response-Header oder dem
`canonical`-Metadata-Feld im Cloudflare-Dashboard.

### Alle Cache-Einträge auflisten

```bash
npx wrangler r2 object list pvgis-cache --prefix pvgis/
```

### Gesamten Cache leeren

Cloudflare bietet kein Bulk-Delete über Wrangler. Workaround via Shell:

```bash
npx wrangler r2 object list pvgis-cache --prefix pvgis/ --json \
  | jq -r '.[].key' \
  | xargs -I{} npx wrangler r2 object delete pvgis-cache {}
```

Alternativ: Bucket im Dashboard löschen, neu anlegen, dann
`npx wrangler deploy` erneut ausführen (der Bucket-Bind bleibt erhalten).

### Objekt-Metadaten ansehen

```bash
npx wrangler r2 object head pvgis-cache pvgis/<hash>.json
```

Gibt u. a. `fetchedAt` und `canonical` aus den Custom-Metadata aus.

---

## Konfigurationsreferenz

### `wrangler.toml`

```toml
name = "pvgis-proxy"         # Worker-Name; bestimmt die *.workers.dev-URL
main = "src/index.ts"        # TypeScript-Einstiegspunkt
compatibility_date = "2024-09-23"  # Cloudflare-Runtime-Snapshot

[[r2_buckets]]
binding = "PVGIS_CACHE"      # Name des Bindings im TypeScript-Code (Env)
bucket_name = "pvgis-cache"  # Tatsächlicher R2-Bucket-Name im Account
```

### Staging-Umgebung (optional)

Für einen separaten Staging-Bucket:

```toml
[env.staging]
[[env.staging.r2_buckets]]
binding = "PVGIS_CACHE"
bucket_name = "pvgis-cache-staging"
```

Bucket anlegen: `npx wrangler r2 bucket create pvgis-cache-staging`  
Deploy auf Staging: `npx wrangler deploy --env staging`  
Staging-URL: `https://pvgis-proxy-staging.<subdomain>.workers.dev`

### Eigene Domain (optional)

Im Cloudflare-Dashboard → Workers & Pages → `pvgis-proxy` → **Triggers**
→ **Add Custom Domain** kann der Worker unter einer eigenen Domain
betrieben werden, z. B. `pvgis.example.com`.

---

## Sicherheitshinweise

- **Kein offener Proxy** — `PVGIS_UPSTREAM` ist hart kodiert. Der Worker
  leitet ausschließlich an `re.jrc.ec.europa.eu` weiter; er kann nicht als
  genereller HTTP-Proxy missbraucht werden.
- **Keine API-Keys** — PVGIS ist keyless. Der Worker speichert und
  überträgt keine Credentials.
- **CORS auf `*`** — passend für eine öffentliche statische Web-App.
  Soll der Worker nur von einer bestimmten Origin erreichbar sein,
  `Access-Control-Allow-Origin` auf diese Domain einschränken
  (Änderung in `src/index.ts`, Konstante `CORS_HEADERS`).
- **Fehlerantworten werden nicht gecacht** — nur HTTP-2xx-Antworten von
  PVGIS landen in R2. Ungültige Koordinaten o. ä. werden nicht dauerhaft
  gespeichert.

---

## Kosten

### Cloudflare Workers Free Plan

| Ressource | Free-Tier-Limit | Typischer Verbrauch |
|-----------|-----------------|---------------------|
| Worker-Requests | 100.000 / Tag | Niedrig (Nutzer teilen den Cache) |
| CPU-Zeit | 10 ms / Request | < 1 ms pro Request |

### Cloudflare R2 Free Tier

| Ressource | Free-Tier-Limit |
|-----------|-----------------|
| Storage | 10 GB / Monat |
| Klasse-A-Ops (Schreiben) | 1 Mio. / Monat |
| Klasse-B-Ops (Lesen) | 10 Mio. / Monat |
| Egress | kostenlos |

Ein PVGIS-JSON-Objekt ist typischerweise 200–400 KB. Bei 10 GB passen
~25.000–50.000 unique Standort-/Parameter-Kombinationen in den Cache —
für den privaten und semi-professionellen Einsatz mehr als ausreichend.

---

## Lizenz

AGPL-3.0 — wie das restliche Repository. Wer diesen Worker als SaaS
betreibt, muss den Quelltext der Nutzerschaft zugänglich machen.
