module control_fsm(
    input  logic clk,
    input  logic rst_n,
    input  logic cfg_enable,
    input  logic cfg_start,
    input  logic cfg_soft_reset,
    input  logic fifo_empty,
    input  logic out_valid,
    output logic proc_enable,
    output logic stat_busy,
    output logic stat_done
);

    typedef enum logic [1:0] {
        ST_IDLE = 2'b00,
        ST_RUN  = 2'b01,
        ST_DONE = 2'b10
    } state_t;

    state_t state, state_n;
    logic start_seen;

    always_comb begin
        state_n = state;
        unique case (state)
            ST_IDLE: begin
                if (cfg_enable && cfg_start && !cfg_soft_reset)
                    state_n = ST_RUN;
            end
            ST_RUN: begin
                if (!cfg_enable || cfg_soft_reset)
                    state_n = ST_IDLE;
                else if (out_valid && fifo_empty)
                    state_n = ST_DONE;
            end
            ST_DONE: begin
                if (!cfg_enable || cfg_soft_reset)
                    state_n = ST_IDLE;
                else if (!cfg_start)
                    state_n = ST_IDLE;
            end
            default: state_n = ST_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= ST_IDLE;
            stat_done  <= 1'b0;
            start_seen <= 1'b0;
        end else begin
            state <= state_n;

            // one-cycle pulse on transition to DONE
            stat_done <= (state != ST_DONE) && (state_n == ST_DONE);

            if (cfg_soft_reset || !cfg_enable)
                start_seen <= 1'b0;
            else if (cfg_start)
                start_seen <= 1'b1;
        end
    end

    assign proc_enable = (state == ST_RUN);
    assign stat_busy   = (state == ST_RUN);

endmodule
