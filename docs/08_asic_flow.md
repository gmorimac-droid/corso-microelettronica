# 08 — ASIC Flow

## 🎯 Objectives

This module introduces the **complete ASIC design flow** from RTL to silicon fabrication.

By the end, you will:
- Understand the **end-to-end ASIC flow**
- Compare FPGA vs ASIC implementation strategies
- Interpret **timing, power, and physical constraints**
- Connect **RTL design with physical implementation**

---

## 🧠 1. What is an ASIC

An ASIC (Application-Specific Integrated Circuit) is a **custom-designed chip** optimized for a specific application.

### Key Characteristics

- Fixed functionality after fabrication
- Optimized for:
  - performance
  - power
  - area (PPA)

👉 Unlike FPGA, no reconfiguration after tape-out

---

## ⚖️ 2. FPGA vs ASIC (Engineering View)

| FPGA | ASIC |
|------|------|
| programmable | fixed |
| lower performance | higher performance |
| higher unit cost | low cost at scale |
| fast development | long development cycle |

### 📌 Design Trade-off

- FPGA → flexibility and fast iteration  
- ASIC → efficiency and scalability  

---

## 🔁 3. Complete ASIC Flow

```
RTL → Simulation → Synthesis → STA → Physical Design → Signoff → Tape-out
```

### Engineering Flow

```
RTL Design
   ↓
Functional Verification
   ↓
Logic Synthesis
   ↓
Static Timing Analysis (STA)
   ↓
Physical Design (Place & Route)
   ↓
Signoff (Timing / Power / Integrity)
   ↓
Tape-out (Fabrication)
```

---

## 🔍 4. Flow Breakdown

### 🧩 4.1 RTL Design

- VHDL / Verilog / SystemVerilog
- Functional description of hardware

---

### 🧪 4.2 Simulation

- Functional verification using testbenches
- Bug fixing before synthesis

---

### ⚙️ 4.3 Synthesis

- RTL → gate-level netlist

### Tools

- Synopsys Design Compiler  
- Cadence Genus  

### Output

- Standard cell netlist

---

### ⏱️ 4.4 Static Timing Analysis (STA)

Analyzes timing without simulation.

### Key Checks

- Setup time  
- Hold time  
- Clock skew  
- Critical paths  

---

### 🧱 4.5 Physical Design

Includes:

- Floorplanning  
- Placement  
- Clock Tree Synthesis (CTS)  
- Routing  

### 📌 Impact

- Directly affects performance, power, and area

---

### 🔍 4.6 Signoff

Final verification before fabrication:

- Timing closure  
- Power analysis  
- Signal integrity  
- DRC / LVS checks  

---

### 📦 4.7 Tape-out

- Final design sent to foundry
- Silicon fabrication begins

👉 Errors at this stage are extremely costly

---

## 📊 5. Timing & PPA Optimization

### Critical Path

```
FF → Logic → Logic → FF
```

### Optimization Techniques

- Pipeline insertion  
- Gate sizing  
- Buffer insertion  
- Clock tree optimization  

---

## 🧰 6. Industry Toolchains

- Synopsys (DC, PrimeTime)  
- Cadence (Genus, Innovus)  
- Siemens EDA (Mentor Graphics)  

---

## ⚠️ 7. Common Pitfalls

❌ Ignoring timing constraints  
❌ Underestimating power consumption  
❌ Poor floorplanning  
❌ Insufficient verification  

---

## 🧪 8. Exercises (Design-Oriented)

1. Describe full ASIC flow  
2. Compare FPGA vs ASIC trade-offs  
3. Identify a critical path  
4. Propose timing optimizations  

---

## 🚀 Next Module

👉 Complete Projects

Focus:
- end-to-end design
- system integration
- real-world applications

---

## 💻 Codice di riferimento

- [SDC Example](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/constraints/counter_example.sdc)

