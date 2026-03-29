module counter #(
  parameter N = 4
)(
  input  logic clk,
  input  logic reset,
  input  logic enable,
  output logic [N-1:0] q
);

  always_ff @(posedge clk or posedge reset) begin
    if (reset)
      q <= '0;
    else if (enable)
      q <= q + 1;
  end

endmodule
