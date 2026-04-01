`include "defines.svh"

module spi_slave(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        spi_sclk,
    input  logic        spi_cs_n,
    input  logic        spi_mosi,
    output logic        spi_miso,

    output logic        reg_wr_en,
    output logic [7:0]  reg_wr_addr,
    output logic [15:0] reg_wr_data,
    output logic [7:0]  reg_rd_addr,
    input  logic [15:0] reg_rd_data,

    output logic        sample_valid,
    output logic signed [15:0] sample_data
);

    // SPI slave protocol, MSB first:
    // frame[23:16] = cmd
    // frame[15:8]  = addr (ignored for sample write)
    // frame[7:0]   = low byte payload
    // For register write, the second data byte is captured in bits [15:0] overall
    // because the address field acts as the upper data byte.
    //
    // Practical interpretation:
    //   WR_REG : {CMD, ADDR, DATA[7:0]} with DATA upper byte = 0
    //   RD_REG : {CMD, ADDR, don't care}; reply shifts out reg_rd_data
    //   WR_SAMPLE: two 16b halves over two consecutive frames is overkill for V1,
    //              so we use {CMD, sample[15:8], sample[7:0]}.

    logic sclk_meta, sclk_sync, sclk_prev;
    logic cs_meta,   cs_sync,   cs_prev;
    logic mosi_meta, mosi_sync;

    logic sclk_rise, cs_active, cs_start, cs_end;

    logic [`SPI_FRAME_W-1:0] rx_shift;
    logic [15:0]             tx_shift;
    logic [5:0]              bit_count;
    logic [7:0]              cmd_byte, addr_byte;
    logic [15:0]             payload_word;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_meta <= 1'b0; sclk_sync <= 1'b0; sclk_prev <= 1'b0;
            cs_meta   <= 1'b1; cs_sync   <= 1'b1; cs_prev   <= 1'b1;
            mosi_meta <= 1'b0; mosi_sync <= 1'b0;
        end else begin
            sclk_meta <= spi_sclk;
            sclk_sync <= sclk_meta;
            sclk_prev <= sclk_sync;

            cs_meta   <= spi_cs_n;
            cs_sync   <= cs_meta;
            cs_prev   <= cs_sync;

            mosi_meta <= spi_mosi;
            mosi_sync <= mosi_meta;
        end
    end

    assign sclk_rise = ( sclk_sync && !sclk_prev);
    assign cs_active = !cs_sync;
    assign cs_start  = (!cs_prev && 1'b0) | (cs_prev && !cs_sync);
    assign cs_end    = (!cs_prev && cs_sync);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_shift    <= '0;
            tx_shift    <= '0;
            bit_count   <= '0;
            reg_wr_en   <= 1'b0;
            reg_wr_addr <= '0;
            reg_wr_data <= '0;
            reg_rd_addr <= '0;
            sample_valid<= 1'b0;
            sample_data <= '0;
            spi_miso    <= 1'b0;
            cmd_byte    <= '0;
            addr_byte   <= '0;
            payload_word<= '0;
        end else begin
            reg_wr_en    <= 1'b0;
            sample_valid <= 1'b0;

            if (cs_start) begin
                bit_count <= '0;
                rx_shift  <= '0;
                tx_shift  <= 16'h0000;
                spi_miso  <= 1'b0;
            end else if (cs_active && sclk_rise) begin
                rx_shift  <= {rx_shift[`SPI_FRAME_W-2:0], mosi_sync};
                bit_count <= bit_count + 1'b1;

                // shift out readback MSB first after command decode
                spi_miso <= tx_shift[15];
                tx_shift <= {tx_shift[14:0], 1'b0};

                if (bit_count == 6'd7) begin
                    cmd_byte <= {rx_shift[6:0], mosi_sync};
                    if ({rx_shift[6:0], mosi_sync} == `SPI_CMD_RD_REG)
                        tx_shift <= reg_rd_data;
                end

                if (bit_count == 6'd15)
                    addr_byte <= {rx_shift[14:8], mosi_sync};

                if (bit_count == 6'd23) begin
                    cmd_byte     <= rx_shift[23:16];
                    addr_byte    <= rx_shift[15:8];
                    payload_word <= {rx_shift[15:8], rx_shift[7:0]};

                    unique case (rx_shift[23:16])
                        `SPI_CMD_WR_REG: begin
                            reg_wr_en   <= 1'b1;
                            reg_wr_addr <= rx_shift[15:8];
                            reg_wr_data <= {8'h00, rx_shift[7:0]};
                        end
                        `SPI_CMD_RD_REG: begin
                            reg_rd_addr <= rx_shift[15:8];
                        end
                        `SPI_CMD_WR_SAMPLE: begin
                            sample_valid <= 1'b1;
                            sample_data  <= {rx_shift[15:8], rx_shift[7:0]};
                        end
                        default: begin end
                    endcase
                end
            end
        end
    end

endmodule
