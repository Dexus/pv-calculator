# Knowledge Distillation for Efficient Transformer-Based Reinforcement Learning in Hardware-Constrained Energy Management Systems

## Citation
- **Authors**: Pascal Henrich, Jonas Sievers, Maximilian Beichter, Thomas Blank, Ralf Mikut, Veit Hagenmeyer
- **Year**: 2026
- **Journal**: arXiv preprint (cs.LG)
- **DOI**: —
- **URL**: https://arxiv.org/abs/2603.26249
- **PDF**: https://arxiv.org/pdf/2603.26249v1

- **Priority**: LOW
- **Topic**: battery-dispatch, machine-learning, energy-management

## Relevance
Uses Decision Transformer (reinforcement learning) for residential battery dispatch to maximise PV self-consumption. Knowledge distillation compresses models for embedded/residential controllers. Relevant as a reference for ML-based dispatch strategies and the Ausgrid dataset for benchmarking.

## Key takeaways
- Decision Transformer learns battery dispatch policies from historical data (offline RL)
- Ausgrid dataset used for multi-building heterogeneous training
- Knowledge distillation reduces parameters by up to 96%, memory by 90%, inference time by 63% with minimal control performance loss
- Comparable cost improvements observed even distilling into same-capacity student models
- Goal: PV self-consumption maximization + electricity cost reduction on resource-limited hardware

## Applicable engine components
- Battery dispatch strategy (alternative to rule-based dispatch in `PvSimulator`)
- Self-consumption metric validation
- Reference dataset (Ausgrid) for future engine benchmark tests

## Abstract
Transformer-based reinforcement learning for sequential residential energy management. The Decision Transformer learns effective battery dispatch policies from historical data, increasing PV self-consumption and reducing electricity costs. Knowledge distillation transfers high-capacity teacher policies to compact student models suitable for embedded deployment. Using the Ausgrid dataset, distillation reduces parameter count by up to 96%, inference memory by 90%, and inference time by 63%, largely preserving control performance.

## Status
- [ ] PDF downloaded
- [ ] Abstract read
- [ ] Key formulas extracted
- [ ] Implemented in engine
