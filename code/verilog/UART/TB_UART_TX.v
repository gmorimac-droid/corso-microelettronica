`timescale 1ns/1ps

module tb_uart_tx;

    localparam integer CLKS_PER_BIT = 4;

    reg       clk;
    reg       rst_n;
    reg       start;
    reg [7:0] data_in;

    wire tx;
    wire busy;
    wire done;

    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .data_in(data_in),
        .tx(tx),
        .busy(busy),
        .done(done)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task send_byte(input [7:0] din);
    begin
        @(posedge clk);
        data_in <= din;
        start   <= 1'b1;

        @(posedge clk);
        start   <= 1'b0;

        wait(done == 1'b1);
        @(posedge clk);
    end
    endtask

    initial begin
        rst_n   = 1'b0;
        start   = 1'b0;
        data_in = 8'h00;

        #20;
        rst_n = 1'b1;

        send_byte(8'hA5);
        send_byte(8'h3C);
        send_byte(8'hF0);

        #100;
        $finish;
    end

    initial begin
        $display("time rst start busy done tx data_in");
        $monitor("%0t   %b   %b    %b    %b   %b  %h",
                 $time, rst_n, start, busy, done, tx, data_in);
    end

endmodule