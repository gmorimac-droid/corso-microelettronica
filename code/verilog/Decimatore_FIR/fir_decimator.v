module fir_decimator #(
    parameter integer DATA_WIDTH   = 16,
    parameter integer COEFF_WIDTH  = 16,
    parameter integer ACC_WIDTH    = 40,
    parameter integer DECIM_FACTOR = 4,
    parameter integer COEFF_SHIFT  = 8,   // coeff scalati di 2^8
    parameter integer NTAPS        = 8
)(
    input  wire                            clk,
    input  wire                            rst,
    input  wire                            din_valid,
    input  wire signed [DATA_WIDTH-1:0]    din,
    output reg                             dout_valid,
    output reg signed [DATA_WIDTH-1:0]     dout
);

    reg signed [DATA_WIDTH-1:0] samples [0:NTAPS-2];
    reg [$clog2(DECIM_FACTOR)-1:0] decim_count;

    integer i;
    reg signed [ACC_WIDTH-1:0] acc;

    // Coefficienti FIR esempio:
    // [-8, 0, 40, 96, 96, 40, 0, -8]
    // Somma = 256, quindi si normalizza con >> 8
    function signed [COEFF_WIDTH-1:0] coeff;
        input integer idx;
        begin
            case (idx)
                0: coeff = -16'sd8;
                1: coeff =  16'sd0;
                2: coeff =  16'sd40;
                3: coeff =  16'sd96;
                4: coeff =  16'sd96;
                5: coeff =  16'sd40;
                6: coeff =  16'sd0;
                7: coeff = -16'sd8;
                default: coeff = {COEFF_WIDTH{1'b0}};
            endcase
        end
    endfunction

    reg signed [ACC_WIDTH-1:0] acc_next;
    reg signed [DATA_WIDTH-1:0] dout_next;

    always @(posedge clk) begin
        if (rst) begin
            dout       <= '0;
            dout_valid <= 1'b0;
            decim_count <= '0;

            for (i = 0; i < NTAPS-1; i = i + 1)
                samples[i] <= '0;
        end else begin
            dout_valid <= 1'b0;

            if (din_valid) begin
                // FIR calcolato sulla finestra "nuova":
                // tap0 usa din corrente, i successivi usano i campioni precedenti
                acc_next = din * coeff(0);
                for (i = 1; i < NTAPS; i = i + 1)
                    acc_next = acc_next + samples[i-1] * coeff(i);

                // normalizzazione / scaling
                dout_next = acc_next >>> COEFF_SHIFT;

                // shift register dei campioni
                for (i = NTAPS-2; i > 0; i = i - 1)
                    samples[i] <= samples[i-1];
                samples[0] <= din;

                // decimazione
                if (decim_count == DECIM_FACTOR-1) begin
                    dout       <= dout_next;
                    dout_valid <= 1'b1;
                    decim_count <= '0;
                end else begin
                    decim_count <= decim_count + 1'b1;
                end
            end
        end
    end

endmodule