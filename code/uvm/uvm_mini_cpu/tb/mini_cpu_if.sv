interface mini_cpu_if(input logic clk);

  logic rst_n;

  logic [7:0] pc;
  logic [3:0] opcode;
  logic [7:0] r0, r1, r2, r3;
  logic       zero_flag;
  logic       halted;

endinterface