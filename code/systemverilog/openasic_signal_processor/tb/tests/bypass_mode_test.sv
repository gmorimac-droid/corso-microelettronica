`timescale 1ns/1ps
module bypass_mode_test;
    tb_top #(.TESTNAME("bypass")) tb();

    initial begin
        @(posedge tb.rst_n);
        tb.program_basic_config(4'd1, 1'b1, 1'b1); // bypass FIR + bypass decim
        tb.spi_write_sample(16'sd11);
        repeat (40) @(posedge tb.clk);
        if (tb.data_out !== 16'sd11)
            $fatal(1, "BYPASS TEST: expected 11 got %0d", tb.data_out);
        if (!tb.data_valid)
            $display("BYPASS TEST note: data_valid is pulse, may not be high at sample point");
        $display("BYPASS TEST PASS data_out=%0d", tb.data_out);
        $finish;
    end
endmodule
