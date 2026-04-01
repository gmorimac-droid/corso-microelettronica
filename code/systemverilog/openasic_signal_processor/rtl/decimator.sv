`include "defines.svh"

module decimator #(
    parameter int DATA_W  = `DATA_W,
    parameter int DECIM_W = `DECIM_W
)(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic [DECIM_W-1:0]       decim_factor,
    input  logic signed [DATA_W-1:0] sample_in,
    input  logic                     sample_valid,
    output logic signed [DATA_W-1:0] sample_out,
    output logic                     sample_out_valid
);

    logic [DECIM_W-1:0] sample_count;
    logic [DECIM_W-1:0] decim_factor_safe;

    always_comb begin
        if (decim_factor == '0)
            decim_factor_safe = {{(DECIM_W-1){1'b0}}, 1'b1};
        else
            decim_factor_safe = decim_factor;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_count      <= '0;
            sample_out        <= '0;
            sample_out_valid  <= 1'b0;
        end else begin
            sample_out_valid <= 1'b0;

            if (sample_valid) begin
                if (sample_count == decim_factor_safe - 1'b1) begin
                    sample_out       <= sample_in;
                    sample_out_valid <= 1'b1;
                    sample_count     <= '0;
                end else begin
                    sample_count <= sample_count + 1'b1;
                end
            end
        end
    end

endmodule
