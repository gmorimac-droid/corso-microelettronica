`timescale 1ns/1ps

module tb_uart_loopback_top;

    localparam integer CLKS_PER_BIT = 4;

    reg        clk;
    reg        rst_n;
    reg        start;
    reg  [7:0] tx_data_in;

    wire       tx_busy;
    wire       tx_done;
    wire [7:0] rx_data_out;
    wire       rx_data_valid;
    wire       rx_busy;
    wire       serial_line;

    integer errors;

    uart_loopback_top #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (start),
        .tx_data_in   (tx_data_in),
        .tx_busy      (tx_busy),
        .tx_done      (tx_done),
        .rx_data_out  (rx_data_out),
        .rx_data_valid(rx_data_valid),
        .rx_busy      (rx_busy),
        .serial_line  (serial_line)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task send_byte(input [7:0] din);
    begin
        @(posedge clk);
        tx_data_in <= din;
        start      <= 1'b1;

        @(posedge clk);
        start      <= 1'b0;
    end
    endtask

    task wait_and_check(input [7:0] expected);
    begin
        wait(rx_data_valid == 1'b1);
        #1;
        if (rx_data_out !== expected) begin
            $display("ERROR: rx_data_out=%h expected=%h at time %0t",
                     rx_data_out, expected, $time);
            errors = errors + 1;
        end else begin
            $display("OK: received %h at time %0t", rx_data_out, $time);
        end
        @(posedge clk);
    end
    endtask

    initial begin
        errors     = 0;
        rst_n      = 1'b0;
        start      = 1'b0;
        tx_data_in = 8'h00;

        #20;
        rst_n = 1'b1;

        send_byte(8'hA5);
        wait_and_check(8'hA5);

        send_byte(8'h3C);
        wait_and_check(8'h3C);

        send_byte(8'hF0);
        wait_and_check(8'hF0);

        send_byte(8'h00);
        wait_and_check(8'h00);

        send_byte(8'hFF);
        wait_and_check(8'hFF);

        #50;

        if (errors == 0)
            $display("LOOPBACK TEST PASSED");
        else
            $display("LOOPBACK TEST FAILED - errors = %0d", errors);

        $finish;
    end

    initial begin
        $display("time rst start tx_busy tx_done rx_busy rx_valid serial tx_in rx_out");
        $monitor("%0t   %b   %b    %b      %b      %b      %b       %b      %h    %h",
                 $time, rst_n, start, tx_busy, tx_done, rx_busy, rx_data_valid,
                 serial_line, tx_data_in, rx_data_out);
    end

endmodule