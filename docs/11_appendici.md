# 11 — Appendici

## 🎯 Obiettivi

* Fornire riferimenti rapidi
* Definire standard di progetto
* Consolidare buone pratiche
* Supportare il lavoro professionale

---

## 🧠 1. Coding Style

### ✔ Regole generali

* nomi chiari e consistenti
* indentazione uniforme
* commenti significativi

---

### 🔧 Esempio (SystemVerilog)

```systemverilog
module counter (
  input  logic clk,
  input  logic reset,
  output logic [3:0] count
);
```

✔ nomi chiari
✔ formattazione pulita

---

## 🔤 2. Naming Convention

| Tipo    | Esempio |
| ------- | ------- |
| clock   | clk     |
| reset   | rst     |
| segnali | data_in |
| moduli  | uart_tx |

---

## 📦 3. Struttura progetto

```text
project/
 ├── rtl/
 ├── tb/
 ├── sim/
 ├── scripts/
 └── docs/
```

---

## 🔁 4. Workflow consigliato

```text
Edit → Simulate → Debug → Fix → Repeat
```

👉 iterativo

---

## 🧪 5. Checklist di verifica

✔ codice sintetizzabile
✔ testbench completo
✔ assertions presenti
✔ timing verificato

---

## 📊 6. Debug

### Strategie:

* usare monitor
* analizzare waveform
* isolare problemi

---

## 📚 7. Riferimenti

### Libri:

* Digital Design (Morris Mano)
* CMOS VLSI Design

---

### Standard:

* IEEE VHDL
* IEEE SystemVerilog

---

## 🔧 8. Tool utili

* simulatori
* editor (VS Code)
* Git

---

## ⚠️ 9. Best Practices

✔ verificare sempre
✔ scrivere codice leggibile
✔ modularizzare
✔ usare version control

---

## 🚀 10. Prossimi passi

* progetti avanzati
* UVM completo
* design ASIC reale

---

## 🎉 Fine del corso

Complimenti!

Hai completato un percorso completo di:

* design digitale
* verifica
* implementazione
* tool professionali

👉 sei pronto per lavorare su progetti reali
