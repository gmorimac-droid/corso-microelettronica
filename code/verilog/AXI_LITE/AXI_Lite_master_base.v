module axi_lite_master #(
    parameter integer C_M_AXI_ADDR_WIDTH = 32,
    parameter integer C_M_AXI_DATA_WIDTH = 32
)(
    input  wire                               clk,
    input  wire                               rst_n,

    // Local command interface
    input  wire                               start,
    input  wire                               rw,        // 0 = write, 1 = read
    input  wire [C_M_AXI_ADDR_WIDTH-1:0]      addr,
    input  wire [C_M_AXI_DATA_WIDTH-1:0]      wdata,
    output reg  [C_M_AXI_DATA_WIDTH-1:0]      rdata,
    output reg                                busy,
    output reg                                done,
    output reg                                error,

    // AXI-Lite Master Interface

    // Write address channel
    output reg  [C_M_AXI_ADDR_WIDTH-1:0]      m_axi_awaddr,
    output reg                                m_axi_awvalid,
    input  wire                               m_axi_awready,

    // Write data channel
    output reg  [C_M_AXI_DATA_WIDTH-1:0]      m_axi_wdata,
    output reg  [(C_M_AXI_DATA_WIDTH/8)-1:0]  m_axi_wstrb,
    output reg                                m_axi_wvalid,
    input  wire                               m_axi_wready,

    // Write response channel
    input  wire [1:0]                         m_axi_bresp,
    input  wire                               m_axi_bvalid,
    output reg                                m_axi_bready,

    // Read address channel
    output reg  [C_M_AXI_ADDR_WIDTH-1:0]      m_axi_araddr,
    output reg                                m_axi_arvalid,
    input  wire                               m_axi_arready,

    // Read data channel
    input  wire [C_M_AXI_DATA_WIDTH-1:0]      m_axi_rdata,
    input  wire [1:0]                         m_axi_rresp,
    input  wire                               m_axi_rvalid,
    output reg                                m_axi_rready
);

    localparam [2:0] S_IDLE             = 3'd0;
    localparam [2:0] S_WRITE_ADDR_DATA  = 3'd1;
    localparam [2:0] S_WRITE_RESP       = 3'd2;
    localparam [2:0] S_READ_ADDR        = 3'd3;
    localparam [2:0] S_READ_DATA        = 3'd4;
    localparam [2:0] S_DONE             = 3'd5;

    reg [2:0] state;

    reg [C_M_AXI_ADDR_WIDTH-1:0] cmd_addr;
    reg [C_M_AXI_DATA_WIDTH-1:0] cmd_wdata;
    reg                          cmd_rw;

    wire write_addr_hs;
    wire write_data_hs;
    wire write_resp_hs;
    wire read_addr_hs;
    wire read_data_hs;

    assign write_addr_hs = m_axi_awvalid && m_axi_awready;
    assign write_data_hs = m_axi_wvalid  && m_axi_wready;
    assign write_resp_hs = m_axi_bvalid  && m_axi_bready;
    assign read_addr_hs  = m_axi_arvalid && m_axi_arready;
    assign read_data_hs  = m_axi_rvalid  && m_axi_rready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            busy          <= 1'b0;
            done          <= 1'b0;
            error         <= 1'b0;
            rdata         <= {C_M_AXI_DATA_WIDTH{1'b0}};

            cmd_addr      <= {C_M_AXI_ADDR_WIDTH{1'b0}};
            cmd_wdata     <= {C_M_AXI_DATA_WIDTH{1'b0}};
            cmd_rw        <= 1'b0;

            m_axi_awaddr  <= {C_M_AXI_ADDR_WIDTH{1'b0}};
            m_axi_awvalid <= 1'b0;

            m_axi_wdata   <= {C_M_AXI_DATA_WIDTH{1'b0}};
            m_axi_wstrb   <= {(C_M_AXI_DATA_WIDTH/8){1'b1}};
            m_axi_wvalid  <= 1'b0;

            m_axi_bready  <= 1'b0;

            m_axi_araddr  <= {C_M_AXI_ADDR_WIDTH{1'b0}};
            m_axi_arvalid <= 1'b0;

            m_axi_rready  <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    busy <= 1'b0;
                    error <= 1'b0;

                    m_axi_awvalid <= 1'b0;
                    m_axi_wvalid  <= 1'b0;
                    m_axi_bready  <= 1'b0;
                    m_axi_arvalid <= 1'b0;
                    m_axi_rready  <= 1'b0;

                    if (start) begin
                        busy      <= 1'b1;
                        cmd_addr  <= addr;
                        cmd_wdata <= wdata;
                        cmd_rw    <= rw;

                        if (rw == 1'b0) begin
                            // Write command
                            m_axi_awaddr  <= addr;
                            m_axi_awvalid <= 1'b1;
                            m_axi_wdata   <= wdata;
                            m_axi_wstrb   <= {(C_M_AXI_DATA_WIDTH/8){1'b1}};
                            m_axi_wvalid  <= 1'b1;
                            state         <= S_WRITE_ADDR_DATA;
                        end else begin
                            // Read command
                            m_axi_araddr  <= addr;
                            m_axi_arvalid <= 1'b1;
                            state         <= S_READ_ADDR;
                        end
                    end
                end

                S_WRITE_ADDR_DATA: begin
                    // AW channel
                    if (write_addr_hs)
                        m_axi_awvalid <= 1'b0;

                    // W channel
                    if (write_data_hs)
                        m_axi_wvalid <= 1'b0;

                    if ((!m_axi_awvalid || write_addr_hs) &&
                        (!m_axi_wvalid  || write_data_hs)) begin
                        m_axi_bready <= 1'b1;
                        state        <= S_WRITE_RESP;
                    end
                end

                S_WRITE_RESP: begin
                    if (write_resp_hs) begin
                        m_axi_bready <= 1'b0;

                        if (m_axi_bresp != 2'b00)
                            error <= 1'b1;

                        state <= S_DONE;
                    end
                end

                S_READ_ADDR: begin
                    if (read_addr_hs) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                        state         <= S_READ_DATA;
                    end
                end

                S_READ_DATA: begin
                    if (read_data_hs) begin
                        m_axi_rready <= 1'b0;
                        rdata        <= m_axi_rdata;

                        if (m_axi_rresp != 2'b00)
                            error <= 1'b1;

                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule