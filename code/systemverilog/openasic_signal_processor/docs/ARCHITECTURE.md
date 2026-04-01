# RTL Architecture

## Top-level signal processor

```mermaid
flowchart LR
    SPI[spi_slave.sv]
    REG[reg_bank.sv]
    FSM[control_fsm.sv]
    FIFO[fifo_sync.sv]
    FIR[fir8_core.sv]
    DEC[decimator.sv]
    OUT[output_stage.sv]
    STAT[status_flags.sv]

    SPI --> REG
    SPI --> FIFO
    REG --> FSM
    REG --> DEC
    FIFO --> FIR --> DEC --> OUT --> STAT
    FSM --> FIFO
    FSM --> STAT
    STAT --> REG
```

## Note di integrazione V4

- `spi_slave.sv` implementa un protocollo SPI minimale a frame da 24 bit.
- `reg_bank.sv` espone configurazione e stato.
- `control_fsm.sv` gestisce `IDLE -> RUN -> DONE`.
- `top.sv` integra il datapath FIFO → FIR → DECIM → OUTPUT.
- `scripts/synth_yosys.sh` è la prima bozza di sintesi RTL reale.

## Freeze RTL target della V4

La V4 punta a congelare:
- porte top-level
- mappa registri base
- datapath base
- protocollo SPI minimale
