module mini_cpu_bind(mini_cpu_if vif);

  bind mini_cpu mini_cpu_probe probe_i (
    .clk       (clk),
    .rst_n     (rst_n),
    .pc        (pc),
    .opcode    (opcode),
    .r0        (regfile[0]),
    .r1        (regfile[1]),
    .r2        (regfile[2]),
    .r3        (regfile[3]),
    .zero_flag (zero_flag),
    .halted    (halted),
    .vif       (vif)
  );

endmodule


module mini_cpu_probe(
  input  logic       clk,
  input  logic       rst_n,
  input  logic [7:0] pc,
  input  logic [3:0] opcode,
  input  logic [7:0] r0,
  input  logic [7:0] r1,
  input  logic [7:0] r2,
  input  logic [7:0] r3,
  input  logic       zero_flag,
  input  logic       halted,
  mini_cpu_if        vif
);

  always_comb begin
    vif.rst_n      = rst_n;
    vif.pc         = pc;
    vif.opcode     = opcode;
    vif.r0         = r0;
    vif.r1         = r1;
    vif.r2         = r2;
    vif.r3         = r3;
    vif.zero_flag  = zero_flag;
    vif.halted     = halted;
  end

endmodule