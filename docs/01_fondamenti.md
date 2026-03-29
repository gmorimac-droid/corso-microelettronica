# 01 — Fondamenti di Logica Digitale

## 🎯 Obiettivi

* Comprendere la logica combinatoria e sequenziale
* Capire il concetto di tempo nei circuiti digitali
* Prepararsi alla scrittura di HDL

---

## 🔢 1. Sistemi digitali

Un sistema digitale elabora informazioni usando **valori discreti** (tipicamente 0 e 1).

### Esempi:

* CPU
* FPGA
* ASIC

---

## 🔌 2. Logica combinatoria

La logica combinatoria è un sistema in cui:

👉 l’uscita dipende SOLO dagli ingressi attuali

### Esempio: porta AND

| A | B | Y |
| - | - | - |
| 0 | 0 | 0 |
| 0 | 1 | 0 |
| 1 | 0 | 0 |
| 1 | 1 | 1 |

---

## ⏱️ 3. Logica sequenziale

Qui entra il tempo:

👉 l’uscita dipende da:

* ingressi attuali
* stato precedente

---

## 🔁 4. Flip-Flop

Elemento base della memoria digitale.

### Tipi:

* D Flip-Flop
* JK
* T

### Comportamento:

* aggiorna stato al fronte di clock

---

## ⏰ 5. Clock

Segnale fondamentale nei sistemi digitali.

👉 sincronizza tutto

### Parametri:

* frequenza
* periodo
* duty cycle

---

## 🔄 6. Registri

Gruppi di flip-flop.

👉 usati per:

* memorizzare dati
* pipeline
* stato

---

## 🔀 7. Finite State Machine (FSM)

Sistema con stati discreti.

### Componenti:

* stati
* transizioni
* ingressi
* uscite

---

## 🧪 8. Esempio: contatore

Un contatore è un esempio di sistema sequenziale:

* stato = valore corrente
* aggiorna a ogni clock

---

## ⚠️ 9. Concetti fondamentali

### Setup time

Tempo minimo prima del clock

### Hold time

Tempo minimo dopo il clock

### Propagation delay

Tempo di propagazione del segnale

---

## 🧠 10. Combinatorio vs Sequenziale

| Tipo         | Dipendenza       |
| ------------ | ---------------- |
| Combinatorio | ingressi         |
| Sequenziale  | ingressi + stato |

---

## 🧪 Esercizi

1. Disegna una tabella di verità per XOR
2. Progetta un contatore modulo 4
3. Descrivi una FSM per un semaforo

---

## 🚀 Collegamento al prossimo modulo

👉 Nel prossimo modulo useremo questi concetti in **VHDL**
