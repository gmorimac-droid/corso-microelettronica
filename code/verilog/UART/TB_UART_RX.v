`timescale 1ns/1ps

module tb_uart_rx;

    localparam integer CLKS_PER_BIT = 4;

    reg       clk;
    reg       rst_n;
    reg       rx;

    wire [7:0] data_out;
    wire       data_valid;
    wire       busy;

    integer errors;

    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .data_out(data_out),
        .data_valid(data_valid),
        .busy(busy)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task send_uart_byte(input [7:0] din);
        integer i;
    begin
        // Idle
        rx <= 1'b1;
        @(posedge clk);

        // Start bit
        rx <= 1'b0;
        repeat (CLKS_PER_BIT) @(posedge clk);

        // Data bits LSB first
        for (i = 0; i < 8; i = i + 1) begin
            rx <= din[i];
            repeat (CLKS_PER_BIT) @(posedge clk);
        end

        // Stop bit
        rx <= 1'b1;
        repeat (CLKS_PER_BIT) @(posedge clk);
    end
    endtask

    task check_received(input [7:0] expected);
    begin
        wait(data_valid == 1'b1);
        #1;
        if (data_out !== expected) begin
            $display("ERROR: received %h expected %h at time %0t",
                     data_out, expected, $time);
            errors = errors + 1;
        end
        @(posedge clk);
    end
    endtask

    initial begin
        errors = 0;
        rst_n  = 1'b0;
        rx     = 1'b1;

        #20;
        rst_n = 1'b1;

        send_uart_byte(8'hA5);
        check_received(8'hA5);

        send_uart_byte(8'h3C);
        check_received(8'h3C);

        send_uart_byte(8'hF0);
        check_received(8'hF0);

        #50;

        if (errors == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED - errors = %0d", errors);

        $finish;
    end

endmodule