`timescale 1ns/1ps
import uvm_pkg::*;
`include "uvm_macros.svh"

`include "counter_item.sv"
`include "counter_mon_item.sv"
`include "counter_sequence.sv"
`include "counter_sequencer.sv"
`include "counter_driver.sv"
`include "counter_monitor.sv"
`include "counter_scoreboard.sv"
`include "counter_agent.sv"
`include "counter_env.sv"
`include "counter_test.sv"

module tb_top;

  logic clk = 0;
  always #5 clk = ~clk;

  counter_if cif(clk);

  counter dut (
    .clk   (clk),
    .reset (cif.reset),
    .enable(cif.enable),
    .q     (cif.q)
  );

  initial begin
    uvm_config_db#(virtual counter_if)::set(null, "*", "vif", cif);
    run_test("counter_test");
  end

endmodule
