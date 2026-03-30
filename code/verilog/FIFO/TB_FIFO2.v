`timescale 1ns/1ps

module tb_fifo_sync_v2;

    localparam integer DATA_WIDTH          = 8;
    localparam integer DEPTH               = 8;
    localparam integer ADDR_WIDTH          = $clog2(DEPTH);
    localparam integer ALMOST_FULL_THRESH  = 7;
    localparam integer ALMOST_EMPTY_THRESH = 1;

    reg                   clk;
    reg                   rst_n;
    reg                   write_en;
    reg                   read_en;
    reg  [DATA_WIDTH-1:0] data_in;

    wire [DATA_WIDTH-1:0] data_out;
    wire                  full;
    wire                  empty;
    wire                  almost_full;
    wire                  almost_empty;
    wire [ADDR_WIDTH:0]   count;

    integer errors;

    // Reference model storage
    reg [DATA_WIDTH-1:0] ref_mem [0:255];
    integer ref_wr_idx;
    integer ref_rd_idx;
    integer ref_count;
    reg [DATA_WIDTH-1:0] expected_data;

    wire do_write_tb;
    wire do_read_tb;

    assign do_write_tb = write_en && !full;
    assign do_read_tb  = read_en  && !empty;

    fifo_sync_v2 #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ALMOST_FULL_THRESH(ALMOST_FULL_THRESH),
        .ALMOST_EMPTY_THRESH(ALMOST_EMPTY_THRESH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en),
        .read_en(read_en),
        .data_in(data_in),
        .data_out(data_out),
        .full(full),
        .empty(empty),
        .almost_full(almost_full),
        .almost_empty(almost_empty),
        .count(count)
    );

    // Clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Reference model update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ref_wr_idx <= 0;
            ref_rd_idx <= 0;
            ref_count  <= 0;
            expected_data <= 0;
        end else begin
            if (do_read_tb) begin
                expected_data <= ref_mem[ref_rd_idx];
                ref_rd_idx <= ref_rd_idx + 1;
            end

            if (do_write_tb) begin
                ref_mem[ref_wr_idx] <= data_in;
                ref_wr_idx <= ref_wr_idx + 1;
            end

            case ({do_write_tb, do_read_tb})
                2'b10: ref_count <= ref_count + 1;
                2'b01: ref_count <= ref_count - 1;
                default: ref_count <= ref_count;
            endcase
        end
    end

    // Checker
    always @(posedge clk) begin
        if (rst_n) begin
            // Check count
            if (count !== ref_count[ADDR_WIDTH:0]) begin
                $display("[%0t] ERROR: count mismatch. DUT=%0d REF=%0d",
                         $time, count, ref_count);
                errors = errors + 1;
            end

            // Check flags
            if ((ref_count == 0) && (empty !== 1'b1)) begin
                $display("[%0t] ERROR: empty should be 1", $time);
                errors = errors + 1;
            end

            if ((ref_count != 0) && (empty !== 1'b0)) begin
                $display("[%0t] ERROR: empty should be 0", $time);
                errors = errors + 1;
            end

            if ((ref_count == DEPTH) && (full !== 1'b1)) begin
                $display("[%0t] ERROR: full should be 1", $time);
                errors = errors + 1;
            end

            if ((ref_count != DEPTH) && (full !== 1'b0)) begin
                $display("[%0t] ERROR: full should be 0", $time);
                errors = errors + 1;
            end

            if ((ref_count >= ALMOST_FULL_THRESH) && (almost_full !== 1'b1)) begin
                $display("[%0t] ERROR: almost_full should be 1", $time);
                errors = errors + 1;
            end

            if ((ref_count < ALMOST_FULL_THRESH) && (almost_full !== 1'b0)) begin
                $display("[%0t] ERROR: almost_full should be 0", $time);
                errors = errors + 1;
            end

            if ((ref_count <= ALMOST_EMPTY_THRESH) && (almost_empty !== 1'b1)) begin
                $display("[%0t] ERROR: almost_empty should be 1", $time);
                errors = errors + 1;
            end

            if ((ref_count > ALMOST_EMPTY_THRESH) && (almost_empty !== 1'b0)) begin
                $display("[%0t] ERROR: almost_empty should be 0", $time);
                errors = errors + 1;
            end
        end
    end

    // Data checker for synchronous read
    always @(posedge clk) begin
        if (rst_n && do_read_tb) begin
            #1;
            if (data_out !== expected_data) begin
                $display("[%0t] ERROR: data mismatch. DUT=%h REF=%h",
                         $time, data_out, expected_data);
                errors = errors + 1;
            end
        end
    end

    // Tasks
    task write_one(input [DATA_WIDTH-1:0] din);
    begin
        @(posedge clk);
        write_en <= 1'b1;
        read_en  <= 1'b0;
        data_in  <= din;

        @(posedge clk);
        write_en <= 1'b0;
        data_in  <= 0;
    end
    endtask

    task read_one;
    begin
        @(posedge clk);
        read_en  <= 1'b1;
        write_en <= 1'b0;

        @(posedge clk);
        read_en <= 1'b0;
    end
    endtask

    task write_and_read(input [DATA_WIDTH-1:0] din);
    begin
        @(posedge clk);
        write_en <= 1'b1;
        read_en  <= 1'b1;
        data_in  <= din;

        @(posedge clk);
        write_en <= 1'b0;
        read_en  <= 1'b0;
        data_in  <= 0;
    end
    endtask

    // Stimulus
    initial begin
        errors   = 0;
        rst_n    = 1'b0;
        write_en = 1'b0;
        read_en  = 1'b0;
        data_in  = 0;

        #12;
        rst_n = 1'b1;

        // Basic writes
        write_one(8'h11);
        write_one(8'h22);
        write_one(8'h33);

        // Basic reads
        read_one;
        read_one;

        // Mixed traffic
        write_one(8'h44);
        write_one(8'h55);
        read_one;
        write_one(8'h66);
        write_and_read(8'h77);

        // Fill FIFO
        write_one(8'h88);
        write_one(8'h99);
        write_one(8'hAA);
        write_one(8'hBB);
        write_one(8'hCC);
        write_one(8'hDD);

        // Overflow attempt
        write_one(8'hEE);

        // Drain FIFO
        repeat (10) read_one;

        // Underflow attempt
        read_one;

        #20;

        if (errors == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED - errors = %0d", errors);

        $finish;
    end

endmodule