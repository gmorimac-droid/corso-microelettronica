module uart_tx #(
    parameter integer CLKS_PER_BIT = 434
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [7:0] data_in,

    output reg        tx,
    output reg        busy,
    output reg        done
);

    localparam [2:0] S_IDLE      = 3'd0;
    localparam [2:0] S_START_BIT = 3'd1;
    localparam [2:0] S_DATA_BITS = 3'd2;
    localparam [2:0] S_STOP_BIT  = 3'd3;
    localparam [2:0] S_CLEANUP   = 3'd4;

    reg [2:0] state;
    reg [$clog2(CLKS_PER_BIT)-1:0] clk_count;
    reg [2:0] bit_index;
    reg [7:0] data_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            clk_count <= 0;
            bit_index <= 0;
            data_reg  <= 8'h00;
            tx        <= 1'b1;
            busy      <= 1'b0;
            done      <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    tx        <= 1'b1;
                    busy      <= 1'b0;
                    clk_count <= 0;
                    bit_index <= 0;

                    if (start) begin
                        busy     <= 1'b1;
                        data_reg <= data_in;
                        state    <= S_START_BIT;
                    end
                end

                S_START_BIT: begin
                    tx <= 1'b0;

                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;
                        state     <= S_DATA_BITS;
                    end
                end

                S_DATA_BITS: begin
                    tx <= data_reg[bit_index];

                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;

                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= 0;
                            state     <= S_STOP_BIT;
                        end
                    end
                end

                S_STOP_BIT: begin
                    tx <= 1'b1;

                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;
                        state     <= S_CLEANUP;
                    end
                end

                S_CLEANUP: begin
                    tx   <= 1'b1;
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                    tx    <= 1'b1;
                    busy  <= 1'b0;
                    done  <= 1'b0;
                end
            endcase
        end
    end

endmodule