`timescale 1ns/1ps
module smoke_test;
    tb_top #(.TESTNAME("smoke")) tb();

    initial begin
        @(posedge tb.rst_n);
        tb.program_basic_config(4'd1, 1'b0, 1'b0);
        tb.push_ramp(12, 0);
        repeat (100) @(posedge tb.clk);
        if (tb.dut.input_count != 12)
            $fatal(1, "SMOKE: input_count expected 12 got %0d", tb.dut.input_count);
        if (tb.dut.output_count == 0)
            $fatal(1, "SMOKE: output_count expected >0 got 0");
        $display("SMOKE TEST PASS input_count=%0d output_count=%0d", tb.dut.input_count, tb.dut.output_count);
        $finish;
    end
endmodule
