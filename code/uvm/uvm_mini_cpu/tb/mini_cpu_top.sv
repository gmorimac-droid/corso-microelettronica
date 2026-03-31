`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import mini_cpu_pkg::*;

module tb_top;

  logic clk;
  mini_cpu_if vif(clk);

  mini_cpu dut (
    .clk   (clk),
    .rst_n (vif.rst_n)
  );

  mini_cpu_bind bind_i(vif);

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    uvm_config_db#(virtual mini_cpu_if)::set(null, "*", "vif", vif);
    run_test();
  end

endmodule