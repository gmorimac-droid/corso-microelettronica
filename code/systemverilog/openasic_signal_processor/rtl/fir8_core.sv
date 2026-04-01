`include "defines.svh"

module fir8_core #(
    parameter int DATA_W  = `DATA_W,
    parameter int COEFF_W = `COEFF_W,
    parameter int ACC_W   = `ACC_W,
    parameter int NTAPS   = `FIR_TAPS
)(
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic                          sample_valid,
    input  logic signed [DATA_W-1:0]      sample_in,
    output logic signed [DATA_W-1:0]      sample_out,
    output logic                          sample_out_valid
);

    logic signed [DATA_W-1:0] x [0:NTAPS-1];
    logic signed [COEFF_W-1:0] h [0:NTAPS-1];

    logic signed [ACC_W-1:0] acc_comb;
    integer i;

    initial begin
        h[0] = -16'sd8;
        h[1] =  16'sd0;
        h[2] =  16'sd40;
        h[3] =  16'sd96;
        h[4] =  16'sd96;
        h[5] =  16'sd40;
        h[6] =  16'sd0;
        h[7] = -16'sd8;
    end

    always_comb begin
        acc_comb = '0;
        // Include current input sample explicitly so the impulse response
        // is aligned with the reference model.
        acc_comb += sample_in * h[0];
        for (int k = 1; k < NTAPS; k++) begin
            acc_comb += x[k-1] * h[k];
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NTAPS; i++) begin
                x[i] <= '0;
            end
            sample_out       <= '0;
            sample_out_valid <= 1'b0;
        end else begin
            sample_out_valid <= 1'b0;

            if (sample_valid) begin
                for (i = NTAPS-1; i > 0; i--) begin
                    x[i] <= x[i-1];
                end
                x[0] <= sample_in;

                sample_out       <= acc_comb >>> 8;
                sample_out_valid <= 1'b1;
            end
        end
    end

endmodule
