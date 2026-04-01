# 03 — Verilog

## 🎯 Objectives

This module introduces Verilog from an **FPGA/ASIC design perspective**, focusing on synthesizable RTL and hardware implications.

By the end, you will:
- Understand **RTL modeling in Verilog**
- Correctly describe **combinational and sequential logic**
- Distinguish between **wire and reg semantics**
- Apply **timing-aware design practices**

---

## 🧠 1. Verilog in Hardware Design

Verilog is a **hardware description language (HDL)** widely used in industry.

### 🔄 Typical Design Flow

RTL → Synthesis → Netlist → Place & Route → Bitstream

👉 Each construct maps directly to **hardware structures**

---

## 🔧 2. Combinational Logic

```verilog
assign Y = A & B;
```

Hardware:
A ----\
       AND ----> Y
B ----/

- No clock
- Impacts **critical path**

---

## 🔁 3. Sequential Logic

```verilog
always @(posedge clk) begin
  q <= d;
end
```

- Generates flip-flops
- Defines pipeline stages

---

## 🔄 4. wire vs reg

| Type | Meaning |
|------|--------|
| wire | connection |
| reg  | procedural assignment |

👉 `reg` ≠ always register

---

## ⚖️ 5. Blocking vs Non-blocking

- `=` → combinational  
- `<=` → sequential  

Wrong usage → simulation mismatch

---

## 🔢 6. Counter Example

```verilog
module counter (
  input clk,
  input reset,
  output reg [3:0] q
);

always @(posedge clk or posedge reset) begin
  if (reset)
    q <= 4'd0;
  else
    q <= q + 1'b1;
end

endmodule
```

---

## 📊 7. Timing Perspective

Critical path:
FF → Logic → FF

Optimization:
- pipeline
- reduce logic depth

---

## ⚠️ 8. Pitfalls

- wrong assignment operator
- latch inference
- sensitivity errors

---

## 🚀 Next Module

SystemVerilog
