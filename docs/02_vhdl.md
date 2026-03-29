# 02 — VHDL (Hardware Description Language)

## 🎯 Obiettivi

* Comprendere la struttura di un modulo VHDL
* Scrivere il primo codice sintetizzabile
* Capire differenza tra segnali e variabili
* Modellare logica combinatoria e sequenziale

---

## 🧠 1. Cos’è VHDL

VHDL è un linguaggio per descrivere hardware.

👉 NON è un linguaggio software
👉 descrive circuiti reali

---

## 🧩 2. Struttura base

Ogni modulo VHDL è composto da:

* **entity** → interfaccia
* **architecture** → comportamento

---

## 🔧 Esempio minimo

```vhdl
entity and_gate is
  Port (
    A : in STD_LOGIC;
    B : in STD_LOGIC;
    Y : out STD_LOGIC
  );
end and_gate;

architecture rtl of and_gate is
begin
  Y <= A and B;
end rtl;
```

---

## 🔌 3. Tipi principali

### STD_LOGIC

* 0, 1, Z, X

### STD_LOGIC_VECTOR

* array di bit

---

## 🔄 4. Segnali vs Variabili

| Segnali                     | Variabili |
| --------------------------- | --------- |
| asincroni                   | locali    |
| aggiornati dopo il processo | immediati |

👉 errore tipico: confonderli

---

## 🔁 5. Process

Struttura fondamentale per descrivere logica sequenziale.

```vhdl
process(clk)
begin
  if rising_edge(clk) then
    -- codice sequenziale
  end if;
end process;
```

---

## ⏱️ 6. Logica sequenziale

Esempio: registro

```vhdl
process(clk)
begin
  if rising_edge(clk) then
    q <= d;
  end if;
end process;
```

---

## 🔢 7. Contatore (esempio completo)

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity counter is
  Port (
    clk   : in  STD_LOGIC;
    reset : in  STD_LOGIC;
    q     : out STD_LOGIC_VECTOR(3 downto 0)
  );
end counter;

architecture rtl of counter is
  signal count : unsigned(3 downto 0) := (others => '0');
begin

  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        count <= (others => '0');
      else
        count <= count + 1;
      end if;
    end if;
  end process;

  q <= std_logic_vector(count);

end rtl;
```

---

## 🔍 8. Librerie

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
```

👉 sempre usare `numeric_std` (NON std_logic_arith)

---

## ⚠️ 9. Errori comuni

❌ usare `std_logic_arith`
❌ mix segnali/variabili
❌ dimenticare clock
❌ latch involontari

---

## 🧪 10. Esercizi

1. Scrivere una porta OR
2. Implementare un registro a 8 bit
3. Creare un contatore modulo 10

---

## 🚀 Collegamento al prossimo modulo

👉 Nel prossimo capitolo vedremo **Verilog**

## 💻 Codice di riferimento

- [Counter RTL (VHDL)](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/vhdl/project_counter/counter.vhd)
- [Testbench VHDL](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/vhdl/project_counter/tb_counter.vhd)
