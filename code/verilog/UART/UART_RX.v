module uart_rx #(
    parameter integer CLKS_PER_BIT = 434
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,

    output reg [7:0]  data_out,
    output reg        data_valid,
    output reg        busy
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
            state      <= S_IDLE;
            clk_count  <= 0;
            bit_index  <= 0;
            data_reg   <= 8'h00;
            data_out   <= 8'h00;
            data_valid <= 1'b0;
            busy       <= 1'b0;
        end else begin
            data_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    busy      <= 1'b0;
                    clk_count <= 0;
                    bit_index <= 0;

                    if (rx == 1'b0) begin
                        busy  <= 1'b1;
                        state <= S_START_BIT;
                    end
                end

                S_START_BIT: begin
                    // Campiona al centro dello start bit
                    if (clk_count == (CLKS_PER_BIT-1)/2) begin
                        if (rx == 1'b0) begin
                            clk_count <= 0;
                            state     <= S_DATA_BITS;
                        end else begin
                            // Falso start bit
                            state <= S_IDLE;
                            busy  <= 1'b0;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_DATA_BITS: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;

                        // Campiona il bit corrente
                        data_reg[bit_index] <= rx;

                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= 0;
                            state     <= S_STOP_BIT;
                        end
                    end
                end

                S_STOP_BIT: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;
                        data_out  <= data_reg;
                        state     <= S_CLEANUP;
                    end
                end

                S_CLEANUP: begin
                    busy       <= 1'b0;
                    data_valid <= 1'b1;
                    state      <= S_IDLE;
                end

                default: begin
                    state      <= S_IDLE;
                    busy       <= 1'b0;
                    data_valid <= 1'b0;
                end
            endcase
        end
    end

endmodule