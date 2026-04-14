# 02 — VHDL (Hardware Description Language)

## 🎯 Objectives

This module introduces VHDL from an **FPGA/ASIC design perspective**, focusing on synthesizable constructs and hardware implications.

By the end, you will:
- Understand **hardware-centric modeling**
- Write **synthesizable RTL**
- Design **clocked pipelines**
- Avoid common **timing and synthesis pitfalls**

---

## 🧠 1. VHDL in a Hardware Design Flow

VHDL is not a programming language: it is a **hardware modeling language**.

### 🔄 Typical FPGA Flow

```
RTL (VHDL)
   ↓
Synthesis (Vivado / Quartus)
   ↓
Netlist (LUT, FF, DSP)
   ↓
Place & Route
   ↓
Bitstream
```

### 📌 Key Concept

Every construct maps to **physical hardware**:
- assignment → combinational logic
- process(clk) → flip-flops
- loops → parallel hardware (NOT sequential execution)

---

## 🧩 2. RTL Design Structure

### Entity (Interface)

Defines:
- I/O ports
- bit-widths
- module boundary

### Architecture (Implementation)

Defines:
- combinational logic
- sequential logic
- pipeline structure

---

## 🔧 3. Combinational Logic

```vhdl
Y <= A and B;
```

### ⏱ Timing

```
A ----       AND ----> Y
B ----/
```

- No clock
- Delay = LUT propagation delay
- Critical path contributor

---

## 🔁 4. Sequential Logic (Registers)

```vhdl
process(clk)
begin
  if rising_edge(clk) then
    q <= d;
  end if;
end process;
```

### ⏱ Timing Model

```
      ┌──────┐
D --->│  FF  │----> Q
      └──────┘
         ↑
        clk
```

- Defines **pipeline stage**
- Latency = 1 clock cycle
- Breaks combinational critical paths

---

## 🔄 5. Pipeline Concept (Critical for FPGA)

Example:

```
Stage 1        Stage 2        Stage 3
[Logic] -> FF -> [Logic] -> FF -> [Logic]
```

### ✔ Benefits

- Higher clock frequency
- Improved timing closure
- Better DSP utilization

### ❗ Trade-off

- Increased latency
- More flip-flops

---

## 🔌 6. Data Types (Synthesis-Oriented)

### Recommended

- `std_logic`
- `std_logic_vector`
- `unsigned` / `signed` (numeric_std)

### ❌ Avoid

- `std_logic_arith` (non-standard)

---

## 🔄 7. Signals vs Variables (Hardware Impact)

| Feature | Signal | Variable |
|--------|--------|----------|
| Scope | global | local |
| Update | scheduled | immediate |
| Hardware mapping | wires/registers | temp logic |

### ⚠️ Design Note

Misuse leads to:
- simulation mismatch
- unintended hardware

---

## 🔢 8. Counter — Synthesizable Example

```vhdl
process(clk)
begin
  if rising_edge(clk) then
    if reset = '1' then
      count <= (others => '0');
    else
      count <= count + 1;
    end if;
  end if;
end process;
```

### Hardware Mapping

- Flip-flops (state)
- Adder (combinational)
- Optional reset network

---

## 📚 9. Clocking & Reset Strategy

### ✔ Best Practices

- Prefer **synchronous reset**
- Use **single clock domain** when possible
- Avoid gated clocks

### ❗ Advanced (ASIC/FPGA)

- CDC handling required for multi-clock
- Reset trees impact timing

---

## ⚠️ 10. Common Design Pitfalls

### ❌ Latch Inference

```
if (cond) then
  y <= a;
end if;
```

→ Missing else → latch

### ❌ Long Combinational Paths

→ timing violation

### ❌ Mixing blocking logic mentally

→ wrong hardware assumptions

---

## 📊 11. Timing Closure Perspective

### Critical Path

```
FF → Logic → Logic → Logic → FF
```

### Fix Strategies

- Insert pipeline registers
- Reduce logic depth
- Use DSP blocks
- Optimize bit-width

---

## 🧪 12. Exercises (Design-Oriented)

1. OR gate (baseline)
2. 8-bit register with enable
3. Mod-10 counter
4. Pipelined adder (2-stage)

---

## 🚀 Next Module

👉 Verilog / SystemVerilog

Focus:
- industry usage
- synthesis equivalence
- mixed-language design

---

## 🧾 Summary (Engineering View)

| Topic | Key Insight |
|------|-----------|
| VHDL | hardware description |
| Process | flip-flops |
| Assignment | combinational logic |
| Pipeline | performance tool |
| Timing | primary design constraint |

---

## 📎 Notes

This version is aligned with:
- FPGA implementation (Xilinx/Intel)
- ASIC design principles
- timing-driven development

