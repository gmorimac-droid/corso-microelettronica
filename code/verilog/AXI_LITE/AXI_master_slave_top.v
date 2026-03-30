module axi_master_slave_top #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32
)(
    input  wire                    clk,
    input  wire                    rst_n,

    // Local command interface to master
    input  wire                    cmd_start,
    input  wire                    cmd_rw,       // 0 = write, 1 = read
    input  wire [ADDR_WIDTH-1:0]   cmd_addr,
    input  wire [DATA_WIDTH-1:0]   cmd_wdata,
    output wire [DATA_WIDTH-1:0]   cmd_rdata,
    output wire                    cmd_busy,
    output wire                    cmd_done,
    output wire                    cmd_error
);

    // -------------------------
    // AXI wires between master and slave
    // -------------------------
    wire [ADDR_WIDTH-1:0]     axi_awaddr;
    wire                      axi_awvalid;
    wire                      axi_awready;

    wire [DATA_WIDTH-1:0]     axi_wdata;
    wire [(DATA_WIDTH/8)-1:0] axi_wstrb;
    wire                      axi_wvalid;
    wire                      axi_wready;

    wire [1:0]                axi_bresp;
    wire                      axi_bvalid;
    wire                      axi_bready;

    wire [ADDR_WIDTH-1:0]     axi_araddr;
    wire                      axi_arvalid;
    wire                      axi_arready;

    wire [DATA_WIDTH-1:0]     axi_rdata;
    wire [1:0]                axi_rresp;
    wire                      axi_rvalid;
    wire                      axi_rready;

    // -------------------------
    // User-side wires from slave
    // -------------------------
    wire                      ctrl_enable;
    wire                      ctrl_start_pulse;
    wire [DATA_WIDTH-1:0]     wdata_out;

    reg                       status_busy;
    reg                       status_done;
    reg                       status_error;
    reg  [DATA_WIDTH-1:0]     rdata_in;

    integer op_countdown;

    // -------------------------
    // AXI Master
    // -------------------------
    axi_lite_master #(
        .C_M_AXI_ADDR_WIDTH(ADDR_WIDTH),
        .C_M_AXI_DATA_WIDTH(DATA_WIDTH)
    ) u_master (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (cmd_start),
        .rw            (cmd_rw),
        .addr          (cmd_addr),
        .wdata         (cmd_wdata),
        .rdata         (cmd_rdata),
        .busy          (cmd_busy),
        .done          (cmd_done),
        .error         (cmd_error),

        .m_axi_awaddr  (axi_awaddr),
        .m_axi_awvalid (axi_awvalid),
        .m_axi_awready (axi_awready),

        .m_axi_wdata   (axi_wdata),
        .m_axi_wstrb   (axi_wstrb),
        .m_axi_wvalid  (axi_wvalid),
        .m_axi_wready  (axi_wready),

        .m_axi_bresp   (axi_bresp),
        .m_axi_bvalid  (axi_bvalid),
        .m_axi_bready  (axi_bready),

        .m_axi_araddr  (axi_araddr),
        .m_axi_arvalid (axi_arvalid),
        .m_axi_arready (axi_arready),

        .m_axi_rdata   (axi_rdata),
        .m_axi_rresp   (axi_rresp),
        .m_axi_rvalid  (axi_rvalid),
        .m_axi_rready  (axi_rready)
    );

    // -------------------------
    // AXI Slave v2
    // Note: slave expects a small local address width.
    // We connect only the lower 4 bits.
    // -------------------------
    axi_lite_slave_v2 #(
        .C_S_AXI_DATA_WIDTH(DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(4)
    ) u_slave (
        .s_axi_aclk       (clk),
        .s_axi_aresetn    (rst_n),

        .s_axi_awaddr     (axi_awaddr[3:0]),
        .s_axi_awvalid    (axi_awvalid),
        .s_axi_awready    (axi_awready),

        .s_axi_wdata      (axi_wdata),
        .s_axi_wstrb      (axi_wstrb),
        .s_axi_wvalid     (axi_wvalid),
        .s_axi_wready     (axi_wready),

        .s_axi_bresp      (axi_bresp),
        .s_axi_bvalid     (axi_bvalid),
        .s_axi_bready     (axi_bready),

        .s_axi_araddr     (axi_araddr[3:0]),
        .s_axi_arvalid    (axi_arvalid),
        .s_axi_arready    (axi_arready),

        .s_axi_rdata      (axi_rdata),
        .s_axi_rresp      (axi_rresp),
        .s_axi_rvalid     (axi_rvalid),
        .s_axi_rready     (axi_rready),

        .ctrl_enable      (ctrl_enable),
        .ctrl_start_pulse (ctrl_start_pulse),
        .wdata_out        (wdata_out),

        .status_busy      (status_busy),
        .status_done      (status_done),
        .status_error     (status_error),
        .rdata_in         (rdata_in)
    );

    // -------------------------
    // Mock user logic
    // Behavior:
    // if ctrl_start_pulse && ctrl_enable -> busy for 3 cycles
    // then done pulses and rdata_in = wdata_out + 1
    // -------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            status_busy  <= 1'b0;
            status_done  <= 1'b0;
            status_error <= 1'b0;
            rdata_in     <= {DATA_WIDTH{1'b0}};
            op_countdown <= 0;
        end else begin
            status_done <= 1'b0;

            if (ctrl_start_pulse && ctrl_enable && !status_busy) begin
                status_busy  <= 1'b1;
                op_countdown <= 3;
            end else if (status_busy) begin
                if (op_countdown > 1) begin
                    op_countdown <= op_countdown - 1;
                end else begin
                    status_busy  <= 1'b0;
                    status_done  <= 1'b1;
                    rdata_in     <= wdata_out + 32'h1;
                    op_countdown <= 0;
                end
            end
        end
    end

endmodule