# pv-calculator

PVGIS-driven photovoltaic, battery storage and 800 W micro-inverter simulator that runs entirely in the browser.

## Live demo

The standalone HTML app (`pv_calculator_pvgis_clientv4pgis.html`) is published via GitHub Pages:

- https://dexus.github.io/pv-calculator/

No backend or local proxy is required. The page generates direct PVGIS links, lets you import the returned JSON/CSV, and then runs the PV, battery, SOC carry-over and 24 h / 800 W group simulation locally in the browser.

## Repository layout

- `pv_calculator_pvgis_clientv4pgis.html` — the single-file web app deployed to GitHub Pages (served as `index.html`).
- `pv_calculator_dexus_overlay/` — Flutter app and Dart `pv_engine` package (covered by the `CI` workflow).
- `pv-calculator-repo-content/` — additional repo content.
- `docs/research-req.txt` — research requirements.

## Deployment

GitHub Pages is built and deployed by `.github/workflows/pages.yml`:

1. On every push to `main` that touches the HTML file (or via manual `workflow_dispatch`), the workflow stages the HTML as `index.html` in a `_site/` directory.
2. The artifact is uploaded with `actions/upload-pages-artifact` and published with `actions/deploy-pages`.

### One-time repository setup

In **Settings → Pages**, set **Source** to **GitHub Actions**. After the first successful run the site is available at the URL above (and is also shown in the workflow run summary).

### Running locally

The app is a single HTML file with no build step — open it directly:

```sh
# Either open the file in your browser:
xdg-open pv_calculator_pvgis_clientv4pgis.html

# …or serve the directory:
python3 -m http.server 8000
# then visit http://localhost:8000/pv_calculator_pvgis_clientv4pgis.html
```

## License

See [LICENSE](LICENSE).
