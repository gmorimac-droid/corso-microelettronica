HDL Workbench Template

Uso consigliato con workbench_full_integrated_v1.tcl

Launcher:
- Profile: HDL Regression Runner
- Config path: configs/hdl_smoke.json
- Case name: hdl_smoke
- Output root: runs
- Workdir: scripts

Validation:
- Metrics: runs/hdl_smoke_20260401_101500/metrics.csv
- Baseline: baselines/hdl_smoke_baseline.csv
