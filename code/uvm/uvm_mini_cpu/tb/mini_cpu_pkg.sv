package mini_cpu_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  typedef enum logic [3:0] {
    OP_NOP   = 4'h0,
    OP_LOADI = 4'h1,
    OP_ADD   = 4'h2,
    OP_SUB   = 4'h3,
    OP_AND   = 4'h4,
    OP_OR    = 4'h5,
    OP_XOR   = 4'h6,
    OP_MOV   = 4'h7,
    OP_JMP   = 4'h8,
    OP_JZ    = 4'h9,
    OP_HALT  = 4'hA
  } opcode_e;


  class mini_cpu_state_item extends uvm_sequence_item;
    rand bit [7:0] pc;
    rand bit [3:0] opcode;
    rand bit [7:0] r0, r1, r2, r3;
    rand bit       zero_flag;
    rand bit       halted;

    `uvm_object_utils(mini_cpu_state_item)

    function new(string name="mini_cpu_state_item");
      super.new(name);
    endfunction
  endclass


  class mini_cpu_program;
    rand bit [15:0] imem[256];
    `uvm_object_utils(mini_cpu_program)

    function new(string name="mini_cpu_program");
      super.new(name);
      foreach (imem[i]) imem[i] = 16'h0000;
    endfunction
  endclass


  class mini_cpu_monitor extends uvm_component;
    `uvm_component_utils(mini_cpu_monitor)

    virtual mini_cpu_if vif;
    uvm_analysis_port #(mini_cpu_state_item) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual mini_cpu_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "virtual interface non trovata")
    endfunction

    task run_phase(uvm_phase phase);
      mini_cpu_state_item item;
      forever begin
        @(posedge vif.clk);
        #1;
        item = mini_cpu_state_item::type_id::create("item");
        item.pc        = vif.pc;
        item.opcode    = vif.opcode;
        item.r0        = vif.r0;
        item.r1        = vif.r1;
        item.r2        = vif.r2;
        item.r3        = vif.r3;
        item.zero_flag = vif.zero_flag;
        item.halted    = vif.halted;
        ap.write(item);
      end
    endtask
  endclass


  class mini_cpu_scoreboard extends uvm_component;
    `uvm_component_utils(mini_cpu_scoreboard)

    uvm_analysis_imp #(mini_cpu_state_item, mini_cpu_scoreboard) imp;

    bit [15:0] program[256];

    bit [7:0] exp_pc;
    bit [7:0] exp_r[4];
    bit       exp_zero;
    bit       exp_halted;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      imp = new("imp", this);
    endfunction

    function void load_program(bit [15:0] p[256]);
      for (int i = 0; i < 256; i++) program[i] = p[i];
    endfunction

    function void reset_model();
      exp_pc     = 8'h00;
      exp_zero   = 1'b0;
      exp_halted = 1'b0;
      foreach (exp_r[i]) exp_r[i] = 8'h00;
    endfunction

    function void write(mini_cpu_state_item t);
      bit [15:0] instr;
      bit [3:0]  opcode;
      bit [1:0]  rd, rs;
      bit [7:0]  imm8;
      bit [7:0]  alu_result;

      if (!exp_halted) begin
        instr  = program[exp_pc];
        opcode = instr[15:12];
        rd     = instr[11:10];
        rs     = instr[9:8];
        imm8   = instr[7:0];
        alu_result = 8'h00;

        case (opcode)
          OP_NOP: begin
            exp_pc = exp_pc + 1;
          end
          OP_LOADI: begin
            exp_r[rd] = imm8;
            exp_zero  = (imm8 == 8'h00);
            exp_pc    = exp_pc + 1;
          end
          OP_ADD: begin
            alu_result = exp_r[rd] + exp_r[rs];
            exp_r[rd]  = alu_result;
            exp_zero   = (alu_result == 8'h00);
            exp_pc     = exp_pc + 1;
          end
          OP_SUB: begin
            alu_result = exp_r[rd] - exp_r[rs];
            exp_r[rd]  = alu_result;
            exp_zero   = (alu_result == 8'h00);
            exp_pc     = exp_pc + 1;
          end
          OP_AND: begin
            alu_result = exp_r[rd] & exp_r[rs];
            exp_r[rd]  = alu_result;
            exp_zero   = (alu_result == 8'h00);
            exp_pc     = exp_pc + 1;
          end
          OP_OR: begin
            alu_result = exp_r[rd] | exp_r[rs];
            exp_r[rd]  = alu_result;
            exp_zero   = (alu_result == 8'h00);
            exp_pc     = exp_pc + 1;
          end
          OP_XOR: begin
            alu_result = exp_r[rd] ^ exp_r[rs];
            exp_r[rd]  = alu_result;
            exp_zero   = (alu_result == 8'h00);
            exp_pc     = exp_pc + 1;
          end
          OP_MOV: begin
            exp_r[rd] = exp_r[rs];
            exp_zero  = (exp_r[rs] == 8'h00);
            exp_pc    = exp_pc + 1;
          end
          OP_JMP: begin
            exp_pc = imm8;
          end
          OP_JZ: begin
            if (exp_zero) exp_pc = imm8;
            else          exp_pc = exp_pc + 1;
          end
          OP_HALT: begin
            exp_halted = 1'b1;
          end
          default: begin
            exp_pc = exp_pc + 1;
          end
        endcase
      end

      if (t.pc !== exp_pc)
        `uvm_error("SB", $sformatf("PC mismatch exp=%0d got=%0d", exp_pc, t.pc))
      if (t.r0 !== exp_r[0])
        `uvm_error("SB", $sformatf("R0 mismatch exp=%0d got=%0d", exp_r[0], t.r0))
      if (t.r1 !== exp_r[1])
        `uvm_error("SB", $sformatf("R1 mismatch exp=%0d got=%0d", exp_r[1], t.r1))
      if (t.r2 !== exp_r[2])
        `uvm_error("SB", $sformatf("R2 mismatch exp=%0d got=%0d", exp_r[2], t.r2))
      if (t.r3 !== exp_r[3])
        `uvm_error("SB", $sformatf("R3 mismatch exp=%0d got=%0d", exp_r[3], t.r3))
      if (t.zero_flag !== exp_zero)
        `uvm_error("SB", $sformatf("ZERO mismatch exp=%0d got=%0d", exp_zero, t.zero_flag))
      if (t.halted !== exp_halted)
        `uvm_error("SB", $sformatf("HALTED mismatch exp=%0d got=%0d", exp_halted, t.halted))
    endfunction
  endclass


  class mini_cpu_env extends uvm_env;
    `uvm_component_utils(mini_cpu_env)

    mini_cpu_monitor    mon;
    mini_cpu_scoreboard sb;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      mon = mini_cpu_monitor   ::type_id::create("mon", this);
      sb  = mini_cpu_scoreboard::type_id::create("sb",  this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      mon.ap.connect(sb.imp);
    endfunction
  endclass

endpackage