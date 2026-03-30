`timescale 1ns/1ps

module tb_fifo_sync;

    localparam DATA_WIDTH = 8;
    localparam DEPTH      = 8;
    localparam ADDR_WIDTH = $clog2(DEPTH);

    reg                   clk;
    reg                   rst_n;
    reg                   write_en;
    reg                   read_en;
    reg  [DATA_WIDTH-1:0] data_in;

    wire [DATA_WIDTH-1:0] data_out;
    wire                  full;
    wire                  empty;

    fifo_sync #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en),
        .read_en(read_en),
        .data_in(data_in),
        .data_out(data_out),
        .full(full),
        .empty(empty)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n    = 1'b0;
        write_en = 1'b0;
        read_en  = 1'b0;
        data_in  = 8'h00;

        #12;
        rst_n = 1'b1;

        // Write 4 values
        @(posedge clk);
        write_en = 1'b1; data_in = 8'h11;

        @(posedge clk);
        data_in = 8'h22;

        @(posedge clk);
        data_in = 8'h33;

        @(posedge clk);
        data_in = 8'h44;

        @(posedge clk);
        write_en = 1'b0;

        // Read 2 values
        @(posedge clk);
        read_en = 1'b1;

        @(posedge clk);
        @(posedge clk);
        read_en = 1'b0;

        // Fill FIFO completely
        @(posedge clk); write_en = 1'b1; data_in = 8'h55;
        @(posedge clk); data_in = 8'h66;
        @(posedge clk); data_in = 8'h77;
        @(posedge clk); data_in = 8'h88;
        @(posedge clk); data_in = 8'h99;
        @(posedge clk); data_in = 8'hAA;

        @(posedge clk);
        write_en = 1'b0;

        // Try overflow
        @(posedge clk);
        write_en = 1'b1; data_in = 8'hFF;
        @(posedge clk);
        write_en = 1'b0;

        // Read everything
        @(posedge clk);
        read_en = 1'b1;

        repeat (10) @(posedge clk);

        read_en = 1'b0;

        // Try underflow
        @(posedge clk);
        read_en = 1'b1;
        @(posedge clk);
        read_en = 1'b0;

        #20;
        $finish;
    end

    initial begin
        $display("time rst wr rd din dout full empty");
        $monitor("%0t   %b   %b  %b  %h   %h   %b    %b",
                 $time, rst_n, write_en, read_en, data_in, data_out, full, empty);
    end

endmodule