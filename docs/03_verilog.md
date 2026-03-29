# 03 — Verilog

## 🎯 Obiettivi

* Comprendere la struttura di un modulo Verilog
* Scrivere logica combinatoria e sequenziale
* Capire differenza tra `wire` e `reg`
* Introdurre lo stile RTL

---

## 🧠 1. Cos’è Verilog

Verilog è un linguaggio per descrivere hardware.

👉 più compatto di VHDL
👉 più vicino al mondo C

---

## 🧩 2. Struttura base

Un modulo Verilog è definito con:

* `module`
* porte di ingresso/uscita
* logica interna

---

## 🔧 Esempio minimo

```verilog
module and_gate (
  input A,
  input B,
  output Y
);

assign Y = A & B;

endmodule
```

---

## 🔌 3. Tipi principali

### wire

* connessione combinatoria

### reg

* usato in blocchi sequenziali

👉 attenzione: `reg` NON è sempre un registro fisico

---

## 🔄 4. Logica combinatoria

```verilog
assign Y = A & B;
```

Oppure:

```verilog
always @(*) begin
  Y = A & B;
end
```

---

## 🔁 5. Logica sequenziale

```verilog
always @(posedge clk) begin
  q <= d;
end
```

👉 uso di `<=` (non blocking) fondamentale

---

## ⚖️ 6. Blocking vs Non-blocking

| Tipo         | Operatore |
| ------------ | --------- |
| Blocking     | =         |
| Non-blocking | <=        |

👉 regola:

* combinatorio → `=`
* sequenziale → `<=`

---

## 🔢 7. Contatore (esempio completo)

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

## 🔍 8. Sensitivity list

```verilog
always @(posedge clk)
```

👉 definisce quando il blocco viene eseguito

---

## ⚠️ 9. Errori comuni

❌ usare `=` nel sequenziale
❌ dimenticare segnali nella sensitivity list
❌ latch involontari
❌ confondere `wire` e `reg`

---

## 🔁 10. Confronto con VHDL

| VHDL                | Verilog     |
| ------------------- | ----------- |
| entity/architecture | module      |
| process             | always      |
| signal              | wire/reg    |
| rising_edge(clk)    | posedge clk |

---

## 🧪 11. Esercizi

1. Scrivere una porta XOR
2. Implementare un registro a 8 bit
3. Creare un contatore modulo 16

---

## 🚀 Collegamento al prossimo modulo

👉 Nel prossimo capitolo vedremo **SystemVerilog**

## 💻 Codice di riferimento

- [Counter RTL (Verilog)](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/verilog/project_counter/counter.v)
- [Testbench Verilog](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/verilog/project_counter/tb_counter.v)
