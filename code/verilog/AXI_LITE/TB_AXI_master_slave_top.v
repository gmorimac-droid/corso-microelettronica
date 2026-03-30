`timescale 1ns/1ps

module tb_axi_master_slave_top;

    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;

    reg                    clk;
    reg                    rst_n;

    reg                    cmd_start;
    reg                    cmd_rw;
    reg  [ADDR_WIDTH-1:0]  cmd_addr;
    reg  [DATA_WIDTH-1:0]  cmd_wdata;
    wire [DATA_WIDTH-1:0]  cmd_rdata;
    wire                   cmd_busy;
    wire                   cmd_done;
    wire                   cmd_error;

    integer errors;
    reg [31:0] rd_data;
    integer i;

    axi_master_slave_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .cmd_start (cmd_start),
        .cmd_rw    (cmd_rw),
        .cmd_addr  (cmd_addr),
        .cmd_wdata (cmd_wdata),
        .cmd_rdata (cmd_rdata),
        .cmd_busy  (cmd_busy),
        .cmd_done  (cmd_done),
        .cmd_error (cmd_error)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task do_write(
        input [ADDR_WIDTH-1:0] wr_addr,
        input [DATA_WIDTH-1:0] wr_data
    );
    begin
        @(posedge clk);
        cmd_addr  <= wr_addr;
        cmd_wdata <= wr_data;
        cmd_rw    <= 1'b0;
        cmd_start <= 1'b1;

        @(posedge clk);
        cmd_start <= 1'b0;

        wait(cmd_done == 1'b1);
        @(posedge clk);

        if (cmd_error) begin
            $display("ERROR: write transaction failed at addr %h", wr_addr);
            errors = errors + 1;
        end
    end
    endtask

    task do_read(
        input  [ADDR_WIDTH-1:0] rd_addr,
        output [DATA_WIDTH-1:0] rd_data
    );
    begin
        @(posedge clk);
        cmd_addr  <= rd_addr;
        cmd_wdata <= 32'h0;
        cmd_rw    <= 1'b1;
        cmd_start <= 1'b1;

        @(posedge clk);
        cmd_start <= 1'b0;

        wait(cmd_done == 1'b1);
        rd_data = cmd_rdata;
        @(posedge clk);

        if (cmd_error) begin
            $display("ERROR: read transaction failed at addr %h", rd_addr);
            errors = errors + 1;
        end
    end
    endtask

    initial begin
        errors    = 0;
        cmd_start = 1'b0;
        cmd_rw    = 1'b0;
        cmd_addr  = {ADDR_WIDTH{1'b0}};
        cmd_wdata = {DATA_WIDTH{1'b0}};
        rst_n     = 1'b0;

        #20;
        rst_n = 1'b1;

        // 1) Write input data
        do_write(32'h0000_0008, 32'h0000_0010);

        // 2) Enable block
        do_write(32'h0000_0000, 32'h0000_0001);

        // 3) Start operation
        do_write(32'h0000_0000, 32'h0000_0003);

        // 4) Poll STATUS until done
        rd_data = 32'h0;
        for (i = 0; i < 10; i = i + 1) begin
            do_read(32'h0000_0004, rd_data);
            if (rd_data[1] == 1'b1)
                disable polling_done;
        end

        polling_done: begin
            for (i = 0; i < 10; i = i + 1) begin
                do_read(32'h0000_0004, rd_data);
                if (rd_data[1] == 1'b1)
                    disable polling_done;
            end
        end

        // Final STATUS check
        do_read(32'h0000_0004, rd_data);
        if (rd_data[1] !== 1'b1) begin
            $display("ERROR: done bit not seen in STATUS");
            errors = errors + 1;
        end

        // 5) Read result
        do_read(32'h0000_000C, rd_data);
        if (rd_data !== 32'h0000_0011) begin
            $display("ERROR: result mismatch. got=%h expected=00000011", rd_data);
            errors = errors + 1;
        end

        // 6) Read back control and wdata
        do_read(32'h0000_0000, rd_data);
        if (rd_data[0] !== 1'b1) begin
            $display("ERROR: enable bit not retained");
            errors = errors + 1;
        end

        do_read(32'h0000_0008, rd_data);
        if (rd_data !== 32'h0000_0010) begin
            $display("ERROR: WDATA readback mismatch");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("MASTER+SLAVE LOOP TEST PASSED");
        else
            $display("MASTER+SLAVE LOOP TEST FAILED - errors = %0d", errors);

        $finish;
    end

    initial begin
        $display("time start rw addr wdata busy done err rdata");
        forever begin
            @(posedge clk);
            #1;
            $display("%0t   %b    %b  %h %h %b    %b    %b   %h",
                     $time, cmd_start, cmd_rw, cmd_addr, cmd_wdata,
                     cmd_busy, cmd_done, cmd_error, cmd_rdata);
        end
    end

endmodule