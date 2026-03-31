import uvm_pkg::*;
`include "uvm_macros.svh"
import mini_cpu_pkg::*;

class base_test extends uvm_test;
  `uvm_component_utils(base_test)

  mini_cpu_env env;
  virtual mini_cpu_if vif;

  function new(string name="base_test", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = mini_cpu_env::type_id::create("env", this);

    if (!uvm_config_db#(virtual mini_cpu_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "virtual interface non trovata")
  endfunction

  virtual task load_program_to_dut(bit [15:0] prog[256]);
    for (int i = 0; i < 256; i++) begin
      $root.tb_top.dut.imem[i] = prog[i];
    end
    env.sb.load_program(prog);
  endtask

  task apply_reset();
    vif.rst_n <= 1'b0;
    repeat (3) @(posedge vif.clk);
    vif.rst_n <= 1'b1;
  endtask
endclass