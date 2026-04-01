module status_flags(
    input  logic fifo_overflow,
    input  logic fifo_underflow,
    input  logic stat_busy_in,
    input  logic stat_done_in,
    input  logic data_valid_in,
    output logic stat_busy,
    output logic stat_done,
    output logic stat_overflow,
    output logic stat_underflow,
    output logic stat_data_valid
);

    always_comb begin
        stat_busy      = stat_busy_in;
        stat_done      = stat_done_in;
        stat_overflow  = fifo_overflow;
        stat_underflow = fifo_underflow;
        stat_data_valid= data_valid_in;
    end

endmodule
