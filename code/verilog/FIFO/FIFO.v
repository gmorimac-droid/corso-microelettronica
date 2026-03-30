module fifo_sync #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16,
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  write_en,
    input  wire                  read_en,
    input  wire [DATA_WIDTH-1:0] data_in,

    output reg  [DATA_WIDTH-1:0] data_out,
    output wire                  full,
    output wire                  empty
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH:0]   count;

    wire do_write;
    wire do_read;

    assign do_write = write_en && !full;
    assign do_read  = read_en  && !empty;

    assign empty = (count == 0);
    assign full  = (count == DEPTH);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr   <= {ADDR_WIDTH{1'b0}};
            rd_ptr   <= {ADDR_WIDTH{1'b0}};
            count    <= {(ADDR_WIDTH+1){1'b0}};
            data_out <= {DATA_WIDTH{1'b0}};
        end else begin
            // Write
            if (do_write) begin
                mem[wr_ptr] <= data_in;
                if (wr_ptr == DEPTH-1)
                    wr_ptr <= {ADDR_WIDTH{1'b0}};
                else
                    wr_ptr <= wr_ptr + 1'b1;
            end

            // Read
            if (do_read) begin
                data_out <= mem[rd_ptr];
                if (rd_ptr == DEPTH-1)
                    rd_ptr <= {ADDR_WIDTH{1'b0}};
                else
                    rd_ptr <= rd_ptr + 1'b1;
            end

            // Count update
            case ({do_write, do_read})
                2'b10: count <= count + 1'b1; // only write
                2'b01: count <= count - 1'b1; // only read
                default: count <= count;      // no op or simultaneous rd/wr
            endcase
        end
    end

endmodule