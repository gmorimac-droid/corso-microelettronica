module traffic_light_fsm_timed #(
    parameter integer GREEN_TIME  = 5,
    parameter integer YELLOW_TIME = 2
)(
    input  wire clk,
    input  wire rst_n,

    output reg  roadA_red,
    output reg  roadA_yellow,
    output reg  roadA_green,

    output reg  roadB_red,
    output reg  roadB_yellow,
    output reg  roadB_green
);

    localparam [1:0] S_A_GREEN  = 2'b00;
    localparam [1:0] S_A_YELLOW = 2'b01;
    localparam [1:0] S_B_GREEN  = 2'b10;
    localparam [1:0] S_B_YELLOW = 2'b11;

    reg [1:0] current_state, next_state;

    localparam integer COUNTER_WIDTH = $clog2((GREEN_TIME > YELLOW_TIME) ? GREEN_TIME : YELLOW_TIME);
    reg [COUNTER_WIDTH-1:0] timer_cnt;
    reg [COUNTER_WIDTH-1:0] timer_max;

    // Timer target depends on state
    always @(*) begin
        case (current_state)
            S_A_GREEN,
            S_B_GREEN:  timer_max = GREEN_TIME - 1;

            S_A_YELLOW,
            S_B_YELLOW: timer_max = YELLOW_TIME - 1;

            default:    timer_max = GREEN_TIME - 1;
        endcase
    end

    // State register + timer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_A_GREEN;
            timer_cnt     <= 0;
        end else begin
            if (timer_cnt == timer_max) begin
                current_state <= next_state;
                timer_cnt     <= 0;
            end else begin
                timer_cnt <= timer_cnt + 1'b1;
            end
        end
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