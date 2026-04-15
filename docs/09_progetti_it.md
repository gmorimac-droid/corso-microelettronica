# Progetti

## Obiettivi

Questo modulo è dedicato ai **progetti hardware end-to-end**, combinando RTL, verifica e implementazione.

Al termine sarai in grado di:
- applicare **progettazione + verifica + flusso**
- costruire **sistemi hardware realistici**
- sviluppare **competenze di ingegneria a livello di progetto**
- prepararti a un lavoro su **FPGA/ASIC di livello industriale**

---

## 1. Ruolo dei progetti nella progettazione hardware

L’apprendimento più efficace avviene attraverso l’implementazione.

Un progetto completo dovrebbe includere:

- progettazione RTL  
- testbench  
- verifica (assertions + controlli)  
- implementazione opzionale su FPGA  

### Prospettiva ingegneristica

I progetti simulano flussi di lavoro reali:
- specifica → progettazione → verifica → implementazione

---

## 2. Struttura di un progetto

```
Progetto
 ├── Specifica
 ├── RTL
 ├── Testbench
 ├── Simulazione
 ├── Sintesi (opzionale)
 └── Risultati / Report
```

### Buona pratica

- mantenere il progetto modulare  
- separare le responsabilità  
- tracciare i risultati  

---

## 3. Linee guida di progettazione

- partire in modo semplice, poi scalare  
- verificare sempre prima della sintesi  
- usare una architettura modulare  
- documentare le decisioni progettuali  

---

## 4. Progetto 1 — Contatore avanzato

### Obiettivo

- contatore parametrico  
- supporto a reset ed enable  

### Funzionalità

- larghezza configurabile (N)  
- gestione dell’overflow  
- testbench self-checking  

### Esempio (SystemVerilog)

```systemverilog
module counter #(
  parameter N = 4
)(
  input  logic clk,
  input  logic reset,
  input  logic enable,
  output logic [N-1:0] q
);

  always_ff @(posedge clk or posedge reset) begin
    if (reset)
      q <= 0;
    else if (enable)
      q <= q + 1;
  end

endmodule
```

### Lettura hardware

- FFs → stato  
- Adder → logica combinatoria  
- Enable → logica di abilitazione  

---

## 5. Progetto 2 — UART

### Obiettivo

Implementare una interfaccia di comunicazione seriale.

### Componenti

- trasmettitore (TX)  
- ricevitore (RX)  
- generatore di baud rate  

### Sfide progettuali

- accuratezza temporale  
- campionamento dei bit  
- sincronizzazione  

---

## 6. Progetto 3 — ALU

### Operazioni

- addizione  
- sottrazione  
- AND / OR logico  

### Focus progettuale

- ottimizzazione della logica combinatoria  
- compromesso tra latenza e area  

---

## 7. Progetto 4 — FIFO

### Concetti

- buffer circolare  
- puntatori di lettura / scrittura  
- rilevazione di full / empty  

### Temi avanzati

- FIFO dual-clock (CDC)  
- ottimizzazione del throughput  

---

## 8. Progetto 5 — CPU semplice

### Componenti

- ALU  
- registri  
- unità di controllo  

### Complessità progettuale

- decodifica delle istruzioni  
- controllo tramite macchina a stati  
- pipeline (opzionale, livello avanzato)  

---

## 9. Verifica nei progetti

Ogni progetto deve includere:

- testbench  
- assertions  
- coverage  

### Buona pratica

- usare ambienti self-checking  
- validare i casi limite  
- misurare la coverage  

---

## 10. Pipeline completa di progetto

```
Specifica → RTL → Testbench → Simulazione → FPGA
```

### Punto chiave

La verifica è continua lungo tutte le fasi del flusso.

---

## 11. Errori comuni

- saltare la verifica  
- complicare troppo il progetto iniziale  
- modularizzazione insufficiente  
- documentazione mancante  

---

## 12. Esercizi orientati alla progettazione

1. Estendere il contatore con nuove funzionalità  
2. Aggiungere assertions al testbench  
3. Simulare l’intero sistema  
4. Implementare su FPGA  

---

## Modulo successivo

Tool e TCL

Focus:
- automazione
- scripting
- ottimizzazione del flusso

---

## Codice RTL completo

```systemverilog
--8<-- "code/systemverilog/project_counter/counter.sv"
```

## Testbench completo

```systemverilog
--8<-- "code/systemverilog/project_counter/tb_counter.sv"
```
