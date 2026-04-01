`timescale 1ns/1ps

module fir_impulse_test;

    localparam int DATA_W = 16;
    localparam int N_SAMPLES = 16;

    logic clk;
    logic rst_n;

    logic signed [DATA_W-1:0] sample_in;
    logic                     sample_valid;
    logic signed [DATA_W-1:0] sample_out;
    logic                     sample_out_valid;

    int signed expected [0:N_SAMPLES-1];
    int out_idx;

    fir8_core dut (
        .clk             (clk),
        .rst_n           (rst_n),
        .sample_valid    (sample_valid),
        .sample_in       (sample_in),
        .sample_out      (sample_out),
        .sample_out_valid(sample_out_valid)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        expected[0] = -8;
        expected[1] =  0;
        expected[2] = 40;
        expected[3] = 96;
        expected[4] = 96;
        expected[5] = 40;
        expected[6] =  0;
        expected[7] = -8;
        for (int i = 8; i < N_SAMPLES; i++) begin
            expected[i] = 0;
        end
    end

    initial begin
        rst_n        = 1'b0;
        sample_in    = '0;
        sample_valid = 1'b0;
        out_idx      = 0;

        repeat (4) @(posedge clk);
        rst_n <= 1'b1;

        // Apply impulse = 256 so output equals coefficients directly after >>8.
        @(posedge clk);
        sample_valid <= 1'b1;
        sample_in    <= 16'sd256;

        @(posedge clk);
        sample_in    <= 16'sd0;

        repeat (14) begin
            @(posedge clk);
            sample_in <= 16'sd0;
        end

        @(posedge clk);
        sample_valid <= 1'b0;

        repeat (4) @(posedge clk);
        $display("FIR impulse test PASSED");
        $finish;
    end

    always @(posedge clk) begin
        if (sample_out_valid) begin
            if (sample_out !== expected[out_idx]) begin
                $error("Mismatch at sample %0d: got=%0d exp=%0d",
                       out_idx, sample_out, expected[out_idx]);
                $fatal;
            end
            out_idx <= out_idx + 1;
        end
    end

endmodule
