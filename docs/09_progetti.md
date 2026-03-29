# 09 — Progetti

## 🎯 Obiettivi

* Applicare tutti i concetti appresi
* Integrare design, verifica e tool
* Costruire sistemi reali
* Sviluppare competenze pratiche

---

## 🧠 1. Perché i progetti sono fondamentali

👉 si impara facendo

Un buon progetto deve includere:

* design RTL
* testbench
* verifica
* (opzionale) implementazione FPGA

---

## 🧩 2. Struttura di un progetto

```text
Progetto
 ├── Specifica
 ├── RTL
 ├── Testbench
 ├── Simulation
 ├── Sintesi (opzionale)
 └── Risultati
```

---

## 🔧 3. Linee guida

✔ iniziare semplice
✔ verificare sempre
✔ modularizzare
✔ documentare

---

## 🔢 4. Progetto 1 — Contatore avanzato

### 📌 Obiettivo

* contatore parametrico
* reset
* enable

---

### 🧪 Feature

* modulo N
* overflow
* testbench

---

### 💻 Esempio (SystemVerilog)

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

---

## 🔌 5. Progetto 2 — UART

### 📌 Obiettivo

* comunicazione seriale

### 🔧 Componenti

* TX
* RX
* baud generator

---

## 🧮 6. Progetto 3 — ALU

### 📌 Operazioni

* add
* sub
* and
* or

---

## 📦 7. Progetto 4 — FIFO

### 📌 Concetti

* buffer
* read/write
* gestione overflow

---

## 🧠 8. Progetto 5 — CPU semplice

### 📌 Componenti

* ALU
* registro
* control unit

---

## 🧪 9. Verification nei progetti

Ogni progetto deve avere:

* testbench
* assertions
* coverage

---

## 🔁 10. Pipeline completa

```text
Design → Testbench → Simulation → FPGA
```

---

## ⚠️ 11. Errori comuni

❌ saltare la verifica
❌ progetti troppo complessi subito
❌ codice non modulare
❌ niente documentazione

---

## 🧪 12. Esercizi

1. Estendere il contatore
2. Aggiungere testbench
3. Simulare progetto completo

---

## 🚀 Collegamento al prossimo modulo

👉 Nel prossimo capitolo: **Tool e TCL**

## Codice RTL completo

```systemverilog
--8<-- "code/systemverilog/project_counter/counter.sv"
```

## Testbench completo

```systemverilog
--8<-- "code/systemverilog/project_counter/tb_counter.sv"
```
