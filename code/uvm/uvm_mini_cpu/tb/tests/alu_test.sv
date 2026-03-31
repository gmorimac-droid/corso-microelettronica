import uvm_pkg::*;
`include "uvm_macros.svh"
import mini_cpu_pkg::*;
`include "base_test.sv"

class alu_test extends base_test;
  `uvm_component_utils(alu_test)

  function new(string name="alu_test", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    bit [15:0] prog[256];

    phase.raise_objection(this);

    foreach (prog[i]) prog[i] = 16'h0000;

    prog[0] = {OP_LOADI, 2'b00, 2'b00, 8'hF0}; // R0=F0
    prog[1] = {OP_LOADI, 2'b01, 2'b00, 8'h0F}; // R1=0F
    prog[2] = {OP_AND,   2'b00, 2'b01, 8'h00}; // R0=00
    prog[3] = {OP_OR,    2'b10, 2'b01, 8'h00}; // R2=0F
    prog[4] = {OP_XOR,   2'b10, 2'b01, 8'h00}; // R2=00
    prog[5] = {OP_HALT,  2'b00, 2'b00, 8'h00};

    load_program_to_dut(prog);
    env.sb.reset_model();
    apply_reset();

    repeat (20) @(posedge vif.clk);

    phase.drop_objection(this);
  endtask
endclass