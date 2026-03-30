`timescale 1ns/1ps

module tb_axi_lite_slave;

    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 4;

    reg                       s_axi_aclk;
    reg                       s_axi_aresetn;

    reg  [ADDR_WIDTH-1:0]     s_axi_awaddr;
    reg                       s_axi_awvalid;
    wire                      s_axi_awready;

    reg  [DATA_WIDTH-1:0]     s_axi_wdata;
    reg  [(DATA_WIDTH/8)-1:0] s_axi_wstrb;
    reg                       s_axi_wvalid;
    wire                      s_axi_wready;

    wire [1:0]                s_axi_bresp;
    wire                      s_axi_bvalid;
    reg                       s_axi_bready;

    reg  [ADDR_WIDTH-1:0]     s_axi_araddr;
    reg                       s_axi_arvalid;
    wire                      s_axi_arready;

    wire [DATA_WIDTH-1:0]     s_axi_rdata;
    wire [1:0]                s_axi_rresp;
    wire                      s_axi_rvalid;
    reg                       s_axi_rready;

    integer errors;

    axi_lite_slave #(
        .C_S_AXI_DATA_WIDTH(DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .s_axi_aclk    (s_axi_aclk),
        .s_axi_aresetn (s_axi_aresetn),
        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),
        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),
        .s_axi_bresp   (s_axi_bresp),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),
        .s_axi_araddr  (s_axi_araddr),
        .s_axi_arvalid (s_axi_arvalid),
        .s_axi_arready (s_axi_arready),
        .s_axi_rdata   (s_axi_rdata),
        .s_axi_rresp   (s_axi_rresp),
        .s_axi_rvalid  (s_axi_rvalid),
        .s_axi_rready  (s_axi_rready)
    );

    initial begin
        s_axi_aclk = 1'b0;
        forever #5 s_axi_aclk = ~s_axi_aclk;
    end

    task axi_write(
        input [ADDR_WIDTH-1:0] addr,
        input [DATA_WIDTH-1:0] data
    );
    begin
        @(posedge s_axi_aclk);
        s_axi_awaddr  <= addr;
        s_axi_awvalid <= 1'b1;
        s_axi_wdata   <= data;
        s_axi_wstrb   <= 4'hF;
        s_axi_wvalid  <= 1'b1;
        s_axi_bready  <= 1'b1;

        wait(s_axi_awready && s_axi_wready);
        @(posedge s_axi_aclk);
        s_axi_awvalid <= 1'b0;
        s_axi_wvalid  <= 1'b0;

        wait(s_axi_bvalid);
        @(posedge s_axi_aclk);
        s_axi_bready <= 1'b0;
    end
    endtask

    task axi_read(
        input  [ADDR_WIDTH-1:0] addr,
        output [DATA_WIDTH-1:0] data
    );
    begin
        @(posedge s_axi_aclk);
        s_axi_araddr  <= addr;
        s_axi_arvalid <= 1'b1;
        s_axi_rready  <= 1'b1;

        wait(s_axi_arready);
        @(posedge s_axi_aclk);
        s_axi_arvalid <= 1'b0;

        wait(s_axi_rvalid);
        data = s_axi_rdata;
        @(posedge s_axi_aclk);
        s_axi_rready <= 1'b0;
    end
    endtask

    reg [31:0] rd_data;

    initial begin
        errors         = 0;
        s_axi_aresetn  = 1'b0;
        s_axi_awaddr   = 0;
        s_axi_awvalid  = 0;
        s_axi_wdata    = 0;
        s_axi_wstrb    = 0;
        s_axi_wvalid   = 0;
        s_axi_bready   = 0;
        s_axi_araddr   = 0;
        s_axi_arvalid  = 0;
        s_axi_rready   = 0;

        #20;
        s_axi_aresetn = 1'b1;

        axi_write(4'h0, 32'h11223344);
        axi_write(4'h4, 32'hAABBCCDD);
        axi_write(4'h8, 32'h55AA55AA);
        axi_write(4'hC, 32'hDEADBEEF);

        axi_read(4'h0, rd_data);
        if (rd_data !== 32'h11223344) begin
            $display("ERROR reg0 readback: %h", rd_data);
            errors = errors + 1;
        end

        axi_read(4'h4, rd_data);
        if (rd_data !== 32'hAABBCCDD) begin
            $display("ERROR reg1 readback: %h", rd_data);
            errors = errors + 1;
        end

        axi_read(4'h8, rd_data);
        if (rd_data !== 32'h55AA55AA) begin
            $display("ERROR reg2 readback: %h", rd_data);
            errors = errors + 1;
        end

        axi_read(4'hC, rd_data);
        if (rd_data !== 32'hDEADBEEF) begin
            $display("ERROR reg3 readback: %h", rd_data);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("AXI-Lite slave TEST PASSED");
        else
            $display("AXI-Lite slave TEST FAILED - errors = %0d", errors);

        $finish;
    end

endmodule