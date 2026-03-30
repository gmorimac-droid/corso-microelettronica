`timescale 1ns/1ps

module tb_alu_v2;

    localparam DATA_WIDTH = 8;

    reg  [DATA_WIDTH-1:0] a;
    reg  [DATA_WIDTH-1:0] b;
    reg  [3:0]            op;

    wire [DATA_WIDTH-1:0] result;
    wire                  carry;
    wire                  overflow;
    wire                  zero;
    wire                  negative;

    integer errors;

    localparam OP_ADD  = 4'b0000;
    localparam OP_SUB  = 4'b0001;
    localparam OP_AND  = 4'b0010;
    localparam OP_OR   = 4'b0011;
    localparam OP_XOR  = 4'b0100;
    localparam OP_NOT  = 4'b0101;
    localparam OP_SHL  = 4'b0110;
    localparam OP_SHR  = 4'b0111;
    localparam OP_SLT  = 4'b1000;
    localparam OP_SLTU = 4'b1001;

    alu_v2 #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .a(a),
        .b(b),
        .op(op),
        .result(result),
        .carry(carry),
        .overflow(overflow),
        .zero(zero),
        .negative(negative)
    );

    task check_result;
        input [DATA_WIDTH-1:0] exp_result;
        input                  exp_carry;
        input                  exp_overflow;
        input                  exp_zero;
        input                  exp_negative;
    begin
        #1;
        if (result    !== exp_result   ||
            carry     !== exp_carry    ||
            overflow  !== exp_overflow ||
            zero      !== exp_zero     ||
            negative  !== exp_negative) begin
            $display("ERROR: a=%h b=%h op=%b -> result=%h c=%b ovf=%b z=%b n=%b | expected=%h %b %b %b %b",
                     a, b, op, result, carry, overflow, zero, negative,
                     exp_result, exp_carry, exp_overflow, exp_zero, exp_negative);
            errors = errors + 1;
        end
    end
    endtask

    initial begin
        errors = 0;

        // ADD
        a = 8'h05; b = 8'h03; op = OP_ADD;
        check_result(8'h08, 1'b0, 1'b0, 1'b0, 1'b0);

        // ADD carry
        a = 8'hFF; b = 8'h01; op = OP_ADD;
        check_result(8'h00, 1'b1, 1'b0, 1'b1, 1'b0);

        // ADD signed overflow
        a = 8'h7F; b = 8'h01; op = OP_ADD;
        check_result(8'h80, 1'b0, 1'b1, 1'b0, 1'b1);

        // SUB
        a = 8'h09; b = 8'h04; op = OP_SUB;
        check_result(8'h05, 1'b0, 1'b0, 1'b0, 1'b0);

        // SUB negative result
        a = 8'h03; b = 8'h05; op = OP_SUB;
        check_result(8'hFE, 1'b1, 1'b0, 1'b0, 1'b1);

        // AND
        a = 8'hA5; b = 8'h3C; op = OP_AND;
        check_result(8'h24, 1'b0, 1'b0, 1'b0, 1'b0);

        // OR
        a = 8'hA5; b = 8'h3C; op = OP_OR;
        check_result(8'hBD, 1'b0, 1'b0, 1'b0, 1'b1);

        // XOR -> zero
        a = 8'h55; b = 8'h55; op = OP_XOR;
        check_result(8'h00, 1'b0, 1'b0, 1'b1, 1'b0);

        // NOT
        a = 8'h0F; b = 8'h00; op = OP_NOT;
        check_result(8'hF0, 1'b0, 1'b0, 1'b0, 1'b1);

        // SHL
        a = 8'h81; b = 8'h00; op = OP_SHL;
        check_result(8'h02, 1'b1, 1'b0, 1'b0, 1'b0);

        // SHR
        a = 8'h81; b = 8'h00; op = OP_SHR;
        check_result(8'h40, 1'b1, 1'b0, 1'b0, 1'b0);

        // SLT signed: -1 < 1 -> true
        a = 8'hFF; b = 8'h01; op = OP_SLT;
        check_result(8'h01, 1'b0, 1'b0, 1'b0, 1'b0);

        // SLTU unsigned: 255 < 1 -> false
        a = 8'hFF; b = 8'h01; op = OP_SLTU;
        check_result(8'h00, 1'b0, 1'b0, 1'b1, 1'b0);

        // SLT signed: 2 < 5 -> true
        a = 8'h02; b = 8'h05; op = OP_SLT;
        check_result(8'h01, 1'b0, 1'b0, 1'b0, 1'b0);

        // SLTU unsigned: 2 < 5 -> true
        a = 8'h02; b = 8'h05; op = OP_SLTU;
        check_result(8'h01, 1'b0, 1'b0, 1'b0, 1'b0);

        if (errors == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED - errors = %0d", errors);

        $finish;
    end

endmodule