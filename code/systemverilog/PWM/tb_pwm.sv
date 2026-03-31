`timescale 1ns/1ps

module tb_pwm_programmable;

    logic clk = 0;
    logic rst = 1;
    logic en  = 0;
    logic [15:0] period_in = 0;
    logic [15:0] duty_in   = 0;
    logic pwm_out;

    pwm_programmable #(
        .WIDTH(16)
    ) dut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .period_in(period_in),
        .duty_in(duty_in),
        .pwm_out(pwm_out)
    );

    always #5 clk = ~clk; // 100 MHz

    initial begin
        #20;
        rst       = 0;
        en        = 1;
        period_in = 16'd10;
        duty_in   = 16'd3;

        #200;
        duty_in   = 16'd7;

        #200;
        duty_in   = 16'd10;

        #100;
        duty_in   = 16'd0;

        #100;
        en        = 0;

        #50;
        $finish;
    end

endmodule