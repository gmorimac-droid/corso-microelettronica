module axi_lite_slave_v2 #(
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
    input  wire                               s_axi_rready,

    // User-side control outputs
    output wire                               ctrl_enable,
    output reg                                ctrl_start_pulse,
    output wire [C_S_AXI_DATA_WIDTH-1:0]      wdata_out,

    // User-side status/data inputs
    input  wire                               status_busy,
    input  wire                               status_done,
    input  wire                               status_error,
    input  wire [C_S_AXI_DATA_WIDTH-1:0]      rdata_in
);

    localparam integer ADDR_LSB = 2;
    localparam integer OPT_MEM_ADDR_BITS = 1;

    localparam [1:0] REG_CONTROL = 2'b00; // 0x0
    localparam [1:0] REG_STATUS  = 2'b01; // 0x4
    localparam [1:0] REG_WDATA   = 2'b10; // 0x8
    localparam [1:0] REG_RDATA   = 2'b11; // 0xC

    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;

    reg [C_S_AXI_DATA_WIDTH-1:0] reg_control;
    reg [C_S_AXI_DATA_WIDTH-1:0] reg_wdata;

    wire write_en;
    reg  [C_S_AXI_DATA_WIDTH-1:0] reg_status;
    reg  [C_S_AXI_DATA_WIDTH-1:0] reg_rdata;

    integer byte_index;

    assign write_en    = s_axi_awready && s_axi_awvalid && s_axi_wready && s_axi_wvalid;
    assign ctrl_enable = reg_control[0];
    assign wdata_out   = reg_wdata;

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
    // User-facing mirrors for RO regs
    // ---------------------------
    always @(*) begin
        reg_status = {C_S_AXI_DATA_WIDTH{1'b0}};
        reg_status[0] = status_busy;
        reg_status[1] = status_done;
        reg_status[2] = status_error;

        reg_rdata = rdata_in;
    end

    // ---------------------------
    // Register write logic
    // ---------------------------
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            reg_control      <= {C_S_AXI_DATA_WIDTH{1'b0}};
            reg_wdata        <= {C_S_AXI_DATA_WIDTH{1'b0}};
            ctrl_start_pulse <= 1'b0;
        end else begin
            ctrl_start_pulse <= 1'b0;

            if (write_en) begin
                case (axi_awaddr[ADDR_LSB + OPT_MEM_ADDR_BITS : ADDR_LSB])

                    REG_CONTROL: begin
                        for (byte_index = 0; byte_index < C_S_AXI_DATA_WIDTH/8; byte_index = byte_index + 1) begin
                            if (s_axi_wstrb[byte_index]) begin
                                reg_control[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
                            end
                        end

                        // start treated as pulse on write of bit[1]=1
                        if (s_axi_wstrb[0] && s_axi_wdata[1])
                            ctrl_start_pulse <= 1'b1;
                    end

                    REG_WDATA: begin
                        for (byte_index = 0; byte_index < C_S_AXI_DATA_WIDTH/8; byte_index = byte_index + 1) begin
                            if (s_axi_wstrb[byte_index]) begin
                                reg_wdata[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
                            end
                        end
                    end

                    // STATUS and RDATA are RO from AXI perspective
                    REG_STATUS: begin
                    end

                    REG_RDATA: begin
                    end

                    default: begin
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
                    REG_CONTROL: s_axi_rdata <= reg_control;
                    REG_STATUS : s_axi_rdata <= reg_status;
                    REG_WDATA  : s_axi_rdata <= reg_wdata;
                    REG_RDATA  : s_axi_rdata <= reg_rdata;
                    default    : s_axi_rdata <= {C_S_AXI_DATA_WIDTH{1'b0}};
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule