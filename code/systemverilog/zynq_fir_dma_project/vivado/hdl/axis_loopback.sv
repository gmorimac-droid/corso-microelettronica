module axis_loopback #(
    parameter int DATA_W = 16
)(
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

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            m_axis_tvalid <= 0;
        end else begin
            if (m_axis_tvalid && m_axis_tready)
                m_axis_tvalid <= 0;

            if (s_axis_tvalid && (!m_axis_tvalid || m_axis_tready)) begin
                m_axis_tdata  <= s_axis_tdata;
                m_axis_tvalid <= 1;
                m_axis_tlast  <= s_axis_tlast;
            end
        end
    end

    assign s_axis_tready = !m_axis_tvalid || m_axis_tready;

endmodule