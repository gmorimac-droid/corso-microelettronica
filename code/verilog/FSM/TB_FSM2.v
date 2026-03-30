`timescale 1ns/1ps

module tb_traffic_light_fsm_timed;

    localparam integer GREEN_TIME  = 4;
    localparam integer YELLOW_TIME = 2;

    reg clk;
    reg rst_n;

    wire roadA_red;
    wire roadA_yellow;
    wire roadA_green;

    wire roadB_red;
    wire roadB_yellow;
    wire roadB_green;

    integer errors;

    traffic_light_fsm_timed #(
        .GREEN_TIME(GREEN_TIME),
        .YELLOW_TIME(YELLOW_TIME)
    ) dut (
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
        errors = 0;
        rst_n  = 1'b0;

        #12;
        rst_n = 1'b1;

        #250;

        if (errors == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED - errors = %0d", errors);

        $finish;
    end

    // Basic checks
    always @(posedge clk) begin
        if (rst_n) begin
            // Mai due verdi contemporaneamente
            if (roadA_green && roadB_green) begin
                $display("[%0t] ERROR: both roads green", $time);
                errors = errors + 1;
            end

            // Road A: una sola luce attiva
            if ((roadA_red && roadA_yellow) ||
                (roadA_red && roadA_green)  ||
                (roadA_yellow && roadA_green)) begin
                $display("[%0t] ERROR: invalid Road A light combination", $time);
                errors = errors + 1;
            end

            // Road B: una sola luce attiva
            if ((roadB_red && roadB_yellow) ||
                (roadB_red && roadB_green)  ||
                (roadB_yellow && roadB_green)) begin
                $display("[%0t] ERROR: invalid Road B light combination", $time);
                errors = errors + 1;
            end
        end
    end

    initial begin
        $display("time  A[R Y G]  B[R Y G]");
        $monitor("%0t   %b %b %b    %b %b %b",
                 $time,
                 roadA_red, roadA_yellow, roadA_green,
                 roadB_red, roadB_yellow, roadB_green);
    end

endmodule