module alu_v2 #(
    parameter DATA_WIDTH = 8
)(
    input  wire [DATA_WIDTH-1:0] a,
    input  wire [DATA_WIDTH-1:0] b,
    input  wire [3:0]            op,

    output reg  [DATA_WIDTH-1:0] result,
    output reg                   carry,
    output reg                   overflow,
    output wire                  zero,
    output wire                  negative
);

    reg [DATA_WIDTH:0] temp;

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

            OP_SLT: begin
                result = ($signed(a) < $signed(b)) ? {{(DATA_WIDTH-1){1'b0}}, 1'b1}
                                                   : {DATA_WIDTH{1'b0}};
            end

            OP_SLTU: begin
                result = (a < b) ? {{(DATA_WIDTH-1){1'b0}}, 1'b1}
                                 : {DATA_WIDTH{1'b0}};
            end

            default: begin
                result   = {DATA_WIDTH{1'b0}};
                carry    = 1'b0;
                overflow = 1'b0;
            end
        endcase
    end

    assign zero     = (result == {DATA_WIDTH{1'b0}});
    assign negative = result[DATA_WIDTH-1];

endmodule