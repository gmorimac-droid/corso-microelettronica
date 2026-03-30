`timescale 1ns/1ps

module tb_mini_cpu;

    reg clk;
    reg rst_n;

    mini_cpu dut (
        .clk  (clk),
        .rst_n(rst_n)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        #20;
        rst_n = 1'b1;

        repeat (20) @(posedge clk);

        $display("Final register state:");
        $display("R0 = %0d", dut.regfile[0]);
        $display("R1 = %0d", dut.regfile[1]);
        $display("R2 = %0d", dut.regfile[2]);
        $display("R3 = %0d", dut.regfile[3]);
        $display("PC = %0d", dut.pc);
        $display("ZERO = %0d", dut.zero_flag);
        $display("HALTED = %0d", dut.halted);

        $finish;
    end

    initial begin
        $display("time pc opcode R0 R1 R2 R3 zero halted");
        forever begin
            @(posedge clk);
            #1;
            $display("%0t   %0d  %h     %0d  %0d  %0d  %0d  %0d    %0d",
                     $time,
                     dut.pc,
                     dut.opcode,
                     dut.regfile[0],
                     dut.regfile[1],
                     dut.regfile[2],
                     dut.regfile[3],
                     dut.zero_flag,
                     dut.halted);
        end
    end

endmodule