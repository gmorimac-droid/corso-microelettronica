`ifndef OPENASIC_DEFINES_SVH
`define OPENASIC_DEFINES_SVH

`define DATA_W         16
`define COEFF_W        16
`define ACC_W          40
`define FIR_TAPS       8
`define FIFO_DEPTH     16
`define DECIM_W        4
`define SPI_FRAME_W    24

// Register map (byte addressed)
`define REG_CTRL       8'h00
`define REG_STATUS     8'h04
`define REG_DECIM      8'h08
`define REG_IN_COUNT   8'h0C
`define REG_OUT_COUNT  8'h10
`define REG_DATA_OUT   8'h14

// CTRL bits
`define CTRL_ENABLE       0
`define CTRL_SOFT_RESET   1
`define CTRL_START        2
`define CTRL_BYPASS_FIR   3
`define CTRL_BYPASS_DECIM 4

// STATUS bits
`define STAT_BUSY         0
`define STAT_DONE         1
`define STAT_OVF          2
`define STAT_UDF          3
`define STAT_DATA_VALID   4

// SPI commands
`define SPI_CMD_WR_REG    8'h10
`define SPI_CMD_RD_REG    8'h11
`define SPI_CMD_WR_SAMPLE 8'h40

`endif
