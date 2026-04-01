`timescale 1ns/1ps
`include "defines.svh"

module tb_top #(
    parameter string TESTNAME = "smoke"
);

    logic clk;
    logic rst_n;
    logic spi_sclk;
    logic spi_cs_n;
    logic spi_mosi;
    logic spi_miso;
    logic signed [15:0] data_out;
    logic data_valid;
    logic busy;
    logic irq;

    top dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .spi_sclk (spi_sclk),
        .spi_cs_n (spi_cs_n),
        .spi_mosi (spi_mosi),
        .spi_miso (spi_miso),
        .data_out (data_out),
        .data_valid(data_valid),
        .busy     (busy),
        .irq      (irq)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk; // 100 MHz TB clock
    end

    initial begin
        spi_sclk = 1'b0;
        spi_cs_n = 1'b1;
        spi_mosi = 1'b0;
        rst_n    = 1'b0;
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
    end

    task automatic spi_shift_bit(input bit b);
        begin
            spi_mosi = b;
            repeat (2) @(posedge clk);
            spi_sclk = 1'b1;
            repeat (2) @(posedge clk);
            spi_sclk = 1'b0;
            repeat (1) @(posedge clk);
        end
    endtask

    task automatic spi_send24(input [23:0] frame);
        begin
            spi_cs_n = 1'b0;
            repeat (1) @(posedge clk);
            for (int i = 23; i >= 0; i--) begin
                spi_shift_bit(frame[i]);
            end
            spi_cs_n = 1'b1;
            repeat (3) @(posedge clk);
        end
    endtask

    task automatic spi_write_reg(input [7:0] addr, input [7:0] data8);
        begin
            spi_send24({`SPI_CMD_WR_REG, addr, data8});
        end
    endtask

    task automatic spi_write_sample(input signed [15:0] s);
        begin
            spi_send24({`SPI_CMD_WR_SAMPLE, s[15:8], s[7:0]});
        end
    endtask

    task automatic program_basic_config(input [3:0] decim, input bit bypass_fir, input bit bypass_decim);
        logic [7:0] ctrl;
        begin
            ctrl = 8'h00;
            ctrl[`CTRL_ENABLE]       = 1'b1;
            ctrl[`CTRL_START]        = 1'b1;
            ctrl[`CTRL_BYPASS_FIR]   = bypass_fir;
            ctrl[`CTRL_BYPASS_DECIM] = bypass_decim;
            spi_write_reg(`REG_DECIM, {4'h0, decim});
            spi_write_reg(`REG_CTRL, ctrl);
        end
    endtask

    task automatic push_ramp(input int n, input int start = 0);
        begin
            for (int i = 0; i < n; i++) begin
                spi_write_sample(start + i);
            end
        end
    endtask

endmodule
