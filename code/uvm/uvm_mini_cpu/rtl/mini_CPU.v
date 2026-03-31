module mini_cpu (
    input  wire clk,
    input  wire rst_n
);

    localparam DATA_WIDTH   = 8;
    localparam INST_WIDTH   = 16;
    localparam REG_COUNT    = 4;
    localparam REG_ADDR_W   = 2;
    localparam IMEM_DEPTH   = 256;

    // Opcodes
    localparam OP_NOP   = 4'h0;
    localparam OP_LOADI = 4'h1;
    localparam OP_ADD   = 4'h2;
    localparam OP_SUB   = 4'h3;
    localparam OP_AND   = 4'h4;
    localparam OP_OR    = 4'h5;
    localparam OP_XOR   = 4'h6;
    localparam OP_MOV   = 4'h7;
    localparam OP_JMP   = 4'h8;
    localparam OP_JZ    = 4'h9;
    localparam OP_HALT  = 4'hA;

    reg [7:0] pc;
    reg       halted;

    reg [DATA_WIDTH-1:0] regfile [0:REG_COUNT-1];
    reg [INST_WIDTH-1:0] imem    [0:IMEM_DEPTH-1];

    reg zero_flag;

    reg [INST_WIDTH-1:0] instr;
    reg [3:0] opcode;
    reg [REG_ADDR_W-1:0] rd;
    reg [REG_ADDR_W-1:0] rs;
    reg [7:0] imm8;

    reg [DATA_WIDTH-1:0] alu_result;

    integer i;

    // Program initialization
    initial begin
        // Clear program memory
        for (i = 0; i < IMEM_DEPTH; i = i + 1)
            imem[i] = 16'h0000;

        // Example program
        // R0 = 5
        imem[0] = {OP_LOADI, 2'b00, 2'b00, 8'h05};
        // R1 = 3
        imem[1] = {OP_LOADI, 2'b01, 2'b00, 8'h03};
        // R0 = R0 + R1 => 8
        imem[2] = {OP_ADD,   2'b00, 2'b01, 8'h00};
        // R2 = R0
        imem[3] = {OP_MOV,   2'b10, 2'b00, 8'h00};
        // R2 = R2 - R1 => 5
        imem[4] = {OP_SUB,   2'b10, 2'b01, 8'h00};
        // if zero jump to 8 (not taken here)
        imem[5] = {OP_JZ,    2'b00, 2'b00, 8'h08};
        // R3 = 0
        imem[6] = {OP_LOADI, 2'b11, 2'b00, 8'h00};
        // HALT
        imem[7] = {OP_HALT,  2'b00, 2'b00, 8'h00};
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc        <= 8'h00;
            halted    <= 1'b0;
            zero_flag <= 1'b0;
            instr     <= {INST_WIDTH{1'b0}};
            opcode    <= 4'h0;
            rd        <= {REG_ADDR_W{1'b0}};
            rs        <= {REG_ADDR_W{1'b0}};
            imm8      <= 8'h00;
            alu_result<= 8'h00;

            regfile[0] <= 8'h00;
            regfile[1] <= 8'h00;
            regfile[2] <= 8'h00;
            regfile[3] <= 8'h00;
        end else if (!halted) begin
            // Fetch
            instr  = imem[pc];

            // Decode
            opcode = instr[15:12];
            rd     = instr[11:10];
            rs     = instr[9:8];
            imm8   = instr[7:0];

            // Default ALU result
            alu_result = 8'h00;

            // Execute
            case (opcode)
                OP_NOP: begin
                    pc <= pc + 1'b1;
                end

                OP_LOADI: begin
                    regfile[rd] <= imm8;
                    zero_flag   <= (imm8 == 8'h00);
                    pc <= pc + 1'b1;
                end

                OP_ADD: begin
                    alu_result  = regfile[rd] + regfile[rs];
                    regfile[rd] <= alu_result;
                    zero_flag   <= (alu_result == 8'h00);
                    pc <= pc + 1'b1;
                end

                OP_SUB: begin
                    alu_result  = regfile[rd] - regfile[rs];
                    regfile[rd] <= alu_result;
                    zero_flag   <= (alu_result == 8'h00);
                    pc <= pc + 1'b1;
                end

                OP_AND: begin
                    alu_result  = regfile[rd] & regfile[rs];
                    regfile[rd] <= alu_result;
                    zero_flag   <= (alu_result == 8'h00);
                    pc <= pc + 1'b1;
                end

                OP_OR: begin
                    alu_result  = regfile[rd] | regfile[rs];
                    regfile[rd] <= alu_result;
                    zero_flag   <= (alu_result == 8'h00);
                    pc <= pc + 1'b1;
                end

                OP_XOR: begin
                    alu_result  = regfile[rd] ^ regfile[rs];
                    regfile[rd] <= alu_result;
                    zero_flag   <= (alu_result == 8'h00);
                    pc <= pc + 1'b1;
                end

                OP_MOV: begin
                    regfile[rd] <= regfile[rs];
                    zero_flag   <= (regfile[rs] == 8'h00);
                    pc <= pc + 1'b1;
                end

                OP_JMP: begin
                    pc <= imm8;
                end

                OP_JZ: begin
                    if (zero_flag)
                        pc <= imm8;
                    else
                        pc <= pc + 1'b1;
                end

                OP_HALT: begin
                    halted <= 1'b1;
                end

                default: begin
                    pc <= pc + 1'b1;
                end
            endcase
        end
    end

endmodule