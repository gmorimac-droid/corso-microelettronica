# 06 — UVM (Universal Verification Methodology)

## 🎯 Objectives

This module introduces UVM from an **industrial ASIC/FPGA verification perspective**.

By the end, you will:
- Understand **UVM architecture and layering**
- Build a **scalable verification environment**
- Separate **stimulus, driving, monitoring, and checking**
- Design **reusable and modular testbenches**

---

## 🧠 1. What is UVM

UVM (Universal Verification Methodology) is the **industry standard verification framework**.

- Built on SystemVerilog
- Widely used in **ASIC design flows**
- Increasingly adopted in **complex FPGA verification**

👉 Enables **scalable and reusable verification environments**

---

## 🧩 2. Why UVM

For simple designs:
- basic testbenches are sufficient

For complex systems:
- need **modularity**
- need **reuse**
- need **automation**

### 📌 Key Goals

- Separation of concerns
- Transaction-level modeling (TLM)
- Reusable verification IP (VIP)

---

## 🏗️ 3. UVM Architecture

```
Test
 └── Environment
      ├── Agent
      │    ├── Driver
      │    ├── Sequencer
      │    └── Monitor
      └── Scoreboard
```

### 🔍 Design Insight

- Hierarchical structure
- Each component has a **well-defined role**
- Enables scalable verification for large systems

---

## 🔧 4. Core Components

### 🧪 Test
- Defines verification scenario
- Configures environment

### 🌍 Environment
- Top-level container
- Instantiates agents and scoreboard

### 🔌 Agent
- Encapsulates interface logic
- Can be active or passive

### 🚚 Driver
- Converts transactions → pin-level signals
- Drives DUT interface

### 🎛️ Sequencer
- Generates transactions
- Controls stimulus flow

### 🔍 Monitor
- Observes DUT signals
- Converts signals → transactions

### 📊 Scoreboard
- Compares expected vs actual behavior
- Implements checking logic

---

## 🔁 5. UVM Data Flow

```
Sequence → Sequencer → Driver → DUT
                             ↓
                         Monitor
                             ↓
                         Scoreboard
```

### 📌 Key Concept

- Stimulus is **transaction-based**
- DUT interaction is **signal-level**
- Verification is **data-driven**

---

## 📦 6. Transactions (Sequence Items)

```systemverilog
class packet extends uvm_sequence_item;
  rand bit [7:0] data;
endclass
```

### ✔ Role

- Abstract representation of data
- Enables reuse and randomization

---

## 🔄 7. Sequences (Stimulus Generation)

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

### ✔ Function

- Generates stimulus patterns
- Can be random or constrained

---

## 🔧 8. Minimal Test Example

```systemverilog
class my_test extends uvm_test;

  `uvm_component_utils(my_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass
```

---

## 📊 9. Verification Strategy (Engineering View)

### ✔ Recommended Approach

- Start with directed tests
- Add constrained random sequences
- Introduce coverage-driven verification

### ✔ Metrics

- Functional coverage
- Assertion coverage
- Bug detection rate

---

## ⚠️ 10. Common Pitfalls

❌ Not understanding architecture  
❌ Overcomplicating early design  
❌ Poor component separation  
❌ Weak debug strategy  

---

## 🧪 11. Exercises (Design-Oriented)

1. Define a transaction class  
2. Create a sequence  
3. Build a minimal agent  
4. Add a basic scoreboard  

---

## 🚀 Next Module

👉 FPGA Flow

Focus:
- synthesis
- implementation
- timing closure

---

## 💻 Codice di riferimento

- [Top Testbench UVM](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/uvm/project_counter/tb_top.sv)
- [Driver](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/uvm/project_counter/counter_driver.sv)
- [Monitor](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/uvm/project_counter/counter_monitor.sv)
- [Scoreboard](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/uvm/project_counter/counter_scoreboard.sv)


