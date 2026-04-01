import argparse, os, json, csv, time

parser = argparse.ArgumentParser()
parser.add_argument('--config', required=True)
parser.add_argument('--output', required=True)
args = parser.parse_args()

os.makedirs(args.output, exist_ok=True)

with open(args.config, 'r') as f:
    cfg = json.load(f)

log_path = os.path.join(args.output, 'run.log')
metrics_path = os.path.join(args.output, 'metrics.csv')
coverage_path = os.path.join(args.output, 'coverage.xml')
wave_path = os.path.join(args.output, 'waveform.vcd')

with open(log_path, 'w') as log:
    log.write('INFO compile started\n')
    time.sleep(0.2)
    log.write('INFO elaborate completed\n')
    time.sleep(0.2)
    log.write('WARN waveform dump enabled\n')
    time.sleep(0.2)
    log.write('ERROR checker reset_done mismatch at cycle 84\n')
    time.sleep(0.2)
    log.write('INFO coverage exported\n')

with open(metrics_path, 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['metric','value','min','max'])
    w.writerow(['tests_passed',12,10,20])
    w.writerow(['tests_failed',1,0,0])
    w.writerow(['coverage',0.89,0.85,1.0])
    w.writerow(['latency_cycles',19,0,25])

with open(coverage_path, 'w') as f:
    f.write("<coverage><summary line='0.89' toggle='0.84' fsm='0.95'/></coverage>")

with open(wave_path, 'w') as f:
    f.write("$date\n  Example\n$end\n")

print('INFO hdl smoke run completed')
