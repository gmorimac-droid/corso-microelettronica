# 01 — Fondamenti di Logica Digitale

## 🎯 Objectives

This module introduces the **fundamental concepts of digital logic** from an FPGA/ASIC design perspective.

By the end, you will:
- Understand **combinational vs sequential logic**
- Interpret **time behavior in digital systems**
- Learn the basis for **RTL design**
- Prepare for **hardware description languages (HDL)**

---

## 🧠 1. Digital Systems

A digital system processes information using **discrete values** (typically 0 and 1).

### Examples

- CPU  
- FPGA  
- ASIC  

### 🔍 Engineering View

All digital systems are composed of:
- combinational logic (LUTs / gates)
- sequential elements (flip-flops)

---

## 🔌 2. Combinational Logic

Output depends ONLY on current inputs.

### Example: AND Gate

| A | B | Y |
|---|---|---|
| 0 | 0 | 0 |
| 0 | 1 | 0 |
| 1 | 0 | 0 |
| 1 | 1 | 1 |

### ⏱ Timing Model

```
Input → Logic → Output
```

- No memory
- Delay = propagation delay

---

## ⏱️ 3. Sequential Logic

Output depends on:
- current inputs
- previous state

### Key Concept

```
Input + State → Next State
```

---

## 🔁 4. Flip-Flops (Storage Elements)

Basic memory elements.

### Example (D Flip-Flop)

```
      ┌──────┐
D --->│  FF  │----> Q
      └──────┘
         ↑
        clk
```

### Properties

- Stores 1 bit
- Updates on clock edge
- Fundamental for pipelines

---

## ⏰ 5. Clock

Global synchronization signal.

### Parameters

- Frequency (f)
- Period (T)
- Duty cycle

### 📌 Design Impact

Clock defines:
- system speed
- timing constraints
- pipeline stages

---

## 🔄 6. Registers

Group of flip-flops.

### Usage

- Data storage  
- Pipeline stages  
- State machines  

---

## 🔀 7. Finite State Machines (FSM)

Discrete-state systems.

### Components

- States  
- Transitions  
- Inputs  
- Outputs  

### Hardware Mapping

- Registers → state storage  
- Logic → transition function  

---

## 🔢 8. Example: Counter

Sequential system where:

- state = current value  
- updated every clock cycle  

### Hardware

- Flip-flops (state)
- Adder logic

---

## 📊 9. Timing Fundamentals

### Setup Time

Minimum time before clock edge  
input must be stable

### Hold Time

Minimum time after clock edge  
input must remain stable

### Propagation Delay

Time for signal to propagate through logic

---

## 📊 10. Timing Diagram Concept

```
Clock:   ┌─┐ ┌─┐ ┌─┐
         ┘ └─┘ └─┘ └─

Data:    ────████────

Valid Window:
        <setup><hold>
```

---

## 🧠 11. Combinational vs Sequential

| Type | Dependency |
|------|-----------|
| Combinational | Inputs |
| Sequential | Inputs + State |

---

## ⚠️ 12. Common Pitfalls

❌ Ignoring timing constraints  
❌ Misunderstanding clock behavior  
❌ Not considering propagation delay  
❌ Poor state design  

---

## 🧪 Exercises (Design-Oriented)

1. Truth table for XOR  
2. Design a mod-4 counter  
3. FSM for traffic light  
4. Identify critical path in a simple circuit  

---

## 🚀 Next Module

👉 VHDL

Focus:
- translating these concepts into RTL
- synthesizable design
