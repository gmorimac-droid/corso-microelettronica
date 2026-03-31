module pwm_programmable #(
    parameter int WIDTH = 16
)(
    input  logic             clk,
    input  logic             rst,
    input  logic             en,
    input  logic [WIDTH-1:0] period_in,
    input  logic [WIDTH-1:0] duty_in,
    output logic             pwm_out
);

    logic [WIDTH-1:0] counter;
    logic [WIDTH-1:0] period_reg;
    logic [WIDTH-1:0] duty_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            counter    <= '0;
            period_reg <= 'd1;
            duty_reg   <= '0;
            pwm_out    <= 1'b0;
        end else begin
            if (!en) begin
                counter    <= '0;
                pwm_out    <= 1'b0;
                period_reg <= (period_in == '0) ? 'd1 : period_in;
                duty_reg   <= duty_in;
            end else begin
                if (counter >= period_reg - 1'b1) begin
                    counter    <= '0;
                    period_reg <= (period_in == '0) ? 'd1 : period_in;
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