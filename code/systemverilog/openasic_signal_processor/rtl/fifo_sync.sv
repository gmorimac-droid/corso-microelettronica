`include "defines.svh"

module fifo_sync #(
    parameter int DATA_W = `DATA_W,
    parameter int DEPTH  = `FIFO_DEPTH,
    parameter int ADDR_W = $clog2(DEPTH)
)(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     soft_reset,
    input  logic                     wr_en,
    input  logic                     rd_en,
    input  logic signed [DATA_W-1:0] wr_data,
    output logic signed [DATA_W-1:0] rd_data,
    output logic                     full,
    output logic                     empty,
    output logic                     overflow,
    output logic                     underflow,
    output logic [ADDR_W:0]          level
);

    logic signed [DATA_W-1:0] mem [0:DEPTH-1];
    logic [ADDR_W-1:0] wr_ptr, rd_ptr;
    logic [ADDR_W:0]   count;

    assign empty = (count == '0);
    assign full  = (count == DEPTH);
    assign level = count;
    assign rd_data = mem[rd_ptr];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr   <= '0;
            rd_ptr   <= '0;
            count    <= '0;
            overflow <= 1'b0;
            underflow<= 1'b0;
        end else begin
            overflow <= 1'b0;
            underflow<= 1'b0;

            if (soft_reset) begin
                wr_ptr    <= '0;
                rd_ptr    <= '0;
                count     <= '0;
                overflow  <= 1'b0;
                underflow <= 1'b0;
            end else begin
                unique case ({wr_en && !rd_en, rd_en && !wr_en})
                    2'b10: begin
                        if (!full) begin
                            mem[wr_ptr] <= wr_data;
                            wr_ptr <= wr_ptr + 1'b1;
                            count  <= count + 1'b1;
                        end else begin
                            overflow <= 1'b1;
                        end
                    end
                    2'b01: begin
                        if (!empty) begin
                            rd_ptr <= rd_ptr + 1'b1;
                            count  <= count - 1'b1;
                        end else begin
                            underflow <= 1'b1;
                        end
                    end
                    default: begin
                        if (wr_en && rd_en) begin
                            if (!empty && !full) begin
                                mem[wr_ptr] <= wr_data;
                                wr_ptr <= wr_ptr + 1'b1;
                                rd_ptr <= rd_ptr + 1'b1;
                            end else if (empty) begin
                                mem[wr_ptr] <= wr_data;
                                wr_ptr <= wr_ptr + 1'b1;
                                count  <= count + 1'b1;
                            end else if (full) begin
                                rd_ptr <= rd_ptr + 1'b1;
                                count  <= count - 1'b1;
                            end
                        end
                    end
                endcase
            end
        end
    end

endmodule
