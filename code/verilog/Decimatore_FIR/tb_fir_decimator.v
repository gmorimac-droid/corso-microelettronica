`timescale 1ns/1ps

module tb_fir_decimator;

    reg clk = 0;
    reg rst = 1;
    reg din_valid = 0;
    reg signed [15:0] din = 0;

    wire dout_valid;
    wire signed [15:0] dout;

    fir_decimator #(
        .DECIM_FACTOR(4)
    ) dut (
        .clk(clk),
        .rst(rst),
        .din_valid(din_valid),
        .din(din),
        .dout_valid(dout_valid),
        .dout(dout)
    );

    always #5 clk = ~clk;

    integer k;

    initial begin
        #20;
        rst = 0;
        din_valid = 1;

        for (k = 0; k < 32; k = k + 1) begin
            din = k;
            #10;
        end

        din_valid = 0;
        #50;
        $finish;
    end

endmodule