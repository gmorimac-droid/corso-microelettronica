`timescale 1ns/1ps

module tb_axi_lite_master;

    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;

    reg                      clk;
    reg                      rst_n;

    reg                      start;
    reg                      rw;
    reg  [ADDR_WIDTH-1:0]    addr;
    reg  [DATA_WIDTH-1:0]    wdata;
    wire [DATA_WIDTH-1:0]    rdata;
    wire                     busy;
    wire                     done;
    wire                     error;

    wire [ADDR_WIDTH-1:0]    m_axi_awaddr;
    wire                     m_axi_awvalid;
    reg                      m_axi_awready;

    wire [DATA_WIDTH-1:0]    m_axi_wdata;
    wire [(DATA_WIDTH/8)-1:0] m_axi_wstrb;
    wire                     m_axi_wvalid;
    reg                      m_axi_wready;

    reg  [1:0]               m_axi_bresp;
    reg                      m_axi_bvalid;
    wire                     m_axi_bready;

    wire [ADDR_WIDTH-1:0]    m_axi_araddr;
    wire                     m_axi_arvalid;
    reg                      m_axi_arready;

    reg  [DATA_WIDTH-1:0]    m_axi_rdata;
    reg  [1:0]               m_axi_rresp;
    reg                      m_axi_rvalid;
    wire                     m_axi_rready;

    reg [31:0] mem [0:3];
    integer errors;

    axi_lite_master #(
        .C_M_AXI_ADDR_WIDTH(ADDR_WIDTH),
        .C_M_AXI_DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .rw(rw),
        .addr(addr),
        .wdata(wdata),
        .rdata(rdata),
        .busy(busy),
        .done(done),
        .error(error),
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

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Very simple AXI-Lite slave model
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axi_awready <= 1'b0;
            m_axi_wready  <= 1'b0;
            m_axi_bvalid  <= 1'b0;
            m_axi_bresp   <= 2'b00;
            m_axi_arready <= 1'b0;
            m_axi_rvalid  <= 1'b0;
            m_axi_rresp   <= 2'b00;
            m_axi_rdata   <= 32'h0;

            mem[0] <= 32'h0;
            mem[1] <= 32'h0;
            mem[2] <= 32'h0;
            mem[3] <= 32'h0;
        end else begin
            m_axi_awready <= 1'b0;
            m_axi_wready  <= 1'b0;
            m_axi_arready <= 1'b0;

            // Write accept
            if (m_axi_awvalid && m_axi_wvalid && !m_axi_bvalid) begin
                m_axi_awready <= 1'b1;
                m_axi_wready  <= 1'b1;

                case (m_axi_awaddr[3:2])
                    2'b00: mem[0] <= m_axi_wdata;
                    2'b01: mem[1] <= m_axi_wdata;
                    2'b10: mem[2] <= m_axi_wdata;
                    2'b11: mem[3] <= m_axi_wdata;
                endcase

                m_axi_bvalid <= 1'b1;
                m_axi_bresp  <= 2'b00;
            end else if (m_axi_bvalid && m_axi_bready) begin
                m_axi_bvalid <= 1'b0;
            end

            // Read accept
            if (m_axi_arvalid && !m_axi_rvalid) begin
                m_axi_arready <= 1'b1;

                case (m_axi_araddr[3:2])
                    2'b00: m_axi_rdata <= mem[0];
                    2'b01: m_axi_rdata <= mem[1];
                    2'b10: m_axi_rdata <= mem[2];
                    2'b11: m_axi_rdata <= mem[3];
                endcase

                m_axi_rvalid <= 1'b1;
                m_axi_rresp  <= 2'b00;
            end else if (m_axi_rvalid && m_axi_rready) begin
                m_axi_rvalid <= 1'b0;
            end
        end
    end

    task do_write(
        input [ADDR_WIDTH-1:0] wr_addr,
        input [DATA_WIDTH-1:0] wr_data
    );
    begin
        @(posedge clk);
        start <= 1'b1;
        rw    <= 1'b0;
        addr  <= wr_addr;
        wdata <= wr_data;

        @(posedge clk);
        start <= 1'b0;

        wait(done);
        @(posedge clk);
    end
    endtask

    task do_read(
        input  [ADDR_WIDTH-1:0] rd_addr,
        output [DATA_WIDTH-1:0] rd_data
    );
    begin
        @(posedge clk);
        start <= 1'b1;
        rw    <= 1'b1;
        addr  <= rd_addr;
        wdata <= 32'h0;

        @(posedge clk);
        start <= 1'b0;

        wait(done);
        rd_data = rdata;
        @(posedge clk);
    end
    endtask

    reg [31:0] tmp;

    initial begin
        errors = 0;
        rst_n  = 1'b0;
        start  = 1'b0;
        rw     = 1'b0;
        addr   = 32'h0;
        wdata  = 32'h0;

        #20;
        rst_n = 1'b1;

        do_write(32'h0000_0000, 32'h11223344);
        do_write(32'h0000_0004, 32'hAABBCCDD);

        do_read(32'h0000_0000, tmp);
        if (tmp !== 32'h11223344) begin
            $display("ERROR readback 0 = %h", tmp);
            errors = errors + 1;
        end

        do_read(32'h0000_0004, tmp);
        if (tmp !== 32'hAABBCCDD) begin
            $display("ERROR readback 1 = %h", tmp);
            errors = errors + 1;
        end

        if (error) begin
            $display("ERROR flag unexpectedly set");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("AXI-Lite master TEST PASSED");
        else
            $display("AXI-Lite master TEST FAILED - errors = %0d", errors);

        $finish;
    end

endmodule