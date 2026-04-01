module fir8_axi_stream #(parameter int DATA_W=16)(
    input  logic aclk,
    input  logic aresetn,

    input  logic [DATA_W-1:0] s_axis_tdata,
    input  logic s_axis_tvalid,
    output logic s_axis_tready,
    input  logic s_axis_tlast,

    output logic [DATA_W-1:0] m_axis_tdata,
    output logic m_axis_tvalid,
    input  logic m_axis_tready,
    output logic m_axis_tlast
);

    logic [DATA_W-1:0] data;
    logic valid;
    logic last_reg;

    fir8_core u_core(
        .clk(aclk),
        .rstn(aresetn),
        .sample_valid(s_axis_tvalid && s_axis_tready),
        .sample_in(s_axis_tdata),
        .sample_out(data),
        .sample_out_valid(valid)
    );

    assign s_axis_tready = m_axis_tready || !m_axis_tvalid;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            m_axis_tvalid <= 0;
        end else begin
            if (valid && (m_axis_tready || !m_axis_tvalid)) begin
                m_axis_tdata  <= data;
                m_axis_tvalid <= 1;
                m_axis_tlast  <= s_axis_tlast;
            end else if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 0;
            end
        end
    end

endmodule