# 05 — Verification Base

## 🎯 Objectives

This module introduces **digital verification fundamentals** from an FPGA/ASIC perspective.

By the end, you will:
- Understand the **role of verification in hardware design**
- Build a **structured testbench**
- Apply **assertions and basic checking**
- Interpret simulation results in a **timing-aware context**

---

## 🧠 1. Role of Verification in Hardware Design

In modern digital design:

👉 RTL correctness is NOT sufficient

A design must be:
- verified
- validated
- stress-tested

### 📊 Industry Reality

- ~70–80% of project time is spent in **verification**
- Bugs are cheaper to fix in simulation than in silicon

---

## 🧩 2. Testbench Architecture

A testbench is a **non-synthesizable environment** used to validate RTL.

### Structure

```
Testbench
 ├── DUT (Design Under Test)
 ├── Stimulus Generator
 ├── Monitor
 └── Checker / Scoreboard
```

---

## 🔧 3. Basic Testbench Example

```systemverilog
module tb_counter;

  logic clk;
  logic reset;
  logic [3:0] q;

  // DUT
  counter dut (
    .clk(clk),
    .reset(reset),
    .q(q)
  );

  // Clock generator
  always #5 clk = ~clk;

  // Stimulus
  initial begin
    clk = 0;
    reset = 1;
    #10;
    reset = 0;

    #100;
    $finish;
  end

endmodule
```

### 🔍 Design Insight

- Clock defines **time reference**
- Stimulus drives DUT inputs
- Simulation observes behavior cycle-by-cycle

---

## 🔁 4. Monitor (Observation Layer)

```systemverilog
initial begin
  $monitor("Time=%0t q=%0d", $time, q);
end
```

### Purpose

- Real-time signal tracking
- Debug support
- Waveform correlation

---

## ✔️ 5. Checker (Self-Checking Logic)

```systemverilog
always @(posedge clk) begin
  if (!reset && q == 4'd10) begin
    $error("Unexpected value detected");
  end
end
```

### ✔ Best Practice

- Always prefer **self-checking testbenches**
- Avoid manual waveform inspection

---

## ⚠️ 6. Assertions (Formalized Checks)

```systemverilog
assert (q < 10)
  else $error("Overflow detected");
```

### Types

- Immediate assertions
- Concurrent assertions (advanced)

### ✔ Benefits

- Automatic bug detection
- Cleaner verification intent
- Reusable checks

---

## 📊 7. Coverage (Test Quality Metric)

Coverage measures how thoroughly the design is exercised.

### Types

- Code coverage (lines, branches)
- Functional coverage (design intent)

### 📌 Goal

Ensure:
- all states are reached
- all transitions are tested
- corner cases are covered

---

## 🔄 8. Simulation Flow

```
RTL Design
   ↓
Testbench Development
   ↓
Simulation Run
   ↓
Waveform + Logs Analysis
   ↓
Bug Fix / Iteration
```

---

## 📊 9. Timing Awareness in Verification

Even in simulation:

- Respect clock cycles
- Validate latency
- Check pipeline alignment

### Example

```
Input → [Pipeline Stage] → Output (after N cycles)
```

Verification must account for:
- latency
- valid signals
- protocol timing

---

## ⚠️ 10. Common Pitfalls

❌ Incomplete test coverage  
❌ Lack of assertions  
❌ Manual-only verification  
❌ Ignoring corner cases  
❌ Not checking latency/pipeline behavior  

---

## 🧪 11. Exercises (Design-Oriented)

1. Write a self-checking testbench for a counter  
2. Add assertions for overflow  
3. Verify reset behavior  
4. Validate pipeline latency  

---

## 🚀 Next Module

👉 UVM (Universal Verification Methodology)

Focus:
- scalable verification
- reusable components
- constrained random testing

---

## 🧾 Summary

| Topic | Key Insight |
|------|------------|
| Testbench | non-synthesizable verification env |
| Checker | automated validation |
| Assertions | formal correctness |
| Coverage | completeness metric |
| Simulation | primary debug tool |


