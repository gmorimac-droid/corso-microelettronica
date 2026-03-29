`timescale 1ns/1ps

module tb_counter;

  reg clk;
  reg reset;
  reg enable;
  wire [3:0] q;

  counter dut (
    .clk(clk),
    .reset(reset),
    .enable(enable),
    .q(q)
  );

  // Clock generator: periodo 10 ns
  always #5 clk = ~clk;

  initial begin
    clk = 0;
    reset = 1;
    enable = 0;

    #12;
    reset = 0;
    enable = 1;

    #80;
    enable = 0;

    #20;
    enable = 1;

    #40;
    reset = 1;

    #10;
    reset = 0;

    #30;
    $finish;
  end

  initial begin
    $monitor("time=%0t reset=%0b enable=%0b q=%0d",
             $time, reset, enable, q);
  end

endmodule
