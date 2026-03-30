module axi_lite_auto_init #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32,
    parameter integer BOOT_DELAY = 8
)(
    input  wire                    clk,
    input  wire                    rst_n,

    output reg                     init_done,
    output reg                     init_error,

    // AXI-Lite Master Interface
    output wire [ADDR_WIDTH-1:0]   m_axi_awaddr,
    output wire                    m_axi_awvalid,
    input  wire                    m_axi_awready,

    output wire [DATA_WIDTH-1:0]   m_axi_wdata,
    output wire [(DATA_WIDTH/8)-1:0] m_axi_wstrb,
    output wire                    m_axi_wvalid,
    input  wire                    m_axi_wready,

    input  wire [1:0]              m_axi_bresp,
    input  wire                    m_axi_bvalid,
    output wire                    m_axi_bready,

    output wire [ADDR_WIDTH-1:0]   m_axi_araddr,
    output wire                    m_axi_arvalid,
    input  wire                    m_axi_arready,

    input  wire [DATA_WIDTH-1:0]   m_axi_rdata,
    input  wire [1:0]              m_axi_rresp,
    input  wire                    m_axi_rvalid,
    output wire                    m_axi_rready
);

    localparam [3:0] S_WAIT_BOOT      = 4'd0;
    localparam [3:0] S_WR_WDATA       = 4'd1;
    localparam [3:0] S_WAIT_WR_WDATA  = 4'd2;
    localparam [3:0] S_WR_ENABLE      = 4'd3;
    localparam [3:0] S_WAIT_WR_ENABLE = 4'd4;
    localparam [3:0] S_WR_START       = 4'd5;
    localparam [3:0] S_WAIT_WR_START  = 4'd6;
    localparam [3:0] S_RD_STATUS      = 4'd7;
    localparam [3:0] S_WAIT_RD_STATUS = 4'd8;
    localparam [3:0] S_DONE           = 4'd9;
    localparam [3:0] S_ERROR          = 4'd10;

    localparam [ADDR_WIDTH-1:0] ADDR_CONTROL = 32'h0000_0000;
    localparam [ADDR_WIDTH-1:0] ADDR_STATUS  = 32'h0000_0004;
    localparam [ADDR_WIDTH-1:0] ADDR_WDATA   = 32'h0000_0008;

    reg [3:0] state;
    reg [$clog2(BOOT_DELAY+1)-1:0] boot_count;

    reg                    cmd_start;
    reg                    cmd_rw;     // 0 write, 1 read
    reg [ADDR_WIDTH-1:0]   cmd_addr;
    reg [DATA_WIDTH-1:0]   cmd_wdata;
    wire [DATA_WIDTH-1:0]  cmd_rdata;
    wire                   cmd_busy;
    wire                   cmd_done;
    wire                   cmd_error;

    reg [DATA_WIDTH-1:0]   status_shadow;

    axi_lite_master #(
        .C_M_AXI_ADDR_WIDTH(ADDR_WIDTH),
        .C_M_AXI_DATA_WIDTH(DATA_WIDTH)
    ) u_master (
        .clk(clk),
        .rst_n(rst_n),

        .start(cmd_start),
        .rw(cmd_rw),
        .addr(cmd_addr),
        .wdata(cmd_wdata),
        .rdata(cmd_rdata),
        .busy(cmd_busy),
        .done(cmd_done),
        .error(cmd_error),

        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),

        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),

        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),

        .m_axi_araddr(m_axi_araddr),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),

        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_WAIT_BOOT;
            boot_count    <= 0;
            init_done     <= 1'b0;
            init_error    <= 1'b0;

            cmd_start     <= 1'b0;
            cmd_rw        <= 1'b0;
            cmd_addr      <= {ADDR_WIDTH{1'b0}};
            cmd_wdata     <= {DATA_WIDTH{1'b0}};
            status_shadow <= {DATA_WIDTH{1'b0}};
        end else begin
            cmd_start <= 1'b0;

            case (state)
                S_WAIT_BOOT: begin
                    init_done  <= 1'b0;
                    init_error <= 1'b0;

                    if (boot_count < BOOT_DELAY-1) begin
                        boot_count <= boot_count + 1'b1;
                    end else begin
                        boot_count <= 0;
                        state <= S_WR_WDATA;
                    end
                end

                S_WR_WDATA: begin
                    if (!cmd_busy) begin
                        cmd_rw    <= 1'b0;
                        cmd_addr  <= ADDR_WDATA;
                        cmd_wdata <= 32'h0000_0010;
                        cmd_start <= 1'b1;
                        state     <= S_WAIT_WR_WDATA;
                    end
                end

                S_WAIT_WR_WDATA: begin
                    if (cmd_done) begin
                        if (cmd_error)
                            state <= S_ERROR;
                        else
                            state <= S_WR_ENABLE;
                    end
                end

                S_WR_ENABLE: begin
                    if (!cmd_busy) begin
                        cmd_rw    <= 1'b0;
                        cmd_addr  <= ADDR_CONTROL;
                        cmd_wdata <= 32'h0000_0001; // enable=1
                        cmd_start <= 1'b1;
                        state     <= S_WAIT_WR_ENABLE;
                    end
                end

                S_WAIT_WR_ENABLE: begin
                    if (cmd_done) begin
                        if (cmd_error)
                            state <= S_ERROR;
                        else
                            state <= S_WR_START;
                    end
                end

                S_WR_START: begin
                    if (!cmd_busy) begin
                        cmd_rw    <= 1'b0;
                        cmd_addr  <= ADDR_CONTROL;
                        cmd_wdata <= 32'h0000_0003; // enable=1, start=1
                        cmd_start <= 1'b1;
                        state     <= S_WAIT_WR_START;
                    end
                end

                S_WAIT_WR_START: begin
                    if (cmd_done) begin
                        if (cmd_error)
                            state <= S_ERROR;
                        else
                            state <= S_RD_STATUS;
                    end
                end

                S_RD_STATUS: begin
                    if (!cmd_busy) begin
                        cmd_rw    <= 1'b1;
                        cmd_addr  <= ADDR_STATUS;
                        cmd_wdata <= 32'h0000_0000;
                        cmd_start <= 1'b1;
                        state     <= S_WAIT_RD_STATUS;
                    end
                end

                S_WAIT_RD_STATUS: begin
                    if (cmd_done) begin
                        if (cmd_error) begin
                            state <= S_ERROR;
                        end else begin
                            status_shadow <= cmd_rdata;
                            state <= S_DONE;
                        end
                    end
                end

                S_DONE: begin
                    init_done <= 1'b1;
                    state <= S_DONE;
                end

                S_ERROR: begin
                    init_error <= 1'b1;
                    state <= S_ERROR;
                end

                default: begin
                    state <= S_ERROR;
                end
            endcase
        end
    end

endmodule