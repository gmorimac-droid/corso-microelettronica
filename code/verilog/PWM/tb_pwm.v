`timescale 1ns/1ps

module tb_pwm_programmable;

    reg clk = 0;
    reg rst = 1;
    reg en  = 0;
    reg [15:0] period = 0;
    reg [15:0] duty   = 0;
    wire pwm_out;

    pwm_programmable_buffered #(
        .WIDTH(16)
    ) dut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .period(period),
        .duty(duty),
        .pwm_out(pwm_out)
    );

    always #5 clk = ~clk;  // 100 MHz

    initial begin
        #20;
        rst    = 0;
        en     = 1;
        period = 16'd10;
        duty   = 16'd3;   // 30%

        #200;

        duty   = 16'd7;   // 70%

        #200;

        duty   = 16'd10;  // 100%

        #100;

        duty   = 16'd0;   // 0%

        #100;

        en     = 0;

        #50;
        $finish;
    end

endmodule