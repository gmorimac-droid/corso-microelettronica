`timescale 1ns/1ps
module fir_decim_integration_test;
    tb_top #(.TESTNAME("fir_decim")) tb();

    initial begin
        @(posedge tb.rst_n);
        tb.program_basic_config(4'd4, 1'b0, 1'b0);
        tb.push_ramp(16, 0);
        repeat (200) @(posedge tb.clk);
        if (tb.dut.output_count == 0)
            $fatal(1, "FIR+DECIM integration: no outputs produced");
        $display("FIR+DECIM INTEGRATION PASS output_count=%0d last_out=%0d", tb.dut.output_count, tb.data_out);
        $finish;
    end
endmodule
