# Zynq PS + AXI + LED

Scaffold completo per un progetto Zynq in cui il **PS** controlla un **LED** tramite **AXI GPIO** nel **PL**.

## Contenuto

- `vivado/scripts/create_project.tcl`  
  Script Tcl per creare il progetto Vivado, il block design e il bitstream.
- `vivado/constraints/led.xdc`  
  Vincoli pin del LED da adattare alla tua board.
- `vitis/led_axi_app/src/main.c`  
  Applicazione bare-metal che fa blink del LED via `XGpio`.
- `docs/guide.md`  
  Guida rapida ai passaggi Vivado/Vitis.

## Note importanti

1. Devi **modificare il pin LED** in `vivado/constraints/led.xdc`.
2. Nel file Tcl devi scegliere **board part** oppure **FPGA part** corretti per la tua scheda.
3. I nomi delle macro in `xparameters.h` possono cambiare in base al nome dell'IP nel block design.
4. Il progetto usa `AXI GPIO` a **1 bit, output only**.

## Struttura

```text
zynq_ps_axi_led/
├── README.md
├── docs/
│   └── guide.md
├── vivado/
│   ├── constraints/
│   │   └── led.xdc
│   └── scripts/
│       ├── create_project.tcl
│       └── export_hardware_notes.txt
└── vitis/
    └── led_axi_app/
        └── src/
            ├── main.c
            └── README.txt
```
