`timescale 1ns/1ps
module spi_reg_test;
    tb_top #(.TESTNAME("spi_reg")) tb();

    initial begin
        @(posedge tb.rst_n);

        tb.spi_write_reg(`REG_DECIM, 8'h04);
        repeat (10) @(posedge tb.clk);
        if (tb.dut.cfg_decim_factor !== 4)
            $fatal(1, "SPI REG TEST: DECIM expected 4 got %0d", tb.dut.cfg_decim_factor);

        tb.spi_write_reg(`REG_CTRL, 8'b0000_1101); // enable,start,bypass_fir
        repeat (10) @(posedge tb.clk);
        if (!tb.dut.cfg_enable)      $fatal(1, "SPI REG TEST: cfg_enable not set");
        if (!tb.dut.cfg_start)       $fatal(1, "SPI REG TEST: cfg_start not set");
        if (!tb.dut.cfg_bypass_fir)  $fatal(1, "SPI REG TEST: cfg_bypass_fir not set");

        $display("SPI REG TEST PASS");
        $finish;
    end
endmodule
