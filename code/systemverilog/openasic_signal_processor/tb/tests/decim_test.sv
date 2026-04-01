`timescale 1ns/1ps

module decim_test;

    logic clk;
    logic rst_n;
    logic [3:0] decim_factor;
    logic signed [15:0] sample_in;
    logic sample_valid;
    logic signed [15:0] sample_out;
    logic sample_out_valid;

    int seen;
    int expected [0:2];

    decimator dut (
        .clk(clk),
        .rst_n(rst_n),
        .decim_factor(decim_factor),
        .sample_in(sample_in),
        .sample_valid(sample_valid),
        .sample_out(sample_out),
        .sample_out_valid(sample_out_valid)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        if (sample_out_valid) begin
            if (sample_out !== expected[seen])
                $fatal(1, "DECIM mismatch idx=%0d exp=%0d got=%0d", seen, expected[seen], sample_out);
            seen++;
        end
    end

    initial begin
        rst_n = 0;
        sample_valid = 0;
        sample_in = 0;
        decim_factor = 4;
        seen = 0;
        expected[0] = 3;
        expected[1] = 7;
        expected[2] = 11;
        repeat (4) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        sample_valid = 1;
        for (int i = 0; i < 12; i++) begin
            sample_in = i;
            @(posedge clk);
        end
        sample_valid = 0;
        repeat (10) @(posedge clk);

        if (seen != 3)
            $fatal(1, "DECIM expected 3 outputs got %0d", seen);
        $display("DECIM TEST PASS");
        $finish;
    end
endmodule
