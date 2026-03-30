`timescale 1ns/1ps

module tb_axi_auto_init_top;

    reg clk;
    reg rst_n;

    wire init_done;
    wire init_error;

    axi_auto_init_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .init_done(init_done),
        .init_error(init_error)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        #20;
        rst_n = 1'b1;

        wait(init_done || init_error);
        #20;

        if (init_error) begin
            $display("AUTO INIT FAILED");
        end else begin
            $display("AUTO INIT PASSED");
            $display("CONTROL = %h", dut.u_slave.reg_control);
            $display("WDATA   = %h", dut.u_slave.reg_wdata);
            $display("RDATA   = %h", dut.u_slave.reg_rdata);
        end

        $finish;
    end

    initial begin
        $display("time init_done init_error busy done wdata rdata");
        forever begin
            @(posedge clk);
            #1;
            $display("%0t   %b         %b          %b    %b    %h %h",
                     $time,
                     init_done,
                     init_error,
                     dut.status_busy,
                     dut.status_done,
                     dut.wdata_out,
                     dut.rdata_in);
        end
    end

endmodule