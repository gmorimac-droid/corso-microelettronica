`include "defines.svh"

module top #(
    parameter int DATA_W = `DATA_W
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  spi_sclk,
    input  logic                  spi_cs_n,
    input  logic                  spi_mosi,
    output logic                  spi_miso,
    output logic signed [15:0]    data_out,
    output logic                  data_valid,
    output logic                  busy,
    output logic                  irq
);

    logic reg_wr_en;
    logic [7:0] reg_wr_addr;
    logic [15:0] reg_wr_data;
    logic [7:0] reg_rd_addr;
    logic [15:0] reg_rd_data;
    logic sample_push_valid;
    logic signed [15:0] sample_push_data;

    logic cfg_enable, cfg_soft_reset, cfg_start, cfg_bypass_fir, cfg_bypass_decim;
    logic [`DECIM_W-1:0] cfg_decim_factor;

    logic fifo_wr_en, fifo_rd_en, fifo_full, fifo_empty, fifo_overflow, fifo_underflow;
    logic signed [15:0] fifo_rd_data;
    logic [$clog2(`FIFO_DEPTH):0] fifo_level;

    logic signed [15:0] fir_out;
    logic fir_out_valid;
    logic signed [15:0] fir_sel_data;
    logic fir_sel_valid;
    logic signed [15:0] decim_out;
    logic decim_out_valid;

    logic stat_busy_i, stat_done_i, stat_ovf_i, stat_udf_i, stat_data_valid_i;
    logic [15:0] out_data_reg;
    logic out_valid_pulse;
    logic [15:0] input_count, output_count;
    logic proc_enable;

    spi_slave u_spi (
        .clk        (clk),
        .rst_n      (rst_n),
        .spi_sclk   (spi_sclk),
        .spi_cs_n   (spi_cs_n),
        .spi_mosi   (spi_mosi),
        .spi_miso   (spi_miso),
        .reg_wr_en  (reg_wr_en),
        .reg_wr_addr(reg_wr_addr),
        .reg_wr_data(reg_wr_data),
        .reg_rd_addr(reg_rd_addr),
        .reg_rd_data(reg_rd_data),
        .sample_valid(sample_push_valid),
        .sample_data (sample_push_data)
    );

    reg_bank u_reg_bank (
        .clk            (clk),
        .rst_n          (rst_n),
        .wr_en          (reg_wr_en),
        .wr_addr        (reg_wr_addr),
        .wr_data        (reg_wr_data),
        .rd_addr        (reg_rd_addr),
        .rd_data        (reg_rd_data),
        .stat_busy      (stat_busy_i),
        .stat_done      (stat_done_i),
        .stat_overflow  (stat_ovf_i),
        .stat_underflow (stat_udf_i),
        .stat_data_valid(stat_data_valid_i),
        .stat_data_out  (out_data_reg),
        .input_count    (input_count),
        .output_count   (output_count),
        .cfg_enable     (cfg_enable),
        .cfg_soft_reset (cfg_soft_reset),
        .cfg_start      (cfg_start),
        .cfg_bypass_fir (cfg_bypass_fir),
        .cfg_bypass_decim(cfg_bypass_decim),
        .cfg_decim_factor(cfg_decim_factor)
    );

    control_fsm u_fsm (
        .clk          (clk),
        .rst_n        (rst_n),
        .cfg_enable   (cfg_enable),
        .cfg_start    (cfg_start),
        .cfg_soft_reset(cfg_soft_reset),
        .fifo_empty   (fifo_empty),
        .out_valid    (out_valid_pulse),
        .proc_enable  (proc_enable),
        .stat_busy    (stat_busy_i),
        .stat_done    (stat_done_i)
    );

    assign fifo_wr_en = sample_push_valid && !fifo_full;
    assign fifo_rd_en = proc_enable && !fifo_empty;

    fifo_sync u_fifo (
        .clk       (clk),
        .rst_n     (rst_n),
        .soft_reset(cfg_soft_reset),
        .wr_en     (fifo_wr_en),
        .rd_en     (fifo_rd_en),
        .wr_data   (sample_push_data),
        .rd_data   (fifo_rd_data),
        .full      (fifo_full),
        .empty     (fifo_empty),
        .overflow  (fifo_overflow),
        .underflow (fifo_underflow),
        .level     (fifo_level)
    );

    fir8_core u_fir (
        .clk             (clk),
        .rst_n           (rst_n & ~cfg_soft_reset),
        .sample_valid    (fifo_rd_en),
        .sample_in       (fifo_rd_data),
        .sample_out      (fir_out),
        .sample_out_valid(fir_out_valid)
    );

    assign fir_sel_data  = cfg_bypass_fir ? fifo_rd_data : fir_out;
    assign fir_sel_valid = cfg_bypass_fir ? fifo_rd_en   : fir_out_valid;

    decimator u_decim (
        .clk            (clk),
        .rst_n          (rst_n & ~cfg_soft_reset),
        .decim_factor   (cfg_decim_factor),
        .sample_in      (fir_sel_data),
        .sample_valid   (fir_sel_valid),
        .sample_out     (decim_out),
        .sample_out_valid(decim_out_valid)
    );

    output_stage u_out (
        .clk            (clk),
        .rst_n          (rst_n),
        .sample_in      (cfg_bypass_decim ? fir_sel_data : decim_out),
        .sample_valid   (cfg_bypass_decim ? fir_sel_valid : decim_out_valid),
        .data_out       (out_data_reg),
        .data_valid_pulse(out_valid_pulse)
    );

    status_flags u_flags (
        .fifo_overflow (fifo_overflow),
        .fifo_underflow(fifo_underflow),
        .stat_busy_in  (stat_busy_i),
        .stat_done_in  (stat_done_i),
        .data_valid_in (out_valid_pulse),
        .stat_busy     (busy),
        .stat_done     (/* unused */),
        .stat_overflow (stat_ovf_i),
        .stat_underflow(stat_udf_i),
        .stat_data_valid(stat_data_valid_i)
    );

    assign data_out   = out_data_reg;
    assign data_valid = out_valid_pulse;
    assign irq        = out_valid_pulse;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_count  <= '0;
            output_count <= '0;
        end else begin
            if (cfg_soft_reset) begin
                input_count  <= '0;
                output_count <= '0;
            end else begin
                if (sample_push_valid)
                    input_count <= input_count + 1'b1;
                if (out_valid_pulse)
                    output_count <= output_count + 1'b1;
            end
        end
    end

endmodule
