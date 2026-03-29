module tb_counter;

  logic clk;
  logic reset;
  logic enable;
  logic [3:0] q;

  // DUT
  counter #(4) dut (
    .clk(clk),
    .reset(reset),
    .enable(enable),
    .q(q)
  );

  // clock
  always #5 clk = ~clk;

  // stimulus
  initial begin
    clk = 0;
    reset = 1;
    enable = 0;

    #10;
    reset = 0;
    enable = 1;

    #100;

    enable = 0;
    #20;

    enable = 1;
    #50;

    $finish;
  end

  // monitor
  initial begin
    $monitor("time=%0t reset=%0b enable=%0b q=%0d",
              $time, reset, enable, q);
  end

endmodule

always @(posedge clk) begin
  if (!reset && enable) begin
    assert (q >= 0)
      else $error("Errore contatore!");
  end
end
