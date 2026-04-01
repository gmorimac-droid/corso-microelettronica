Satellite Workbench Template

Uso consigliato con workbench_full_integrated_v1.tcl

Launcher:
- Profile: Satellite Matlab Visibility (oppure adatta il profilo per Python)
- Config path: configs/sat_visibility.json
- Case name: sat_visibility
- Output root: runs
- Workdir: scripts

Validation:
- Metrics: runs/sat_visibility_20260401_101500/metrics.csv
- Baseline: baselines/sat_visibility_baseline.csv
