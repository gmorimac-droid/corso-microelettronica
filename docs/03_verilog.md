# 03 — Verilog

## Obiettivi

Questo modulo introduce Verilog da una **prospettiva di progettazione FPGA/ASIC**, con attenzione al **RTL sintetizzabile** e alle sue implicazioni hardware.

Al termine del modulo sarai in grado di:
- comprendere la **modellazione RTL in Verilog**
- descrivere correttamente **logica combinatoria e logica sequenziale**
- distinguere tra **semantica di `wire` e `reg`**
- applicare pratiche di progetto consapevoli rispetto al **timing**

---

## 1. Verilog nella progettazione hardware

Verilog è un **linguaggio di descrizione hardware (HDL)** ampiamente utilizzato in ambito industriale.

### Flusso di progetto tipico

RTL → Sintesi → Netlist → Place & Route → Bitstream

Ogni costrutto del linguaggio viene ricondotto a **strutture hardware concrete**.

---

## 2. Logica combinatoria

```verilog
assign Y = A & B;
```

Hardware:

A ----\
       AND ----> Y
B ----/

Caratteristiche principali:
- non usa clock
- contribuisce al **cammino critico**

---

## 3. Logica sequenziale

```verilog
always @(posedge clk) begin
  q <= d;
end
```

Caratteristiche principali:
- genera flip-flop
- definisce stadi di pipeline

---

## 4. `wire` vs `reg`

| Tipo | Significato |
|------|-------------|
| wire | connessione |
| reg  | assegnazione procedurale |

`reg` **non** significa automaticamente registro hardware.

---

## 5. Blocking vs non-blocking

- `=` → tipicamente usato per logica combinatoria  
- `<=` → tipicamente usato per logica sequenziale  

Un uso scorretto può portare a **mismatch tra simulazione e hardware atteso**.

---

## 6. Esempio: contatore

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

## 7. Prospettiva di timing

Cammino critico:

FF → Logica → FF

Possibili direzioni di ottimizzazione:
- inserire pipeline
- ridurre la profondità logica

---

## 8. Errori comuni

- uso scorretto dell’operatore di assegnazione
- inferenza involontaria di latch
- errori nella sensitivity list

---

## Modulo successivo

SystemVerilog
