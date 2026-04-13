# 04 — SystemVerilog (Design)

## 🎯 Objectives

This module introduces SystemVerilog as a **modern RTL design language** for FPGA and ASIC development.

By the end, you will:
- Use **SystemVerilog constructs for safer RTL**
- Improve **readability and maintainability**
- Reduce common **Verilog design errors**
- Write **synthesis-friendly and timing-aware code**

---

## 🧠 1. SystemVerilog in Design Flow

SystemVerilog extends Verilog with:
- safer RTL constructs
- better type system
- advanced verification features

RTL → Synthesis → Netlist → Place & Route → Bitstream

👉 Stronger guarantees than Verilog for RTL correctness

---

## 🔧 2. `logic` Type

```systemverilog
logic a;
logic [3:0] data;
```

✔ replaces wire/reg  
✔ reduces ambiguity  

---

## 🔁 3. Sequential Logic — `always_ff`

```systemverilog
always_ff @(posedge clk) begin
  q <= d;
end
```

- Generates flip-flops  
- Defines pipeline stage  

---

## 🔄 4. Combinational Logic — `always_comb`

```systemverilog
always_comb begin
  y = a & b;
end
```

✔ automatic sensitivity  
✔ avoids latch  

---

## 🔷 5. FSM — `enum`

```systemverilog
typedef enum logic [1:0] {
  IDLE,
  RUN,
  STOP
} state_t;
```

✔ safer FSM  
✔ better debug  

---

## 🧩 6. Struct

```systemverilog
typedef struct {
  logic [7:0] data;
  logic valid;
} packet_t;
```

---

## 🔗 7. Interface

```systemverilog
interface bus_if;
  logic clk;
  logic [7:0] data;
endinterface
```

---

## 🔢 8. Counter

```systemverilog
module counter (
  input  logic clk,
  input  logic reset,
  output logic [3:0] q
);

always_ff @(posedge clk or posedge reset) begin
  if (reset)
    q <= 0;
  else
    q <= q + 1;
end

endmodule
```

---

## 📊 9. Timing

FF → Logic → FF

✔ pipeline improves frequency  

---

## ⚠️ 10. Pitfalls

- using always instead of always_ff  
- mixing logic types  
- poor structuring  

---

## 🚀 Next

Verification Base
