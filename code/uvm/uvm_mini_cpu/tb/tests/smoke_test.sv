import uvm_pkg::*;
`include "uvm_macros.svh"
import mini_cpu_pkg::*;
`include "base_test.sv"

class smoke_test extends base_test;
  `uvm_component_utils(smoke_test)

  function new(string name="smoke_test", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    bit [15:0] prog[256];

    phase.raise_objection(this);

    foreach (prog[i]) prog[i] = 16'h0000;

    prog[0] = {OP_LOADI, 2'b00, 2'b00, 8'h05};
    prog[1] = {OP_LOADI, 2'b01, 2'b00, 8'h03};
    prog[2] = {OP_ADD,   2'b00, 2'b01, 8'h00};
    prog[3] = {OP_MOV,   2'b10, 2'b00, 8'h00};
    prog[4] = {OP_SUB,   2'b10, 2'b01, 8'h00};
    prog[5] = {OP_JZ,    2'b00, 2'b00, 8'h08};
    prog[6] = {OP_LOADI, 2'b11, 2'b00, 8'h00};
    prog[7] = {OP_HALT,  2'b00, 2'b00, 8'h00};

    load_program_to_dut(prog);
    env.sb.reset_model();
    apply_reset();

    repeat (20) @(posedge vif.clk);

    phase.drop_objection(this);
  endtask
endclass