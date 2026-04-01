`include "defines.svh"

module output_stage #(
    parameter int DATA_W = `DATA_W
)(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     soft_reset,
    input  logic signed [DATA_W-1:0] sample_in,
    input  logic                     sample_valid,
    output logic signed [DATA_W-1:0] data_out,
    output logic                     data_valid_pulse
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out         <= '0;
            data_valid_pulse <= 1'b0;
        end else begin
            data_valid_pulse <= 1'b0;
            if (soft_reset) begin
                data_out <= '0;
            end else if (sample_valid) begin
                data_out         <= sample_in;
                data_valid_pulse <= 1'b1;
            end
        end
    end

endmodule
