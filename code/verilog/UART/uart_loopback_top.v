module uart_loopback_top #(
    parameter integer CLKS_PER_BIT = 434
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [7:0] tx_data_in,

    output wire       tx_busy,
    output wire       tx_done,

    output wire [7:0] rx_data_out,
    output wire       rx_data_valid,
    output wire       rx_busy,

    output wire       serial_line
);

    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) u_uart_tx (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (start),
        .data_in (tx_data_in),
        .tx      (serial_line),
        .busy    (tx_busy),
        .done    (tx_done)
    );

    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) u_uart_rx (
        .clk       (clk),
        .rst_n     (rst_n),
        .rx        (serial_line),
        .data_out  (rx_data_out),
        .data_valid(rx_data_valid),
        .busy      (rx_busy)
    );

endmodule