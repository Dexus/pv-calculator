# An Approach to Implement Photovoltaic Self-Consumption and Ramp-Rate Control Algorithm with a Vanadium Redox Flow Battery Day-to-Day Forecast Charging

## Citation
- **Authors**: Ana Foles, Luis Fialho, Manuel Collares-Pereira, Pedro Horta
- **Year**: 2022
- **Journal**: Sustainable Energy, Grids and Networks, 100626
- **DOI**: `10.1016/j.segan.2022.100626`
- **URL**: https://doi.org/10.1016/j.segan.2022.100626
- **arXiv**: https://arxiv.org/abs/2012.11955
- **PDF**: https://arxiv.org/pdf/2012.11955v4

- **Priority**: MED
- **Topic**: self-consumption, battery-dispatch, ramp-rate-control

## Relevance
Demonstrates three energy management strategies (SCM, SCM+RR, SCM+RR+WF) for PV+battery (VRFB) systems. Quantifies self-consumption ratio (SCR) and grid-relief factor (GRF). Relevant to our battery dispatch layer and SOC management — shows how day-ahead weather forecasting improves dispatch outcomes.

## Key takeaways
- Three EMSs compared: self-consumption maximization (SCM); SCM + ramp-rate control; SCM + ramp-rate + weather forecast
- SCM+RR+WF achieved SCR = 59% and GRF = 61% over the study week in wintertime
- 100% of violating ramp events eliminated by the weather-forecast-aware dispatch
- SOC management control is essential for VRFB systems — direct relevance to `BatteryConfig.initialSocKwh` and SOC carry-over
- Day-ahead forecast charging pre-fills battery to improve ramp smoothing

## Applicable engine components
- `PvSimulator` battery dispatch (Step 4–5 in dispatch order)
- `BatteryConfig` SOC carry-over and pre-run
- self-consumption ratio (SCR) and self-sufficiency ratio (SSR) outputs
- `gridExportLimitKw` / ramp-rate limiting concept

## Abstract
The variability of the solar resource is mainly caused by cloud passing, causing rapid power fluctuations on PV system output. This work uses a vanadium redox flow battery (VRFB) to control PV power output, maintaining ramp rates within non-violation limits. Three EMSs are simulated and results show SCM+RR+WF is robust for PV+VRFB management, successfully controlling 100% of violating power ramps while achieving SCR=59% and GRF=61%.

## Status
- [ ] PDF downloaded
- [ ] Abstract read
- [ ] Key formulas extracted
- [ ] Implemented in engine
