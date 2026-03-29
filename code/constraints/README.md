# Constraints

Questa cartella contiene esempi di file di vincolo usati nei flow FPGA e ASIC.

## File inclusi

- `counter_example.xdc`  
  Esempio Xilinx XDC con clock e assegnazioni pin

- `counter_example.sdc`  
  Esempio SDC con clock, input delay e output delay

- `timing_only.sdc`  
  Esempio minimale solo timing

- `pins_example.xdc`  
  Esempio focalizzato soprattutto su pin e standard I/O

## Note

- I nomi delle porte devono combaciare con quelli del top-level RTL.
- I pin usati negli esempi sono indicativi e vanno adattati alla board o al progetto reale.
- XDC è tipico dei flow Xilinx/Vivado.
- SDC è uno standard molto diffuso nei flow FPGA e ASIC.
