# 09 — Progetti

## 🎯 Objectives

This module focuses on **end-to-end hardware design projects** combining RTL, verification, and implementation.

By the end, you will:
- Apply **design + verification + flow**
- Build **realistic hardware systems**
- Develop **project-level engineering skills**
- Prepare for **industry-level FPGA/ASIC work**

---

## 🧠 1. Role of Projects in Hardware Design

👉 Real learning happens through implementation

A complete project should include:

- RTL design  
- Testbench  
- Verification (assertions + checks)  
- Optional FPGA implementation  

### 📌 Engineering Perspective

Projects simulate real workflows:
- specification → design → verification → implementation

---

## 🧩 2. Project Structure

```
Project
 ├── Specification
 ├── RTL
 ├── Testbench
 ├── Simulation
 ├── Synthesis (optional)
 └── Results / Reports
```

### ✔ Best Practice

- Keep design modular  
- Separate concerns  
- Track results  

---

## 🔧 3. Design Guidelines

✔ Start simple, then scale  
✔ Always verify before synthesis  
✔ Use modular architecture  
✔ Document design decisions  

---

## 🔢 4. Project 1 — Advanced Counter

### 📌 Objective

- Parametric counter  
- Reset + enable support  

### 🧪 Features

- Configurable width (N)  
- Overflow behavior  
- Self-checking testbench  

### 💻 Example (SystemVerilog)

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

### 🔍 Hardware Insight

- FFs → state  
- Adder → combinational logic  
- Enable → gating logic  

---

## 🔌 5. Project 2 — UART

### 📌 Objective

Implement serial communication interface.

### 🔧 Components

- Transmitter (TX)  
- Receiver (RX)  
- Baud rate generator  

### 📌 Design Challenges

- Timing accuracy  
- Bit sampling  
- Synchronization  

---

## 🧮 6. Project 3 — ALU

### 📌 Operations

- Addition  
- Subtraction  
- Logical AND / OR  

### 📊 Design Focus

- Combinational logic optimization  
- Latency vs area trade-off  

---

## 📦 7. Project 4 — FIFO

### 📌 Concepts

- Circular buffer  
- Read / write pointers  
- Full / empty detection  

### 📌 Advanced Topics

- Dual-clock FIFO (CDC)  
- Throughput optimization  

---

## 🧠 8. Project 5 — Simple CPU

### 📌 Components

- ALU  
- Registers  
- Control unit  

### 📊 Design Complexity

- Instruction decoding  
- State machine control  
- Pipeline (optional advanced)  

---

## 🧪 9. Verification in Projects

Each project must include:

- Testbench  
- Assertions  
- Coverage  

### ✔ Best Practice

- Use self-checking environments  
- Validate edge cases  
- Measure coverage  

---

## 🔁 10. Full Design Pipeline

```
Specification → RTL → Testbench → Simulation → FPGA
```

### 📌 Key Insight

Verification is continuous across all stages.

---

## ⚠️ 11. Common Pitfalls

❌ Skipping verification  
❌ Overcomplicating initial design  
❌ Poor modularization  
❌ Missing documentation  

---

## 🧪 12. Exercises (Design-Oriented)

1. Extend the counter with new features  
2. Add assertions to testbench  
3. Simulate full system  
4. Implement on FPGA  

---

## 🚀 Next Module

👉 Tool & TCL

Focus:
- automation
- scripting
- workflow optimization

---

## Codice RTL completo

```systemverilog
--8<-- "code/systemverilog/project_counter/counter.sv"
```

## Testbench completo

```systemverilog
--8<-- "code/systemverilog/project_counter/tb_counter.sv"
```

---

## 📄 Source File

fileciteturn9file0
