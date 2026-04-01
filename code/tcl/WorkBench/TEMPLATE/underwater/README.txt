Underwater Workbench Template

Uso consigliato con workbench.tcl

Launcher:
- Adatta il profilo Underwater per usare Python se vuoi test rapido
- launcher: python3
- target: uw_detector.py
- Config path: configs/uw_passive.json
- Case name: uw_passive
- Output root: runs
- Workdir: scripts

Validation:
- Metrics: runs/uw_passive_20260401_101500/metrics.csv
- Baseline: baselines/uw_passive_baseline.csv
