# 07 — FPGA Flow

## 🎯 Obiettivi

* Comprendere il flusso completo FPGA
* Passare da RTL a hardware reale
* Introdurre tool industriali
* Capire timing e vincoli

---

## 🧠 1. Cos’è un FPGA

Un FPGA (Field Programmable Gate Array) è un dispositivo programmabile.

👉 permette di implementare circuiti digitali senza fabbricazione ASIC

---

## 🔁 2. Flusso FPGA completo

```text
RTL → Simulation → Synthesis → Implementation → Bitstream → FPGA
```

---

## 🔍 3. Fasi del flusso

---

### 🧩 3.1 RTL Design

* VHDL / Verilog / SystemVerilog
* descrizione del circuito

---

### 🧪 3.2 Simulation

* verifica funzionale
* uso di testbench

---

### ⚙️ 3.3 Synthesis

* traduce RTL in gate logici

👉 output:

* netlist

---

### 🧱 3.4 Implementation

Include:

* placement (posizionamento)
* routing (connessioni)

---

### ⏱️ 3.5 Timing Analysis

Verifica che il circuito rispetti i tempi:

* setup time
* hold time
* clock frequency

---

### 📦 3.6 Bitstream

File finale da caricare su FPGA.

---

## 🧰 4. Tool principali

### 🔷 Xilinx Vivado

* per FPGA Xilinx

### 🔶 Intel Quartus

* per FPGA Intel

---

## 🔧 5. Constraints (vincoli)

Definiscono:

* clock
* pin
* timing

Esempio:

```tcl
create_clock -period 10 [get_ports clk]
```

---

## 🔌 6. Caricamento su FPGA

* collegare board
* programmare dispositivo
* verificare comportamento

---

## ⚠️ 7. Errori comuni

❌ ignorare timing
❌ constraints sbagliati
❌ non simulare prima
❌ clock non definito

---

## 🧪 8. Esercizi

1. Sintetizzare un contatore
2. Definire un clock constraint
3. Caricare su FPGA

---

## 🚀 Collegamento al prossimo modulo

👉 Nel prossimo capitolo vedremo **ASIC Flow**

## 💻 Codice di riferimento

- [Constraints XDC](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/constraints/counter_example.xdc)
- [Constraints SDC](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/constraints/counter_example.sdc)
- [Timing minimale](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/constraints/timing_only.sdc)
