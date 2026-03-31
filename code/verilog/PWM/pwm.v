module pwm_programmable_buffered #(
    parameter integer WIDTH = 16
)(
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 en,
    input  wire [WIDTH-1:0]     period_in,
    input  wire [WIDTH-1:0]     duty_in,
    output reg                  pwm_out
);

    reg [WIDTH-1:0] counter;
    reg [WIDTH-1:0] period_reg;
    reg [WIDTH-1:0] duty_reg;

    always @(posedge clk) begin
        if (rst) begin
            counter    <= {WIDTH{1'b0}};
            period_reg <= 16'd1;
            duty_reg   <= {WIDTH{1'b0}};
            pwm_out    <= 1'b0;
        end else begin
            if (!en || (period_reg == 0)) begin
                counter <= {WIDTH{1'b0}};
                pwm_out <= 1'b0;
                period_reg <= (period_in == 0) ? 16'd1 : period_in;
                duty_reg   <= duty_in;
            end else begin
                if (counter >= period_reg - 1) begin
                    counter    <= {WIDTH{1'b0}};
                    period_reg <= (period_in == 0) ? 16'd1 : period_in;
                    duty_reg   <= duty_in;
                end else begin
                    counter <= counter + 1'b1;
                end

                if (duty_reg >= period_reg)
                    pwm_out <= 1'b1;
                else if (counter < duty_reg)
                    pwm_out <= 1'b1;
                else
                    pwm_out <= 1'b0;
            end
        end
    end

endmodule