# 07 — FPGA Flow

## 🎯 Objectives

This module introduces the **complete FPGA implementation flow** from RTL to hardware execution.

By the end, you will:
- Understand the **end-to-end FPGA flow**
- Map RTL into **physical hardware resources**
- Interpret **timing analysis and constraints**
- Use **industry-standard tools (Vivado / Quartus)**

---

## 🧠 1. What is an FPGA

An FPGA (Field Programmable Gate Array) is a **reconfigurable digital device**.

### Key Characteristics

- Programmable after manufacturing
- Composed of:
  - LUTs (logic)
  - Flip-flops (storage)
  - DSP blocks (arithmetic)
  - BRAM (memory)

👉 Enables rapid prototyping and deployment without ASIC fabrication

---

## 🔁 2. Complete FPGA Flow

```
RTL → Simulation → Synthesis → Implementation → Bitstream → FPGA
```

### Engineering View

```
RTL Design
   ↓
Functional Verification
   ↓
Logic Synthesis
   ↓
Physical Implementation
   ↓
Timing Closure
   ↓
Bitstream Generation
   ↓
Hardware Debug
```

---

## 🔍 3. Flow Breakdown

### 🧩 3.1 RTL Design

- VHDL / Verilog / SystemVerilog
- Describes functionality

👉 Output: abstract hardware model

---

### 🧪 3.2 Simulation

- Functional verification
- Testbench-based validation

👉 Goal: eliminate logical bugs before synthesis

---

### ⚙️ 3.3 Synthesis

- Converts RTL → gate-level netlist

### Hardware Mapping

- LUTs → combinational logic  
- FFs → registers  
- DSP → arithmetic  

---

### 🧱 3.4 Implementation

Includes:

- Placement → physical location of logic
- Routing → interconnections

👉 Determines real performance

---

### ⏱️ 3.5 Timing Analysis

Ensures design meets clock constraints.

### Critical Path

```
FF → Logic → Logic → FF
```

### Metrics

- Setup time
- Hold time
- Max frequency (Fmax)

---

### 📦 3.6 Bitstream Generation

- Final binary file
- Programs FPGA configuration memory

---

### 🔌 3.7 Hardware Execution

- Load bitstream
- Run design on board
- Perform validation

---

## 🧰 4. Industry Tools

### 🔷 Xilinx Vivado
- Design, synthesis, implementation

### 🔶 Intel Quartus
- Equivalent flow for Intel FPGAs

---

## 🔧 5. Constraints (Timing & Physical)

Constraints define how the tool interprets your design.

### Example

```tcl
create_clock -period 10 [get_ports clk]
```

### Key Constraints

- Clock definition
- IO pin mapping
- Timing exceptions

👉 Incorrect constraints = incorrect hardware behavior

---

## 📊 6. Timing Closure (Critical Topic)

### Goal

Meet required clock frequency

### Techniques

- Pipeline insertion
- Reduce combinational depth
- Use DSP blocks
- Optimize fanout

---

## ⚠️ 7. Common Pitfalls

❌ Ignoring timing reports  
❌ Incorrect constraints  
❌ Skipping simulation  
❌ Undefined clock domains  

---

## 🧪 8. Exercises (Design-Oriented)

1. Synthesize a counter  
2. Define clock constraint  
3. Achieve timing closure  
4. Deploy on FPGA  

---

## 🚀 Next Module

👉 ASIC Flow

Focus:
- physical design
- silicon implementation
- advanced timing constraints

---

## 💻 Codice di riferimento

- [Constraints XDC](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/constraints/counter_example.xdc)
- [Constraints SDC](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/constraints/counter_example.sdc)
- [Timing minimale](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/constraints/timing_only.sdc)


