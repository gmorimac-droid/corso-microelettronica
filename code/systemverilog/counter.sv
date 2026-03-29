module counter (
  input  logic       clk,
  input  logic       reset,
  output logic [3:0] q
);

  always_ff @(posedge clk or posedge reset) begin
    if (reset)
      q <= 4'd0;
    else
      q <= q + 1'b1;
  end

endmodule
