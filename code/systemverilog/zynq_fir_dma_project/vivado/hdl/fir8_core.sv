module fir8_core #(parameter int DATA_W=16)(
    input  logic clk,
    input  logic rstn,
    input  logic sample_valid,
    input  logic signed [DATA_W-1:0] sample_in,
    output logic signed [DATA_W-1:0] sample_out,
    output logic sample_out_valid
);

    logic signed [DATA_W-1:0] x[0:7];
    logic signed [15:0] h[0:7];
    integer i;
    logic signed [39:0] acc;

    initial begin
        h = '{-8,0,40,96,96,40,0,-8};
    end

    always_ff @(posedge clk) begin
        if (!rstn) begin
            for(i=0;i<8;i++) x[i]<=0;
        end else if(sample_valid) begin
            for(i=7;i>0;i--) x[i]<=x[i-1];
            x[0] <= sample_in;

            acc = 0;
            for(i=0;i<8;i++) acc += x[i]*h[i];

            sample_out <= acc >>> 8;
            sample_out_valid <= 1;
        end else begin
            sample_out_valid <= 0;
        end
    end
endmodule