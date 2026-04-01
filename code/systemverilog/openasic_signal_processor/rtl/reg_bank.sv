`include "defines.svh"

module reg_bank #(
    parameter int DATA_W  = `DATA_W,
    parameter int DECIM_W = `DECIM_W
)(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     wr_en,
    input  logic [7:0]               wr_addr,
    input  logic [15:0]              wr_data,
    input  logic [7:0]               rd_addr,
    output logic [15:0]              rd_data,

    input  logic                     stat_busy,
    input  logic                     stat_done,
    input  logic                     stat_overflow,
    input  logic                     stat_underflow,
    input  logic                     stat_data_valid,
    input  logic [15:0]              stat_data_out,
    input  logic [15:0]              input_count,
    input  logic [15:0]              output_count,

    output logic                     cfg_enable,
    output logic                     cfg_soft_reset,
    output logic                     cfg_start,
    output logic                     cfg_bypass_fir,
    output logic                     cfg_bypass_decim,
    output logic [DECIM_W-1:0]       cfg_decim_factor
);

    logic [15:0] ctrl_reg;
    logic [15:0] decim_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_reg  <= '0;
            decim_reg <= 16'd1;
        end else begin
            if (wr_en) begin
                unique case (wr_addr)
                    `REG_CTRL:  ctrl_reg  <= wr_data;
                    `REG_DECIM: decim_reg <= wr_data;
                    default: ;
                endcase
            end
        end
    end

    assign cfg_enable       = ctrl_reg[`CTRL_ENABLE];
    assign cfg_soft_reset   = ctrl_reg[`CTRL_SOFT_RESET];
    assign cfg_start        = ctrl_reg[`CTRL_START];
    assign cfg_bypass_fir   = ctrl_reg[`CTRL_BYPASS_FIR];
    assign cfg_bypass_decim = ctrl_reg[`CTRL_BYPASS_DECIM];
    assign cfg_decim_factor = decim_reg[DECIM_W-1:0];

    always_comb begin
        rd_data = 16'h0000;
        unique case (rd_addr)
            `REG_CTRL:      rd_data = ctrl_reg;
            `REG_STATUS: begin
                rd_data[`STAT_BUSY]       = stat_busy;
                rd_data[`STAT_DONE]       = stat_done;
                rd_data[`STAT_OVF]        = stat_overflow;
                rd_data[`STAT_UDF]        = stat_underflow;
                rd_data[`STAT_DATA_VALID] = stat_data_valid;
            end
            `REG_DECIM:     rd_data = decim_reg;
            `REG_IN_COUNT:  rd_data = input_count;
            `REG_OUT_COUNT: rd_data = output_count;
            `REG_DATA_OUT:  rd_data = stat_data_out;
            default:        rd_data = 16'h0000;
        endcase
    end

endmodule
