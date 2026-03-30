`timescale 1ns/1ps

module tb_traffic_light_fsm;

    reg clk;
    reg rst_n;

    wire roadA_red;
    wire roadA_yellow;
    wire roadA_green;
    wire roadB_red;
    wire roadB_yellow;
    wire roadB_green;

    traffic_light_fsm dut (
        .clk(clk),
        .rst_n(rst_n),
        .roadA_red(roadA_red),
        .roadA_yellow(roadA_yellow),
        .roadA_green(roadA_green),
        .roadB_red(roadB_red),
        .roadB_yellow(roadB_yellow),
        .roadB_green(roadB_green)
    );

    // Clock generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Stimulus
    initial begin
        rst_n = 1'b0;
        #12;
        rst_n = 1'b1;

        #80;
        $finish;
    end

    // Monitor
    initial begin
        $display("Time\tState Outputs");
        $monitor("%0t\tA[R=%b Y=%b G=%b] B[R=%b Y=%b G=%b]",
                 $time,
                 roadA_red, roadA_yellow, roadA_green,
                 roadB_red, roadB_yellow, roadB_green);
    end

endmodule