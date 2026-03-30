
## DESCRIZIONE

Questo è un altro capitolo con poco codice Verilog vero e proprio, ma è anche un capitolo difficile da ignorare quando si inizia a sviluppare un progetto reale.

Sono finiti i tempi in cui i circuiti digitali erano completamente TTL e l’unico problema di interfacciamento era scegliere tra chip DIP “AS” o “ALS”.
Oggi, con l’enfasi sulle alte velocità, una grande parte del design della scheda elettronica consiste nel coordinare con attenzione segnali di interfaccia specializzati, assicurandosi che i segnali di I/O dei circuiti integrati siano compatibili.

Le FPGA hanno un grande vantaggio:

supportano molti standard di interfaccia
sono configurabili quasi pin per pin

In questo capitolo vengono analizzate le principali categorie di interfacce.

Interfacce di segnale

Le interfacce oggi sono numerosissime:
LVCMOS, LVDS, HSTL, LVPECL, SSTL, ecc.

Ogni standard definisce parametri come:

livelli di tensione
slew rate
soglie di commutazione
differenziale vs single-ended
terminazione
impedenza di pilotaggio

Le FPGA moderne permettono di controllare molti di questi parametri.

Parametri aggiuntivi configurabili
delay inserito
drive strength
pull-up / pull-down / keeper
tri-state
Come si configurano?

Tramite tre metodi:

primitive I/O nel codice Verilog
tensioni esterne sui pin dedicati
constraint di progetto
Constraint

Ogni progetto FPGA ha due parti:

codice (Verilog/VHDL)
constraint (file di configurazione)

I constraint definiscono:

assegnazione pin
timing
configurazione I/O

Sono specifici per vendor e dispositivo.

Output voltage levels

I livelli di tensione vanno da 3.3V a meno di 1V.
I pin sono organizzati in banchi (banks):

👉 tutti i pin nello stesso bank condividono la tensione

⚠️ Questo crea vincoli progettuali importanti.

Slew rate

Velocità di salita/discesa del segnale:

slow
fast

Configurato per pin.

Switching thresholds

Definiti via constraint.
Alcuni standard richiedono tensione di riferimento esterna.

Differenziale vs single-ended

Differenziale:

usa coppie di pin
richiede primitive specifiche nel codice
attenzione alla polarità

Single-ended:

default
Impedenza e terminazione

Le FPGA possono emulare resistenze interne:

serie
parallelo

Vantaggi:

meno componenti esterni
migliori prestazioni ad alta velocità

Configurazione tramite:

resistenze esterne di riferimento
primitive I/O
Delay inserito

Delay programmabile:

aggiusta setup/hold
può essere dinamico
utile per alte velocità
Drive strength

Corrente di uscita configurabile (es. 2mA, 4mA…)

Serve per:

controllare riflessioni
migliorare integrità del segnale

Trade-off:

troppo basso → lento
troppo alto → rumore
Tri-state

Uscite ad alta impedenza:

via Verilog
via primitive
Pull-up / Pull-down / Keeper
Pull-up/down → tengono il segnale a 1 o 0
Keeper → mantiene l’ultimo valore

Usati per:

evitare segnali flottanti
stabilizzare bus tri-state

##ESEMPI UTILI E REALI

# 🔌 I/O Flavors – Practical FPGA Examples

In real FPGA designs, configuring I/O is a fundamental task that goes far beyond simply writing Verilog code. Every signal that enters or leaves the FPGA must be carefully defined in terms of electrical behavior, timing, and compatibility with external hardware.

This section presents practical examples of how I/O features are used in real designs.

---

## 💡 LED Output (LVCMOS)

A basic example is driving an LED. The FPGA output pin must use the correct voltage standard and drive strength.

```verilog
assign led = 1'b1;
```

```tcl
set_property PACKAGE_PIN W5 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
set_property DRIVE 8 [get_ports led]
```

---

## 🔘 Button Input (Pull-up)

Inputs must never be left floating. A pull-up resistor ensures a defined logic level.

```verilog
always @(posedge clk)
    if (button)
        led <= 1'b1;
```

```tcl
set_property PACKAGE_PIN V10 [get_ports button]
set_property IOSTANDARD LVCMOS33 [get_ports button]
set_property PULLUP true [get_ports button]
```

---

## 🔁 Bidirectional Bus (Tri-state)

Tri-state logic allows multiple devices to share a bus.

```verilog
assign data = (wr_en) ? data_out : 16'bz;
assign data_in = data;
```

```tcl
set_property IOSTANDARD LVCMOS33 [get_ports data]
```

---

## ⏱️ DDR Interface (Inserted Delay)

High-speed interfaces require precise timing alignment.

```verilog
IDELAYE2 #(
    .DELAY_VALUE(10)
) idelay_inst (
    .IDATAIN(data_in),
    .DATAOUT(data_delayed)
);
```

Inserted delays help satisfy setup and hold constraints.

---

## ⚡ Differential Signaling (LVDS)

Differential signals improve noise immunity at high speed.

```verilog
IBUFDS ibufds_inst (
    .I(clk_p),
    .IB(clk_n),
    .O(clk)
);
```

```tcl
set_property IOSTANDARD LVDS [get_ports {clk_p clk_n}]
```

---

## 🔌 Internal Termination

FPGA devices can emulate termination resistors internally.

```tcl
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports data_in]
```

This reduces the need for external resistors and improves signal integrity.

---

## 🌊 Slew Rate Control

Controlling signal transitions helps reduce noise.

```tcl
set_property SLEW SLOW [get_ports led]
```

---

## 🔋 Drive Strength

Output current can be tuned depending on the load.

```tcl
set_property DRIVE 12 [get_ports data]
```

or

```tcl
set_property DRIVE 4 [get_ports data]
```

Higher drive increases speed but also noise.

---

## ⏱️ Clock Generation (PLL)

PLLs are used to generate new clock frequencies.

```verilog
clk_wiz_0 clk_gen (
    .clk_in1(clk_in),
    .clk_out1(clk_200MHz)
);
```

---

## ⚠️ Common Design Error

A very common mistake is mixing different voltage standards within the same I/O bank.

Example (WRONG):
- 3.3V signal
- 1.8V signal

Since all pins in a bank share the same supply voltage, this will cause design failure or hardware damage.

---

## 🧠 Summary

FPGA I/O configuration combines Verilog code and constraint definitions. Key features used in real designs include:

- Voltage standards (LVCMOS, LVDS, etc.)
- Pull-up and pull-down resistors
- Tri-state buses
- Inserted delays for timing
- Differential signaling
- Internal termination
- Slew rate control
- Drive strength tuning
- Clock management (PLL)

Mastering these concepts is essential for building reliable and high-performance FPGA systems.