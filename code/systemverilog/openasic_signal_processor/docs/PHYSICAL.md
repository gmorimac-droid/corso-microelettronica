# Physical Bring-Up (V5)

Questa versione prepara il progetto al primo run OpenLane/OpenROAD.

## File chiave
- `asic/config.json`
- `asic/constraints.sdc`
- `asic/pin_order.cfg`

## Obiettivi V5
1. congelare le porte top-level
2. allineare la configurazione al flow OpenLane
3. fare un primo run fisico con clock a 10 MHz
4. raccogliere report di sintesi, timing e DRC

## Check pre-run
- top-level sintetizzabile
- un solo clock (`clk`)
- reset definito (`rst_n`)
- nessun costrutto non sintetizzabile nel top
- pin order coerente con le porte del top

## Comando di run
```bash
cd asic
openlane config.json
```
