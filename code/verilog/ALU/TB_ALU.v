`timescale 1ns/1ps

module tb_alu;

    localparam DATA_WIDTH = 8;

    reg  [DATA_WIDTH-1:0] a;
    reg  [DATA_WIDTH-1:0] b;
    reg  [2:0]            op;

    wire [DATA_WIDTH-1:0] result;
    wire                  carry;
    wire                  overflow;
    wire                  zero;

    integer errors;

    localparam OP_ADD = 3'b000;
    localparam OP_SUB = 3'b001;
    localparam OP_AND = 3'b010;
    localparam OP_OR  = 3'b011;
    localparam OP_XOR = 3'b100;
    localparam OP_NOT = 3'b101;
    localparam OP_SHL = 3'b110;
    localparam OP_SHR = 3'b111;

    alu #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .a(a),
        .b(b),
        .op(op),
        .result(result),
        .carry(carry),
        .overflow(overflow),
        .zero(zero)
    );

    task check_result;
        input [DATA_WIDTH-1:0] exp_result;
        input                  exp_carry;
        input                  exp_overflow;
        input                  exp_zero;
    begin
        #1;
        if (result !== exp_result ||
            carry  !== exp_carry ||
            overflow !== exp_overflow ||
            zero   !== exp_zero) begin
            $display("ERROR: a=%h b=%h op=%b -> result=%h carry=%b ovf=%b zero=%b | expected=%h %b %b %b",
                     a, b, op, result, carry, overflow, zero,
                     exp_result, exp_carry, exp_overflow, exp_zero);
            errors = errors + 1;
        end
    end
    endtask

    initial begin
        errors = 0;

        // ADD
        a = 8'h05; b = 8'h03; op = OP_ADD;
        check_result(8'h08, 1'b0, 1'b0, 1'b0);

        // ADD with carry
        a = 8'hFF; b = 8'h01; op = OP_ADD;
        check_result(8'h00, 1'b1, 1'b0, 1'b1);

        // ADD with signed overflow
        a = 8'h7F; b = 8'h01; op = OP_ADD;
        check_result(8'h80, 1'b0, 1'b1, 1'b0);

        // SUB
        a = 8'h09; b = 8'h04; op = OP_SUB;
        check_result(8'h05, 1'b0, 1'b0, 1'b0);

        // AND
        a = 8'hA5; b = 8'h3C; op = OP_AND;
        check_result(8'h24, 1'b0, 1'b0, 1'b0);

        // OR
        a = 8'hA5; b = 8'h3C; op = OP_OR;
        check_result(8'hBD, 1'b0, 1'b0, 1'b0);

        // XOR
        a = 8'hA5; b = 8'h3C; op = OP_XOR;
        check_result(8'h99, 1'b0, 1'b0, 1'b0);

        // NOT
        a = 8'h0F; b = 8'h00; op = OP_NOT;
        check_result(8'hF0, 1'b0, 1'b0, 1'b0);

        // SHL
        a = 8'h81; b = 8'h00; op = OP_SHL;
        check_result(8'h02, 1'b1, 1'b0, 1'b0);

        // SHR
        a = 8'h81; b = 8'h00; op = OP_SHR;
        check_result(8'h40, 1'b1, 1'b0, 1'b0);

        // ZERO
        a = 8'h55; b = 8'h55; op = OP_XOR;
        check_result(8'h00, 1'b0, 1'b0, 1'b1);

        if (errors == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED - errors = %0d", errors);

        $finish;
    end

endmodule