module fifo_sync_v2 #(
    parameter integer DATA_WIDTH          = 8,
    parameter integer DEPTH               = 16,
    parameter integer ADDR_WIDTH          = $clog2(DEPTH),
    parameter integer ALMOST_FULL_THRESH  = DEPTH - 1,
    parameter integer ALMOST_EMPTY_THRESH = 1
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  write_en,
    input  wire                  read_en,
    input  wire [DATA_WIDTH-1:0] data_in,

    output reg  [DATA_WIDTH-1:0] data_out,
    output wire                  full,
    output wire                  empty,
    output wire                  almost_full,
    output wire                  almost_empty,
    output wire [ADDR_WIDTH:0]   count
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH:0]   count_reg;

    wire do_write;
    wire do_read;

    assign count = count_reg;

    assign empty        = (count_reg == 0);
    assign full         = (count_reg == DEPTH);
    assign almost_full  = (count_reg >= ALMOST_FULL_THRESH);
    assign almost_empty = (count_reg <= ALMOST_EMPTY_THRESH);

    assign do_write = write_en && !full;
    assign do_read  = read_en  && !empty;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr   <= {ADDR_WIDTH{1'b0}};
            rd_ptr   <= {ADDR_WIDTH{1'b0}};
            count_reg<= {(ADDR_WIDTH+1){1'b0}};
            data_out <= {DATA_WIDTH{1'b0}};
        end else begin
            // Write path
            if (do_write) begin
                mem[wr_ptr] <= data_in;
                if (wr_ptr == DEPTH-1)
                    wr_ptr <= {ADDR_WIDTH{1'b0}};
                else
                    wr_ptr <= wr_ptr + 1'b1;
            end

            // Read path
            if (do_read) begin
                data_out <= mem[rd_ptr];
                if (rd_ptr == DEPTH-1)
                    rd_ptr <= {ADDR_WIDTH{1'b0}};
                else
                    rd_ptr <= rd_ptr + 1'b1;
            end

            // Count update
            case ({do_write, do_read})
                2'b10: count_reg <= count_reg + 1'b1;
                2'b01: count_reg <= count_reg - 1'b1;
                default: count_reg <= count_reg;
            endcase
        end
    end

endmodule