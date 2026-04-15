# Tool e TCL

## Obiettivi

Questo modulo introduce i **tool EDA e lo scripting TCL** da una prospettiva ingegneristica FPGA/ASIC.

Al termine sarai in grado di:
- comprendere il ruolo dei **tool EDA nel flusso di progetto**
- automatizzare **simulazione, sintesi e implementazione**
- usare **TCL scripting** per flussi riproducibili
- costruire un **flusso professionale sotto versionamento**

---

## 1. Ruolo dei tool EDA

La progettazione hardware moderna è interamente guidata dai tool.

I tool EDA permettono:
- simulazione funzionale  
- sintesi logica  
- analisi temporale  
- implementazione fisica  

### Punto chiave

Senza tool non esiste progettazione hardware reale.

---

## 2. Categorie di tool

### Simulazione

- ModelSim  
- QuestaSim  
- XSIM  

### Sintesi / FPGA

- Xilinx Vivado  
- Intel Quartus  

### ASIC

- Synopsys (DC, PrimeTime)  
- Cadence (Genus, Innovus)  

---

## 3. Concetto di flusso automatizzato

```
Script → Tool → Output → Analisi
```

### Vantaggio ingegneristico

- ripetibilità  
- scalabilità  
- tracciabilità del debug  

---

## 4. Panoramica di TCL

TCL (Tool Command Language) è il **linguaggio di scripting standard** usato nei tool EDA.

### Utilizzo

- controllare l’esecuzione del tool  
- automatizzare i flussi  
- generare report  

---

## 5. Esempio base di TCL

```tcl
create_project my_project ./proj -part xc7a35tcpg236-1
add_files counter.vhd
synth_design -top counter
report_timing_summary
```

### Interpretazione del flusso

- creazione del progetto  
- import dei file  
- sintesi  
- analisi temporale  

---

## 6. Automazione del flusso

Usando TCL puoi:

- eseguire simulazioni  
- lanciare la sintesi  
- eseguire l’implementazione  
- generare report  

In questo modo si ottiene un flusso completamente automatizzato senza GUI.

---

## 7. Script comuni

### Simulazione

```tcl
run 100ns
```

### Sintesi

```tcl
synth_design -top top_module
```

### Timing

```tcl
report_timing_summary
```

---

## 8. Integrazione dei constraint

I constraint sono fondamentali sia nei flussi FPGA sia nei flussi ASIC.

### Esempio

```tcl
create_clock -period 10 [get_ports clk]
```

### Impatto

- definiscono le aspettative temporali  
- guidano sintesi e implementazione  
- sono essenziali per la timing closure  

---

## 9. Flusso professionale

```
Git → Script TCL → Tool EDA → Report → Debug
```

### Buone pratiche

- mettere sotto versionamento tutto  
- mantenere gli script modulari  
- automatizzare i task ripetitivi  
- tracciare timing e log  

---

## 10. Errori comuni

- lavorare solo tramite GUI  
- non versionare gli script  
- usare script hardcoded e non riusabili  
- ignorare log e report  

---

## 11. Esercizi orientati alla progettazione

1. Scrivere uno script TCL di base  
2. Automatizzare il flusso di sintesi  
3. Generare report di timing  
4. Integrare i constraint nello script  

---

## Completamento del corso

Hai completato l’intero percorso di progettazione FPGA/ASIC.

Passi successivi:
- costruire progetti più avanzati  
- ottimizzare per prestazioni e PPA  
- esplorare metodologie di verifica più avanzate (UVM avanzato)  

---

## Sintesi finale

| Tema | Punto chiave |
|------|--------------|
| Tool | nucleo della progettazione hardware |
| TCL | base dell’automazione |
| Flusso | deve essere riproducibile |
| Constraint | cruciali per il timing |
| Script | abilitano la scalabilità |
