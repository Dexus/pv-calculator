# Cloudflare PVGIS-Proxy – Einrichtung & Betrieb

Dieses Dokument beschreibt die vollständige Einrichtung des optionalen
Cloudflare-Caching-Proxys für PVGIS-Anfragen. Der Proxy ist nicht
zwingend erforderlich — die App funktioniert ohne ihn und fällt auf die
öffentliche PVGIS-API zurück. Er ist jedoch empfohlen für produktive
Deployments, um Ladezeiten zu reduzieren und PVGIS-Ausfälle abzufangen.

Den Worker-Quellcode und die detaillierte technische Dokumentation
findest du unter `cloudflare-pvgis-proxy/README.md`.

---

## Überblick

```
                ┌──────────────────────────┐
                │  GitHub Actions           │
                │  (pages.yml)              │
                │                           │
                │  Secret PVGIS_PROXY ──────┼──┐
                └──────────────────────────┘  │
                                              │ --dart-define
                                              ▼
Flutter Web Build ──── pvgisProxyEndpoint ────▶ PvgisApiService
                                                      │
                               ┌──────────────────────┤
                               │ wenn gesetzt          │ wenn leer
                               ▼                       ▼
                   Cloudflare Worker          re.jrc.ec.europa.eu
                   pvgis-proxy.workers.dev    (öffentliche API)
                               │
                         R2-Lookup
                         pvgis/<hash>.json
                               │
                    HIT ───────┴──── MISS → PVGIS → R2 speichern
```

---

## Schritt 1 — Cloudflare-Konto

1. [dash.cloudflare.com/sign-up](https://dash.cloudflare.com/sign-up)
   aufrufen und ein kostenloses Konto erstellen.
2. E-Mail-Adresse bestätigen.
3. Im Dashboard unter **R2 Object Storage** einmalig die Zahlungsmethode
   hinterlegen (für R2; kein tatsächlicher Kostenfall im Free Tier).

> Das Free Tier deckt typische Nutzungsmengen vollständig ab:
> 10 GB R2-Storage, 100.000 Worker-Requests/Tag, ausgehender Traffic
> kostenlos. Detaillierte Kostentabelle: `cloudflare-pvgis-proxy/README.md`.

---

## Schritt 2 — Wrangler installieren & authentifizieren

```bash
cd pv_calculator_dexus_overlay/cloudflare-pvgis-proxy
npm install          # installiert wrangler lokal ins node_modules
npx wrangler login   # öffnet den Browser für die OAuth-Anmeldung
```

Nach erfolgreicher Anmeldung speichert Wrangler ein Token unter
`~/.wrangler/config/default.toml`. Es bleibt gültig bis zum Widerruf.

---

## Schritt 3 — R2-Bucket anlegen

```bash
npx wrangler r2 bucket create pvgis-cache
```

Überprüfen:

```bash
npx wrangler r2 bucket list
```

Der Bucket `pvgis-cache` muss erscheinen.

---

## Schritt 4 — Worker deployen

```bash
npx wrangler deploy
```

Wrangler gibt die Worker-URL aus — sie hat die Form:

```
https://pvgis-proxy.<dein-subdomain>.workers.dev
```

Den Subdomain-Teil findest du im Cloudflare-Dashboard unter
**Workers & Pages → Overview**.

### Deployment verifizieren

```bash
curl -I "https://pvgis-proxy.<dein-subdomain>.workers.dev\
?lat=48.14&lon=11.58&peakpower=5&loss=14\
&angle=30&aspect=0&startyear=2020&endyear=2022\
&pvcalculation=1&outputformat=json&usehorizon=1"
```

Erwartet: `HTTP/2 200` mit `x-cache: MISS` (erster Aufruf).  
Zweiter identischer Aufruf: `x-cache: HIT`.

---

## Schritt 5 — GitHub-Secret setzen

Das Workflow `pages.yml` injiziert den Proxy-Endpunkt nur, wenn das
Secret gesetzt ist. Ohne Secret baut es ohne Proxy — kein Fehler.

**Secret anlegen:**

1. GitHub-Repository öffnen
2. **Settings** → **Secrets and variables** → **Actions**
3. **New repository secret**
   - Name: `PVGIS_PROXY`
   - Value: `https://pvgis-proxy.<dein-subdomain>.workers.dev`
4. **Add secret**

Beim nächsten Push auf `main` wird der Flutter-Web-Build automatisch
mit `--dart-define=PVGIS_PROXY=<url>` gebaut.

---

## Schritt 6 — Deployment testen

Nach dem nächsten CI-Durchlauf:

1. GitHub Pages-URL der App aufrufen
2. DevTools → Network-Tab öffnen
3. PVGIS-Import in der App anstoßen
4. Im Network-Tab: Request geht an `pvgis-proxy.*.workers.dev`,
   Response-Header enthält `x-cache: MISS` (erster Aufruf) oder
   `x-cache: HIT` (bei wiederholtem Aufruf mit gleichen Parametern)

---

## Schritt 7 — Optionale Custom Domain

Statt der `*.workers.dev`-URL kann eine eigene Domain verwendet werden,
z. B. `pvgis.example.com`:

1. Im Cloudflare-Dashboard: **Workers & Pages** → `pvgis-proxy`
   → **Triggers** → **Add Custom Domain**
2. Domain eingeben (muss auf Cloudflare als Nameserver laufen)
3. GitHub-Secret `PVGIS_PROXY` auf die neue Domain aktualisieren

---

## Variablen-Übersicht

| Stelle | Variable | Bedeutung |
|--------|----------|-----------|
| `wrangler.toml` | `bucket_name` | R2-Bucket-Name (muss mit angelegtem Bucket übereinstimmen) |
| `wrangler.toml` | `name` | Worker-Name → prägt die `*.workers.dev`-URL |
| GitHub Secret | `PVGIS_PROXY` | Vollständige Worker-URL, die der Flutter-Build einbettet |
| Dart | `PVGIS_PROXY` (dart-define) | Zur Laufzeit gelesener Endpunkt in `lib/config.dart` |
| Dart | `pvgisProxyEndpoint` | Konstante in `lib/config.dart`, `null` wenn nicht gesetzt |

---

## Troubleshooting

### Worker antwortet mit 502

PVGIS selbst ist nicht erreichbar. Der Worker gibt
`{"error":"PVGIS upstream unreachable","detail":"…"}` zurück.
Kurz warten und erneut versuchen; gecachte Anfragen sind nicht betroffen.

### `wrangler deploy` schlägt fehl: „bucket not found"

Der R2-Bucket existiert noch nicht oder der Name in `wrangler.toml`
stimmt nicht überein. `npx wrangler r2 bucket list` zeigt vorhandene
Buckets.

### Flutter-Build verwendet den Proxy nicht

`echo $PVGIS_PROXY` im Build-Schritt prüfen. Wenn leer, ist das Secret
nicht gesetzt oder der Build wurde ohne `--dart-define` ausgelöst.
In der laufenden App prüfen: `lib/config.dart` → `pvgisProxyEndpoint`
muss zur Laufzeit die Worker-URL enthalten (im Debug-Build mit einem
`print`-Statement verifizierbar).

### `x-cache: MISS` bei jeder Anfrage

Die Parameter unterscheiden sich minimal (z. B. unterschiedliche
Nachkommastellen bei `lat`/`lon`). Der Hash ist dann verschieden.
`x-cache-key` aus zwei Antworten vergleichen; unterschiedliche Werte
bestätigen die Ursache. Das `canonical`-Feld im R2-Objekt-Metadata zeigt
exakt, welche Parameter den Hash bestimmt haben.

---

## Weiterführende Links

- Technische Proxy-Dokumentation: `cloudflare-pvgis-proxy/README.md`
- Cloudflare Workers-Dokumentation: <https://developers.cloudflare.com/workers/>
- Cloudflare R2-Dokumentation: <https://developers.cloudflare.com/r2/>
- Wrangler CLI-Referenz: <https://developers.cloudflare.com/workers/wrangler/>
- PVGIS API-Dokumentation: <https://joint-research-centre.ec.europa.eu/pvgis-photovoltaic-geographical-information-system/getting-started-pvgis/api-non-interactive-service_en>
