#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/netlist"
mkdir -p "$OUT_DIR"

yosys -q -p "
  read_verilog -sv \
    $ROOT/rtl/defines.svh \
    $ROOT/rtl/spi_slave.sv \
    $ROOT/rtl/reg_bank.sv \
    $ROOT/rtl/control_fsm.sv \
    $ROOT/rtl/fifo_sync.sv \
    $ROOT/rtl/fir8_core.sv \
    $ROOT/rtl/decimator.sv \
    $ROOT/rtl/output_stage.sv \
    $ROOT/rtl/status_flags.sv \
    $ROOT/rtl/top.sv;
  hierarchy -check -top top;
  proc; opt; fsm; opt; memory; opt;
  stat;
  write_verilog $OUT_DIR/top_synth.v
"

echo "Yosys synthesis done: $OUT_DIR/top_synth.v"
