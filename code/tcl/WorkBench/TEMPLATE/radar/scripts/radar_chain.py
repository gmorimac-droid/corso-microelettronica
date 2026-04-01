import argparse, os, time
parser = argparse.ArgumentParser()
parser.add_argument('--config', required=True)
parser.add_argument('--output', required=True)
args = parser.parse_args()
os.makedirs(args.output, exist_ok=True)
with open(os.path.join(args.output, "run.log"), "w") as log:
    log.write("INFO start\n")
    time.sleep(1)
    log.write("WARN example\n")
with open(os.path.join(args.output, "metrics.csv"), "w") as m:
    m.write("metric,value,min,max\nrmse,1.2,0,2\n")
print("INFO done")
