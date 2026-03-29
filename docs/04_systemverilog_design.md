# 04 — SystemVerilog (Design)

## 🎯 Obiettivi

* Comprendere le estensioni di Verilog
* Scrivere codice RTL più sicuro e leggibile
* Usare costrutti moderni (logic, always_ff, enum, struct)
* Evitare errori tipici di Verilog

---

## 🧠 1. Cos’è SystemVerilog

SystemVerilog è un’estensione di Verilog.

👉 include:

* miglioramenti per il design RTL
* strumenti per la verifica

---

## 🔧 2. Tipo `logic`

Sostituisce `wire` e `reg`.

```systemverilog
logic a;
logic [3:0] data;
```

✔ più semplice
✔ meno errori

---

## 🔁 3. always_ff (sequenziale)

```systemverilog
always_ff @(posedge clk) begin
  q <= d;
end
```

✔ garantisce codice sequenziale corretto
✔ evita errori di sintesi

---

## 🔄 4. always_comb (combinatorio)

```systemverilog
always_comb begin
  y = a & b;
end
```

✔ sensitivity list automatica
✔ evita latch involontari

---

## 🔷 5. enum (fondamentale per FSM)

```systemverilog
typedef enum logic [1:0] {
  IDLE,
  RUN,
  STOP
} state_t;

state_t state;
```

✔ leggibilità altissima
✔ codice più sicuro

---

## 🧩 6. struct

```systemverilog
typedef struct {
  logic [7:0] data;
  logic valid;
} packet_t;

packet_t pkt;
```

---

## 🔗 7. interface

Permette di raggruppare segnali.

```systemverilog
interface bus_if;
  logic clk;
  logic [7:0] data;
endinterface
```

---

## 🔢 8. Contatore (esempio moderno)

```systemverilog
module counter (
  input  logic       clk,
  input  logic       reset,
  output logic [3:0] q
);

  always_ff @(posedge clk or posedge reset) begin
    if (reset)
      q <= 4'd0;
    else
      q <= q + 1;
  end

endmodule
```

---

## ⚖️ 9. Verilog vs SystemVerilog

| Verilog     | SystemVerilog           |
| ----------- | ----------------------- |
| reg/wire    | logic                   |
| always      | always_ff / always_comb |
| meno sicuro | più robusto             |

---

## ⚠️ 10. Errori comuni

❌ usare `always` invece di `always_ff`
❌ mescolare combinatorio e sequenziale
❌ ignorare enum
❌ codice poco leggibile

---

## 🧪 11. Esercizi

1. Scrivere un contatore usando `always_ff`
2. Creare una FSM con `enum`
3. Usare una `struct` per un pacchetto dati

---

## 🚀 Collegamento al prossimo modulo

👉 Nel prossimo capitolo vedremo la **Verification Base**

## 💻 Codice di riferimento

- [Counter RTL (SystemVerilog)](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/systemverilog/project_counter/counter.sv)
- [Testbench SystemVerilog](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/systemverilog/project_counter/tb_counter.sv)
