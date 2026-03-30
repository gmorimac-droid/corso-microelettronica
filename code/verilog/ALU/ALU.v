module alu #(
    parameter DATA_WIDTH = 8
)(
    input  wire [DATA_WIDTH-1:0] a,
    input  wire [DATA_WIDTH-1:0] b,
    input  wire [2:0]            op,

    output reg  [DATA_WIDTH-1:0] result,
    output reg                   carry,
    output reg                   overflow,
    output wire                  zero
);

    reg [DATA_WIDTH:0] temp;

    localparam OP_ADD = 3'b000;
    localparam OP_SUB = 3'b001;
    localparam OP_AND = 3'b010;
    localparam OP_OR  = 3'b011;
    localparam OP_XOR = 3'b100;
    localparam OP_NOT = 3'b101;
    localparam OP_SHL = 3'b110;
    localparam OP_SHR = 3'b111;

    always @(*) begin
        result   = {DATA_WIDTH{1'b0}};
        carry    = 1'b0;
        overflow = 1'b0;
        temp     = {(DATA_WIDTH+1){1'b0}};

        case (op)
            OP_ADD: begin
                temp     = {1'b0, a} + {1'b0, b};
                result   = temp[DATA_WIDTH-1:0];
                carry    = temp[DATA_WIDTH];
                overflow = (~(a[DATA_WIDTH-1] ^ b[DATA_WIDTH-1])) &
                           (a[DATA_WIDTH-1] ^ result[DATA_WIDTH-1]);
            end

            OP_SUB: begin
                temp     = {1'b0, a} - {1'b0, b};
                result   = temp[DATA_WIDTH-1:0];
                carry    = temp[DATA_WIDTH];
                overflow = (a[DATA_WIDTH-1] ^ b[DATA_WIDTH-1]) &
                           (a[DATA_WIDTH-1] ^ result[DATA_WIDTH-1]);
            end

            OP_AND: begin
                result = a & b;
            end

            OP_OR: begin
                result = a | b;
            end

            OP_XOR: begin
                result = a ^ b;
            end

            OP_NOT: begin
                result = ~a;
            end

            OP_SHL: begin
                result = a << 1;
                carry  = a[DATA_WIDTH-1];
            end

            OP_SHR: begin
                result = a >> 1;
                carry  = a[0];
            end

            default: begin
                result   = {DATA_WIDTH{1'b0}};
                carry    = 1'b0;
                overflow = 1'b0;
            end
        endcase
    end

    assign zero = (result == {DATA_WIDTH{1'b0}});

endmodule