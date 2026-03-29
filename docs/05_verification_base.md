# 05 — Verification Base

## 🎯 Obiettivi

* Comprendere il ruolo della verifica
* Scrivere un testbench base
* Introdurre assertions e coverage
* Capire il flusso di simulazione

---

## 🧠 1. Perché la verifica è fondamentale

👉 Scrivere codice corretto NON basta

Un circuito deve essere:

* verificato
* testato
* validato

👉 nella pratica:

* il 70–80% del tempo è verifica

---

## 🧩 2. Cos’è un testbench

Un testbench è un modulo che:

* genera stimoli
* osserva le uscite
* verifica il comportamento

---

## 🔧 3. Struttura di un testbench

```text
Testbench
 ├── DUT (design under test)
 ├── Stimulus
 ├── Monitor
 └── Checker
```

---

## 🔁 4. Esempio base (SystemVerilog)

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

---

## 🔍 5. Monitor

Serve per osservare i segnali:

```systemverilog
initial begin
  $monitor("Time=%0t q=%0d", $time, q);
end
```

---

## ✔️ 6. Checker

Verifica automaticamente il comportamento:

```systemverilog
always @(posedge clk) begin
  if (!reset && q == 4'd10) begin
    $display("Errore!");
  end
end
```

---

## ⚠️ 7. Assertions

Controlli automatici nel codice:

```systemverilog
assert (q < 10)
  else $error("Overflow!");
```

---

## 📊 8. Coverage

Misura quanto il test è completo.

👉 tipi:

* code coverage
* functional coverage

---

## 🔁 9. Flusso di simulazione

1. scrivere RTL
2. scrivere testbench
3. simulare
4. analizzare risultati

---

## ⚠️ 10. Errori comuni

❌ test incompleti
❌ niente assertions
❌ verifiche manuali
❌ non considerare corner case

---

## 🧪 11. Esercizi

1. Scrivere testbench per un contatore
2. Aggiungere assertion
3. Verificare overflow

---

## 🚀 Collegamento al prossimo modulo

👉 Nel prossimo capitolo vedremo **UVM (verification avanzata)**
