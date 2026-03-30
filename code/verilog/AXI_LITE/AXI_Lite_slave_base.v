module axi_lite_slave #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 4
)(
    input  wire                               s_axi_aclk,
    input  wire                               s_axi_aresetn,

    // Write address channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]      s_axi_awaddr,
    input  wire                               s_axi_awvalid,
    output reg                                s_axi_awready,

    // Write data channel
    input  wire [C_S_AXI_DATA_WIDTH-1:0]      s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]  s_axi_wstrb,
    input  wire                               s_axi_wvalid,
    output reg                                s_axi_wready,

    // Write response channel
    output reg  [1:0]                         s_axi_bresp,
    output reg                                s_axi_bvalid,
    input  wire                               s_axi_bready,

    // Read address channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]      s_axi_araddr,
    input  wire                               s_axi_arvalid,
    output reg                                s_axi_arready,

    // Read data channel
    output reg [C_S_AXI_DATA_WIDTH-1:0]       s_axi_rdata,
    output reg [1:0]                          s_axi_rresp,
    output reg                                s_axi_rvalid,
    input  wire                               s_axi_rready
);

    localparam integer ADDR_LSB = 2;
    localparam integer OPT_MEM_ADDR_BITS = 1; // 4 regs => 2 bits total word index

    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;

    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg0;
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg1;
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg2;
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg3;

    wire write_en;
    integer byte_index;

    assign write_en = s_axi_awready && s_axi_awvalid && s_axi_wready && s_axi_wvalid;

    // ---------------------------
    // Write address ready
    // ---------------------------
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_awready <= 1'b0;
            axi_awaddr    <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end else begin
            if (!s_axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                s_axi_awready <= 1'b1;
                axi_awaddr    <= s_axi_awaddr;
            end else begin
                s_axi_awready <= 1'b0;
            end
        end
    end

    // ---------------------------
    // Write data ready
    // ---------------------------
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_wready <= 1'b0;
        end else begin
            if (!s_axi_wready && s_axi_wvalid && s_axi_awvalid) begin
                s_axi_wready <= 1'b1;
            end else begin
                s_axi_wready <= 1'b0;
            end
        end
    end

    // ---------------------------
    // Register write logic
    // ---------------------------
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            slv_reg0 <= 32'h00000000;
            slv_reg1 <= 32'h00000000;
            slv_reg2 <= 32'h00000000;
            slv_reg3 <= 32'h00000000;
        end else begin
            if (write_en) begin
                case (axi_awaddr[ADDR_LSB + OPT_MEM_ADDR_BITS : ADDR_LSB])
                    2'b00: begin
                        for (byte_index = 0; byte_index < C_S_AXI_DATA_WIDTH/8; byte_index = byte_index + 1) begin
                            if (s_axi_wstrb[byte_index])
                                slv_reg0[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
                        end
                    end

                    2'b01: begin
                        for (byte_index = 0; byte_index < C_S_AXI_DATA_WIDTH/8; byte_index = byte_index + 1) begin
                            if (s_axi_wstrb[byte_index])
                                slv_reg1[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
                        end
                    end

                    2'b10: begin
                        for (byte_index = 0; byte_index < C_S_AXI_DATA_WIDTH/8; byte_index = byte_index + 1) begin
                            if (s_axi_wstrb[byte_index])
                                slv_reg2[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
                        end
                    end

                    2'b11: begin
                        for (byte_index = 0; byte_index < C_S_AXI_DATA_WIDTH/8; byte_index = byte_index + 1) begin
                            if (s_axi_wstrb[byte_index])
                                slv_reg3[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
                        end
                    end

                    default: begin
                        slv_reg0 <= slv_reg0;
                        slv_reg1 <= slv_reg1;
                        slv_reg2 <= slv_reg2;
                        slv_reg3 <= slv_reg3;
                    end
                endcase
            end
        end
    end

    // ---------------------------
    // Write response
    // ---------------------------
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= 2'b00; // OKAY
        end else begin
            if (write_en && !s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // ---------------------------
    // Read address ready
    // ---------------------------
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 1'b0;
            axi_araddr    <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end else begin
            if (!s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                axi_araddr    <= s_axi_araddr;
            end else begin
                s_axi_arready <= 1'b0;
            end
        end
    end

    // ---------------------------
    // Read data channel
    // ---------------------------
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rresp  <= 2'b00;
            s_axi_rdata  <= {C_S_AXI_DATA_WIDTH{1'b0}};
        end else begin
            if (s_axi_arready && s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;

                case (axi_araddr[ADDR_LSB + OPT_MEM_ADDR_BITS : ADDR_LSB])
                    2'b00: s_axi_rdata <= slv_reg0;
                    2'b01: s_axi_rdata <= slv_reg1;
                    2'b10: s_axi_rdata <= slv_reg2;
                    2'b11: s_axi_rdata <= slv_reg3;
                    default: s_axi_rdata <= 32'h00000000;
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule