# OpenASIC Signal Processor

V5 del progetto ASIC open-source.

Questa versione è orientata al **primo passaggio OpenLane/OpenROAD**:
- top-level congelato per il flow
- configurazione OpenLane aggiornata
- `constraints.sdc` usato sia per PnR che per signoff
- `pin_order.cfg` organizzato per lati del chip
- script di run OpenLane pronto

## Stato della V5

La V5 è pensata per:
1. regressione RTL di base
2. sintesi Yosys
3. primo run fisico con OpenLane
4. raccolta dei primi report di area/timing/DRC

## Nota importante

Questa versione è una base **flow-ready**, non ancora signoff-ready.
Il passo successivo corretto è:
- far passare i test RTL
- lanciare Yosys
- lanciare OpenLane
- correggere i primi warning di timing/floorplan
