# PV Calculator — Research Papers

Curated collection of academic papers and resources for building a full-featured
PV solar calculator app. Organized by topic, covering simulation algorithms,
battery dispatch, irradiance modeling, inverter physics, financial metrics,
and validation methods.

## How to use this

Each paper has a markdown file: `P<id>_<short-name>.md` containing:
- Full citation with DOI/URL
- Relevance summary (why it matters for our calculator)
- Key algorithms / formulas to extract (to be filled when reading)
- Applicable engine components
- Reading status checklist

## Papers by topic

### Self-Consumption & Dispatch
| # | Paper | Year | Citations | Priority |
|---|-------|------|-----------|----------|
| P01 | Photovoltaic self-consumption in buildings: A review (Luthander) | 2015 | 1021 | MUST |
| P30 | Energy yield with different battery dispatch strategies (Quoilin) | 2016 | 200+ | MUST |
| P18 | PV self-consumption with battery storage analysis | 2018 | 100+ | HIGH |
| P02 | Optimal sizing of PV + storage for residential (Beck) | 2017 | 108 | HIGH |
| P35 | PV self-consumption + VRFB ramp-rate control with forecast (Foles) | 2022 | — | MED |
| P36 | Decision Transformer battery dispatch for PV self-consumption (Henrich) | 2026 | — | LOW |

### Irradiance & PVGIS
| # | Paper | Year | Citations | Priority |
|---|-------|------|-----------|----------|
| P04 | PVGIS solar radiation database (Suri) | 2007 | 1000+ | MUST |
| P03 | PVGIS methodology overview (JRC) | 2007 | 800+ | MUST |
| P13 | Solar irradiance modelling review (Jamil) | 2018 | 300+ | HIGH |
| P27 | Reindl tilted surface irradiance model | 1990 | 2000+ | HIGH |
| P28 | Perez sky diffuse irradiance model | 1987 | 3000+ | HIGH |

### Inverter & Temperature Models
| # | Paper | Year | Citations | Priority |
|---|-------|------|-----------|----------|
| P06 | Sandia PV performance model (King) | 2004 | 2000+ | MUST |
| P07 | Inverter sizing strategies (Burger) | 2006 | 500+ | HIGH |
| P14 | PV cell temperature model (Mattei) | 2006 | 1000+ | HIGH |
| P25 | Temperature effect by PV technology (Huld) | 2010 | 500+ | HIGH |

### Battery Sizing & SOC
| # | Paper | Year | Citations | Priority |
|---|-------|------|-----------|----------|
| P10 | Optimal battery sizing in microgrids (Abbey) | 2015 | 500+ | HIGH |
| P09 | Battery sizing methodology (Al-falahi) | 2017 | 200+ | MED |
| P21 | Battery technology comparison for residential PV | 2020 | 200+ | MED |

### Tilt, Azimuth & Shading
| # | Paper | Year | Citations | Priority |
|---|-------|------|-----------|----------|
| P15 | Optimal tilt angle review (Ruiz-Arias) | 2020 | 300+ | HIGH |
| P16 | Shading losses review (Picault) | 2010 | 800+ | MED |

### Financial & Economic Models
| # | Paper | Year | Citations | Priority |
|---|-------|------|-----------|----------|
| P19 | LCOE methodology review | 2021 | 300+ | HIGH |
| P17 | Economics of residential PV+storage (LBNL) | 2019 | 200+ | HIGH |
| P29 | Net metering vs feed-in tariffs (Darghouth) | 2014 | 500+ | MED |

### Standards & Validation
| # | Paper | Year | Citations | Priority |
|---|-------|------|-----------|----------|
| P12 | IEC 61724-1 Monitoring Standard | 2021 | -- | MUST |
| P22 | NREL System Advisor Model (SAM) | 2024 | -- | HIGH |
| P11 | Performance ratio revisited | 2019 | -- | MED |
| P26 | PV yield correction algorithm | 2018 | 100+ | MED |

### Open-Source Tools & Methods
| # | Paper | Year | Citations | Priority |
|---|-------|------|-----------|----------|
| P05 | pvlib Python (Holmgren) | 2018 | 500+ | MUST |
| P20 | PV power forecasting review | 2016 | 600+ | MED |
| P24 | Soft computing PV forecasting | 2016 | 500+ | LOW |

### Grid Integration
| # | Paper | Year | Citations | Priority |
|---|-------|------|-----------|----------|
| P23 | Grid export limits & voltage regulation | 2012 | 300+ | MED |
| P08 | Inverter clipping review | 2020 | -- | HIGH |

### Inverter Clipping (Semantic Scholar)
| # | Paper | Year | Citations | Priority |
|---|-------|------|-----------|----------|
| P31 | DC/AC ratio, azimuth & slope impact on clipping (Torres-Ferrer) | 2023 | 24 | HIGH |
| P32 | PV module degradation from inverter clipping (Dhoble) | 2022 | 2 | MED |

### Sizing (Semantic Scholar additions)
| # | Paper | Year | Citations | Priority |
|---|-------|------|-----------|----------|
| P33 | Multi-objective PV+battery sizing (2025) | 2025 | 2 | MED |
| P34 | PV sizing from nameplate specs (Shakeel) | 2015 | 3 | MED |

## Reading order recommendation

For someone new to PV simulation building the calculator engine:

1. **P01** Luthander — understand the key metrics (SCR, SSR)
2. **P05** pvlib — understand the standard simulation pipeline
3. **P06** Sandia model — DC power from irradiance + temperature
4. **P04** PVGIS database — where irradiance data comes from
5. **P14** Mattei — temperature derating specifically
6. **P07** Burger — inverter sizing and clipping (our 800W cap)
7. **P30** Quoilin — battery dispatch strategies
8. **P12** IEC 61724 — standard metrics to output
9. **P19** LCOE — financial model
10. **P15** Tilt/azimuth — orientation optimization

## Contribution guidelines

When adding new papers:
1. Create `P<next-id>_<short-name>.md` using the template below
2. Add entries to the relevant topic table(s) in this README
3. Mark priority based on relevance to current engine features

### Template for new paper entries

```markdown
# [Title]

## Citation
- **Authors**: ...
- **Year**: ...
- **Journal**: ...
- **DOI**: ...
- **URL**: ...

- **Priority**: MUST / HIGH / MED / LOW
- **Topic**: ...

## Relevance
[Why this paper matters for the PV calculator]

## Key takeaways
- [Algorithm / formula / insight 1]
- [Algorithm / formula / insight 2]

## Applicable engine components
- [e.g., battery dispatch, irradiance model, inverter cap]

## Status
- [ ] PDF downloaded
- [ ] Abstract read
- [ ] Key formulas extracted
- [ ] Implemented in engine
```
