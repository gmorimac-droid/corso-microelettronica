module traffic_light_fsm (
    input  wire clk,
    input  wire rst_n,

    output reg  roadA_red,
    output reg  roadA_yellow,
    output reg  roadA_green,

    output reg  roadB_red,
    output reg  roadB_yellow,
    output reg  roadB_green
);

    // State encoding
    localparam S_A_GREEN  = 2'b00;
    localparam S_A_YELLOW = 2'b01;
    localparam S_B_GREEN  = 2'b10;
    localparam S_B_YELLOW = 2'b11;

    reg [1:0] current_state, next_state;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= S_A_GREEN;
        else
            current_state <= next_state;
    end

    // Next-state logic
    always @(*) begin
        case (current_state)
            S_A_GREEN:  next_state = S_A_YELLOW;
            S_A_YELLOW: next_state = S_B_GREEN;
            S_B_GREEN:  next_state = S_B_YELLOW;
            S_B_YELLOW: next_state = S_A_GREEN;
            default:    next_state = S_A_GREEN;
        endcase
    end

    // Output logic (Moore FSM)
    always @(*) begin
        // Default values
        roadA_red    = 1'b0;
        roadA_yellow = 1'b0;
        roadA_green  = 1'b0;
        roadB_red    = 1'b0;
        roadB_yellow = 1'b0;
        roadB_green  = 1'b0;

        case (current_state)
            S_A_GREEN: begin
                roadA_green = 1'b1;
                roadB_red   = 1'b1;
            end

            S_A_YELLOW: begin
                roadA_yellow = 1'b1;
                roadB_red    = 1'b1;
            end

            S_B_GREEN: begin
                roadA_red   = 1'b1;
                roadB_green = 1'b1;
            end

            S_B_YELLOW: begin
                roadA_red    = 1'b1;
                roadB_yellow = 1'b1;
            end

            default: begin
                roadA_green = 1'b1;
                roadB_red   = 1'b1;
            end
        endcase
    end

endmodule