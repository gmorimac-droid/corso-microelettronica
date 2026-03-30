`timescale 1ns/1ps

module tb_axi_lite_slave_v2;

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

    wire                      ctrl_enable;
    wire                      ctrl_start_pulse;
    wire [DATA_WIDTH-1:0]     wdata_out;

    reg                       status_busy;
    reg                       status_done;
    reg                       status_error;
    reg  [DATA_WIDTH-1:0]     rdata_in;

    integer errors;
    reg [31:0] rd_data;
    integer op_countdown;

    axi_lite_slave_v2 #(
        .C_S_AXI_DATA_WIDTH(DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .s_axi_aclk       (s_axi_aclk),
        .s_axi_aresetn    (s_axi_aresetn),
        .s_axi_awaddr     (s_axi_awaddr),
        .s_axi_awvalid    (s_axi_awvalid),
        .s_axi_awready    (s_axi_awready),
        .s_axi_wdata      (s_axi_wdata),
        .s_axi_wstrb      (s_axi_wstrb),
        .s_axi_wvalid     (s_axi_wvalid),
        .s_axi_wready     (s_axi_wready),
        .s_axi_bresp      (s_axi_bresp),
        .s_axi_bvalid     (s_axi_bvalid),
        .s_axi_bready     (s_axi_bready),
        .s_axi_araddr     (s_axi_araddr),
        .s_axi_arvalid    (s_axi_arvalid),
        .s_axi_arready    (s_axi_arready),
        .s_axi_rdata      (s_axi_rdata),
        .s_axi_rresp      (s_axi_rresp),
        .s_axi_rvalid     (s_axi_rvalid),
        .s_axi_rready     (s_axi_rready),
        .ctrl_enable      (ctrl_enable),
        .ctrl_start_pulse (ctrl_start_pulse),
        .wdata_out        (wdata_out),
        .status_busy      (status_busy),
        .status_done      (status_done),
        .status_error     (status_error),
        .rdata_in         (rdata_in)
    );

    initial begin
        s_axi_aclk = 1'b0;
        forever #5 s_axi_aclk = ~s_axi_aclk;
    end

    // Mock user logic:
    // when ctrl_start_pulse && ctrl_enable => busy for 3 cycles, then done and rdata = wdata + 1
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            status_busy <= 1'b0;
            status_done <= 1'b0;
            status_error <= 1'b0;
            rdata_in <= 32'h0;
            op_countdown <= 0;
        end else begin
            status_done <= 1'b0;

            if (ctrl_start_pulse && ctrl_enable && !status_busy) begin
                status_busy <= 1'b1;
                op_countdown <= 3;
            end else if (status_busy) begin
                if (op_countdown > 1) begin
                    op_countdown <= op_countdown - 1;
                end else begin
                    status_busy <= 1'b0;
                    status_done <= 1'b1;
                    rdata_in <= wdata_out + 32'h1;
                    op_countdown <= 0;
                end
            end
        end
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

        status_busy    = 0;
        status_done    = 0;
        status_error   = 0;
        rdata_in       = 0;

        #20;
        s_axi_aresetn = 1'b1;

        // Write WDATA = 0x10
        axi_write(4'h8, 32'h00000010);

        // Enable block
        axi_write(4'h0, 32'h00000001);

        // Start pulse
        axi_write(4'h0, 32'h00000003);

        // Check that enable is latched
        axi_read(4'h0, rd_data);
        if (rd_data[0] !== 1'b1) begin
            $display("ERROR: enable bit not set");
            errors = errors + 1;
        end

        // Poll STATUS until done
        repeat (10) begin
            axi_read(4'h4, rd_data);
            if (rd_data[1]) begin
                disable poll_done_block;
            end
        end

        poll_done_block: begin
            repeat (10) begin
                axi_read(4'h4, rd_data);
                if (rd_data[1]) begin
                    disable poll_done_block;
                end
            end
        end

        axi_read(4'h4, rd_data);
        if (rd_data[1] !== 1'b1) begin
            $display("ERROR: done bit not observed");
            errors = errors + 1;
        end

        axi_read(4'hC, rd_data);
        if (rd_data !== 32'h00000011) begin
            $display("ERROR: rdata mismatch. got=%h expected=00000011", rd_data);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("AXI-Lite slave v2 TEST PASSED");
        else
            $display("AXI-Lite slave v2 TEST FAILED - errors = %0d", errors);

        $finish;
    end

endmodule