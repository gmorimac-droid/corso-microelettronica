# Guida rapida

## 1. Vivado

Apri la console Tcl di Vivado e lancia:

```tcl
cd <cartella_progetto>/vivado/scripts
source create_project.tcl
```

Lo script crea:

- progetto Vivado
- block design `design_1`
- `ZYNQ7 Processing System`
- `AXI GPIO`
- connessioni automatiche
- wrapper HDL
- sintesi
- implementazione
- bitstream

## 2. Vincoli LED

Apri `vivado/constraints/led.xdc` e cambia il pin:

```tcl
set_property PACKAGE_PIN T22 [get_ports gpio_rtl_0_tri_o]
```

con quello corretto per la tua board.

## 3. Export hardware

Dopo il bitstream esporta l'hardware verso Vitis includendo il bitstream.

## 4. Vitis

Crea una platform dal file `.xsa`, poi crea una bare-metal application e copia il contenuto di:

- `vitis/led_axi_app/src/main.c`

nel tuo `main.c`.

## 5. Build e run

- Build della app
- Program FPGA
- Launch on Hardware

## 6. Risultato atteso

Il LED lampeggia.
