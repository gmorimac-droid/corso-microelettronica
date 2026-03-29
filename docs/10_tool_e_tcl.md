# 10 — Tool e TCL

## 🎯 Obiettivi

* Comprendere il ruolo dei tool nel flusso di progettazione
* Automatizzare processi con TCL
* Gestire simulation, synthesis e implementation
* Introdurre scripting e workflow professionali

---

## 🧠 1. Perché i tool sono fondamentali

👉 Senza tool non esiste progettazione hardware moderna

I tool permettono:

* simulazione
* sintesi
* analisi timing
* implementazione

---

## 🧰 2. Tipi di tool

### 🔷 Simulazione

* ModelSim
* QuestaSim
* XSIM

---

### ⚙️ Sintesi

* Vivado
* Quartus

---

### 🏭 ASIC

* Synopsys
* Cadence

---

## 🔁 3. Flusso automatizzato

```text
Script → Tool → Output → Analisi
```

👉 invece di cliccare manualmente
👉 si usano script

---

## 💻 4. Cos’è TCL

TCL (Tool Command Language) è un linguaggio di scripting.

👉 usato nei tool FPGA e ASIC

---

## 🔧 5. Esempio base TCL

```tcl
create_project my_project ./proj -part xc7a35tcpg236-1
add_files counter.vhd
synth_design -top counter
report_timing_summary
```

---

## 🔄 6. Automazione flow

Con TCL puoi:

* lanciare simulazioni
* sintetizzare
* generare report

👉 tutto automaticamente

---

## 📦 7. Script tipici

### Simulation

```tcl
run 100ns
```

### Synthesis

```tcl
synth_design -top top_module
```

### Timing

```tcl
report_timing_summary
```

---

## 🔌 8. Constraints

File fondamentali per:

* clock
* pin
* timing

Esempio:

```tcl
create_clock -period 10 [get_ports clk]
```

---

## 🧠 9. Workflow professionale

```text
Git → Script → Tool → Report → Debug
```

👉 tutto versionato
👉 tutto ripetibile

---

## ⚠️ 10. Errori comuni

❌ lavorare solo da GUI
❌ non versionare script
❌ script non modulari
❌ ignorare log e report

---

## 🧪 11. Esercizi

1. Scrivere uno script TCL base
2. Automatizzare una sintesi
3. Generare report timing

---

## 🚀 Collegamento al prossimo modulo

👉 Fine del corso 🎉
👉 oppure: progetti avanzati e approfondimenti
