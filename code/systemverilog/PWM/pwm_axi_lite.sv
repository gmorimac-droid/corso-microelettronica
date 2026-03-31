module pwm_axi_lite #(
    parameter int C_S_AXI_DATA_WIDTH = 32,
    parameter int C_S_AXI_ADDR_WIDTH = 4,
    parameter int PWM_WIDTH          = 16
)(
    input  logic                             s_axi_aclk,
    input  logic                             s_axi_aresetn,

    input  logic [C_S_AXI_ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  logic                             s_axi_awvalid,
    output logic                             s_axi_awready,

    input  logic [C_S_AXI_DATA_WIDTH-1:0]    s_axi_wdata,
    input  logic [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  logic                             s_axi_wvalid,
    output logic                             s_axi_wready,

    output logic [1:0]                       s_axi_bresp,
    output logic                             s_axi_bvalid,
    input  logic                             s_axi_bready,

    input  logic [C_S_AXI_ADDR_WIDTH-1:0]    s_axi_araddr,
    input  logic                             s_axi_arvalid,
    output logic                             s_axi_arready,

    output logic [C_S_AXI_DATA_WIDTH-1:0]    s_axi_rdata,
    output logic [1:0]                       s_axi_rresp,
    output logic                             s_axi_rvalid,
    input  logic                             s_axi_rready,

    output logic                             pwm_out
);

    localparam int ADDR_LSB = 2;
    localparam int OPT_MEM_ADDR_BITS = 1;

    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg0;
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg1;
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg2;
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg3;

    logic [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    logic [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;

    logic pwm_en;
    logic [PWM_WIDTH-1:0] pwm_period;
    logic [PWM_WIDTH-1:0] pwm_duty;

    logic [C_S_AXI_DATA_WIDTH-1:0] reg_data_out;

    assign pwm_en     = slv_reg0[0];
    assign pwm_period = slv_reg1[PWM_WIDTH-1:0];
    assign pwm_duty   = slv_reg2[PWM_WIDTH-1:0];

    pwm_core #(
        .WIDTH(PWM_WIDTH)
    ) u_pwm_core (
        .clk      (s_axi_aclk),
        .rstn     (s_axi_aresetn),
        .en       (pwm_en),
        .period_in(pwm_period),
        .duty_in  (pwm_duty),
        .pwm_out  (pwm_out)
    );

    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn)
            slv_reg3 <= '0;
        else begin
            slv_reg3 <= '0;
            slv_reg3[0] <= pwm_out;
        end
    end

    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn)
            s_axi_awready <= 1'b0;
        else if (!s_axi_awready && s_axi_awvalid && s_axi_wvalid)
            s_axi_awready <= 1'b1;
        else
            s_axi_awready <= 1'b0;
    end

    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn)
            axi_awaddr <= '0;
        else if (!s_axi_awready && s_axi_awvalid && s_axi_wvalid)
            axi_awaddr <= s_axi_awaddr;
    end

    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn)
            s_axi_wready <= 1'b0;
        else if (!s_axi_wready && s_axi_wvalid && s_axi_awvalid)
            s_axi_wready <= 1'b1;
        else
            s_axi_wready <= 1'b0;
    end

    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            slv_reg0 <= '0;
            slv_reg1 <= '0;
            slv_reg2 <= '0;
        end else if (s_axi_awready && s_axi_awvalid && s_axi_wready && s_axi_wvalid) begin
            unique case (axi_awaddr[ADDR_LSB + OPT_MEM_ADDR_BITS : ADDR_LSB])
                2'b00: for (int i = 0; i < C_S_AXI_DATA_WIDTH/8; i++)
                           if (s_axi_wstrb[i]) slv_reg0[i*8 +: 8] <= s_axi_wdata[i*8 +: 8];
                2'b01: for (int i = 0; i < C_S_AXI_DATA_WIDTH/8; i++)
                           if (s_axi_wstrb[i]) slv_reg1[i*8 +: 8] <= s_axi_wdata[i*8 +: 8];
                2'b10: for (int i = 0; i < C_S_AXI_DATA_WIDTH/8; i++)
                           if (s_axi_wstrb[i]) slv_reg2[i*8 +: 8] <= s_axi_wdata[i*8 +: 8];
                default: begin end
            endcase
        end
    end

    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= 2'b00;
        end else if (s_axi_awready && s_axi_awvalid && !s_axi_bvalid && s_axi_wready && s_axi_wvalid) begin
            s_axi_bvalid <= 1'b1;
            s_axi_bresp  <= 2'b00;
        end else if (s_axi_bvalid && s_axi_bready) begin
            s_axi_bvalid <= 1'b0;
        end
    end

    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 1'b0;
            axi_araddr    <= '0;
        end else if (!s_axi_arready && s_axi_arvalid) begin
            s_axi_arready <= 1'b1;
            axi_araddr    <= s_axi_araddr;
        end else begin
            s_axi_arready <= 1'b0;
        end
    end

    always_comb begin
        unique case (axi_araddr[ADDR_LSB + OPT_MEM_ADDR_BITS : ADDR_LSB])
            2'b00: reg_data_out = slv_reg0;
            2'b01: reg_data_out = slv_reg1;
            2'b10: reg_data_out = slv_reg2;
            2'b11: reg_data_out = slv_reg3;
            default: reg_data_out = '0;
        endcase
    end

    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rresp  <= 2'b00;
            s_axi_rdata  <= '0;
        end else if (s_axi_arready && s_axi_arvalid && !s_axi_rvalid) begin
            s_axi_rvalid <= 1'b1;
            s_axi_rresp  <= 2'b00;
            s_axi_rdata  <= reg_data_out;
        end else if (s_axi_rvalid && s_axi_rready) begin
            s_axi_rvalid <= 1'b0;
        end
    end

endmodule