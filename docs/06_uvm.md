# 06 — UVM (Universal Verification Methodology)

## 🎯 Obiettivi

* Comprendere l’architettura UVM
* Strutturare un ambiente di verifica complesso
* Separare generazione, guida e controllo
* Introdurre test riutilizzabili e scalabili

---

## 🧠 1. Cos’è UVM

UVM è una metodologia standard per la verifica.

👉 basata su SystemVerilog
👉 usata nell’industria ASIC

---

## 🧩 2. Perché UVM

Nei sistemi complessi:

❌ testbench semplici non bastano

Serve:

* riusabilità
* modularità
* automazione

---

## 🏗️ 3. Architettura UVM

```text
Test
 └── Environment
      ├── Agent
      │    ├── Driver
      │    ├── Sequencer
      │    └── Monitor
      └── Scoreboard
```

---

## 🔧 4. Componenti principali

### 🧪 Test

* definisce cosa testare

---

### 🌍 Environment

* contiene tutto

---

### 🔌 Agent

* interfaccia con DUT

---

### 🚚 Driver

* invia stimoli

---

### 🎛️ Sequencer

* genera sequenze

---

### 🔍 Monitor

* osserva segnali

---

### 📊 Scoreboard

* confronta risultati

---

## 🔁 5. Flusso UVM

1. sequencer genera transazioni
2. driver le applica al DUT
3. monitor osserva
4. scoreboard verifica

---

## 🔧 6. Esempio minimale (struttura)

```systemverilog
class my_test extends uvm_test;

  `uvm_component_utils(my_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass
```

---

## 📦 7. Transazioni

In UVM si lavora con oggetti:

```systemverilog
class packet extends uvm_sequence_item;
  rand bit [7:0] data;
endclass
```

---

## 🔄 8. Sequenze

Generano stimoli:

```systemverilog
class my_sequence extends uvm_sequence #(packet);
  `uvm_object_utils(my_sequence)

  task body();
    packet pkt = packet::type_id::create("pkt");
    start_item(pkt);
    finish_item(pkt);
  endtask
endclass
```

---

## ⚠️ 9. Errori comuni

❌ non capire l’architettura
❌ codice troppo complesso subito
❌ non separare i componenti
❌ ignorare il debug

---

## 🧪 10. Esercizi

1. Definire una transazione
2. Creare una sequenza
3. Costruire un environment minimale

---

## 🚀 Collegamento al prossimo modulo

👉 Nel prossimo capitolo vedremo il **FPGA Flow**


## 💻 Codice di riferimento

- [Top Testbench UVM](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/uvm/project_counter/tb_top.sv)
- [Driver](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/uvm/project_counter/counter_driver.sv)
- [Monitor](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/uvm/project_counter/counter_monitor.sv)
- [Scoreboard](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/uvm/project_counter/counter_scoreboard.sv)
