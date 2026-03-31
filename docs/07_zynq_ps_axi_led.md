#0. Obiettivo del progetto

Vogliamo ottenere questo:

PS Zynq: esegue un programma C.
AXI GPIO nel PL: espone un registro AXI controllato dal processore.
LED: collegato a un’uscita del blocco AXI GPIO.
Il C scrive sul GPIO e il LED si accende/spegne. Questo è il caso d’uso base del driver XGpio, che assume tipicamente che il bit 0 del canale 1 sia collegato a un LED.
#1. Cosa ti serve prima di iniziare

Ti servono:

una scheda Zynq-7000 o simile,
Vivado per la parte hardware,
Vitis per la parte software bare-metal,
il file di vincoli della board oppure l’infrastruttura board-aware di Vivado,
una connessione JTAG/USB per programmare e fare run del software. Il flusso con Zynq PS + AXI GPIO è coperto nei tutorial embedded AMD aggiornati, e il driver XGpio è documentato ufficialmente nella BSP embeddedsw.
#2. Struttura mentale del progetto

La struttura del design è questa:

ARM (PS) -->  AXI GP master --> AXI interconnect --> AXI GPIO --> LED

Nel tutorial Zynq di AMD, il PS viene inserito nel block design e si collegano IP AXI nel PL tramite i porti GP; l’uso di AXI GPIO per controllare LED è un esempio standard.

#3. File che avrai alla fine
Hardware

In Vivado avrai tipicamente:

project_name.xpr
block design, per esempio design_1.bd
wrapper top, per esempio design_1_wrapper.v
bitstream .bit
export hardware .xsa
Software

In Vitis avrai:

src/main.c
BSP / platform generata da .xsa
xparameters.h con gli indirizzi base dei blocchi AXI
librerie driver, incluso xgpio.h. Il driver XGpio espone funzioni come XGpio_Initialize e la BSP contiene gli identificativi dei device e gli indirizzi necessari.

## HARDWARE

#4. Passo hardware 1: creare il progetto Vivado

In Vivado:

Create Project
scegli nome e cartella
seleziona la tua board oppure il part corretto
crea un progetto RTL “vuoto”

Qui non devi ancora scrivere Verilog: per questo esercizio usiamo IP Integrator. AMD raccomanda proprio l’uso di IP Integrator e della Designer Assistance per assemblare subsystem di base con Zynq e IP AXI.

#5. Passo hardware 2: creare il Block Design

In Vivado:

Create Block Design
chiamalo per esempio design_1

Questo file .bd sarà il cuore del progetto hardware.

Cosa contiene all’inizio

All’inizio è vuoto. Devi aggiungere:

ZYNQ7 Processing System
AXI GPIO

AMD nei tutorial embedded mostra proprio il flusso “Add IP” → inserisci PS e AXI GPIO nel diagramma.

#6. Passo hardware 3: aggiungere il Processing System

Nel block design:

tasto destro → Add IP
cerca ZYNQ7 Processing System
inseriscilo

Poi clicca Run Block Automation.

Cosa fa Block Automation

Configura automaticamente il PS con i collegamenti di base necessari nel block design. AMD descrive questa funzione come parte della Designer Assistance, che aiuta a mettere insieme un subsystem base facendo connessioni standard in automatico.

#7. Passo hardware 4: aggiungere AXI GPIO

Sempre nel block design:

tasto destro → Add IP
cerca AXI GPIO
inseriscilo

Poi fai doppio click su axi_gpio_0 e configuralo così:

GPIO width = 1
All outputs
niente GPIO2, oppure lascialo disattivato se non ti serve

AMD mostra l’uso di AXI GPIO nei propri tutorial embedded e indica la customizzazione del blocco per i GPIO da usare verso il PL.

#8. Passo hardware 5: collegare PS e AXI GPIO

Adesso devi collegare:

interfaccia AXI del PS
clock
reset
bus AXI verso axi_gpio_0

Il modo più semplice è:

cliccare Run Connection Automation

Vivado collegherà automaticamente:

master AXI del PS
slave AXI del GPIO
clock
reset
interconnect, se necessario

AMD documenta proprio questo uso di Connection Automation per fare le connessioni interne standard tra blocchi IP.

#9. Passo hardware 6: portare il GPIO all’esterno

Adesso hai axi_gpio_0, ma il suo segnale deve uscire dal design verso un pin della FPGA.

Nel block design:

seleziona il segnale GPIO del blocco
tasto destro → Make External

Ti verrà creata una porta esterna, spesso chiamata qualcosa come gpio_rtl_0_tri_o.

Cosa rappresenta

È il segnale fisico che poi mapperai su un pin della board, per esempio il LED utente.

#10. Passo hardware 7: assegnare il pin del LED

Qui dipende dalla tua board.

Hai due casi:

Caso A: board files supportati

Vivado può già conoscere alcuni mapping board-aware.

Caso B: file .xdc manuale

Devi aggiungere un file di vincoli con il pin del LED.

Esempio generico .xdc:
```c
set_property PACKAGE_PIN T22 [get_ports gpio_rtl_0_tri_o]
set_property IOSTANDARD LVCMOS33 [get_ports gpio_rtl_0_tri_o]
```
Attenzione
T22 è solo un esempio
devi usare il pin vero della tua scheda
il nome della porta deve coincidere con quello generato nel wrapper
#11. Passo hardware 8: validare il design

In block design:

clicca Validate Design

Questo controlla connessioni mancanti, reset, clock, indirizzi, ecc.

Se ci sono errori, fermati qui e correggili prima di andare avanti.

#12. Passo hardware 9: creare il wrapper HDL

Quando il block design è valido:

tasto destro sul block design
Create HDL Wrapper
scegli Let Vivado manage wrapper

Vivado ti creerà un top-level HDL, tipicamente:

design_1_wrapper.v

Questo è il file top del tuo progetto.

#13. Passo hardware 10: synthesize, implement, generate bitstream

Poi fai:

Run Synthesis
Run Implementation
Generate Bitstream

Alla fine avrai il file .bit.

#14. Passo hardware 11: esportare l’hardware verso Vitis

Da Vivado:

File → Export Hardware oppure usa il flusso equivalente verso Vitis
assicurati di includere il bitstream
otterrai un file .xsa

Questo .xsa contiene:

descrizione hardware
address map AXI
clock/reset
bitstream associato o riferimenti utili per la platform

AMD usa il file hardware export/XSA come base per creare la platform e le applicazioni in Vitis.

##Parte software

#15. Passo software 1: creare la platform in Vitis

In Vitis:

crea un workspace
New Platform Component oppure importa l’hardware dal file .xsa
seleziona lo .xsa esportato da Vivado

Questo genera la platform con la BSP bare-metal e i driver compatibili con l’hardware che hai appena creato. AMD documenta la creazione di application/platform component dal design hardware esportato.

#16. Passo software 2: creare l’applicazione

In Vitis:

New Application Project
scegli la platform appena creata
scegli un template vuoto oppure “Hello World”
chiamala per esempio led_axi_gpio_app

A questo punto il file che ti interessa davvero è:

src/main.c
#17. Passo software 3: capire quali header servono

Per controllare l’AXI GPIO in C servono in genere:

```c
#include "xparameters.h"
#include "xgpio.h"
#include "xil_printf.h"
```

Cosa fanno
xparameters.h: contiene ID e indirizzi generati dalla BSP
xgpio.h: API del driver AXI GPIO
xil_printf.h: stampa debug su UART, se configurata

Il driver XGpio definisce API come XGpio_Initialize, XGpio_SetDataDirection e le strutture istanza necessarie.

#18. Passo software 4: il programma C minimo

Ecco un main.c semplice e corretto per far blinkare il LED.
```c
#include "xparameters.h"
#include "xgpio.h"
#include "xil_printf.h"
```
#define LED_CHANNEL 1

XGpio Gpio;

```c
static void delay_loop(volatile unsigned int count)
{
    while (count--) {
        ;
    }
}

int main(void)
{
    int status;

    xil_printf("Inizializzazione AXI GPIO...\r\n");

    status = XGpio_Initialize(&Gpio, XPAR_AXI_GPIO_0_DEVICE_ID);
    if (status != XST_SUCCESS) {
        xil_printf("Errore: init GPIO fallita\r\n");
        return XST_FAILURE;
    }

    /* Tutti i bit del canale 1 in output */
    XGpio_SetDataDirection(&Gpio, LED_CHANNEL, 0x0);

    xil_printf("Blink LED avviato\r\n");

    while (1) {
        XGpio_DiscreteWrite(&Gpio, LED_CHANNEL, 0x1);
        delay_loop(5000000);

        XGpio_DiscreteWrite(&Gpio, LED_CHANNEL, 0x0);
        delay_loop(5000000);
    }

    return 0;
}
API usate
XGpio_Initialize(...)
XGpio_SetDataDirection(...)
XGpio_DiscreteWrite(...)
```
Sono proprio le primitive base del driver XGpio, documentate negli esempi ufficiali AMD/Xilinx.

#19. Cosa significa XPAR_AXI_GPIO_0_DEVICE_ID

Questo simbolo viene generato automaticamente nella BSP in base all’hardware esportato.
Di solito lo trovi in xparameters.h.

Quindi:

non devi inventarlo a mano
devi solo usare il nome che Vitis ha generato per quel blocco AXI GPIO

Se il blocco non si chiama axi_gpio_0, il nome del define potrebbe cambiare.

#20. Cosa significa XGpio_SetDataDirection(&Gpio, 1, 0x0)

Il secondo argomento è il channel.
Il terzo è una mask di direzione:

bit = 1 → input
bit = 0 → output

Quindi:

XGpio_SetDataDirection(&Gpio, 1, 0x0);

significa: tutti i bit del canale 1 sono uscite. Gli esempi ufficiali XGpio usano proprio il canale 1 e spesso assumono che il bit 0 sia collegato a un LED.

#21. Passo software 5: build e run

In Vitis:

build dell’applicazione
programma la FPGA con l’hardware esportato
lancia l’eseguibile sul target

A livello pratico, Vitis usa la platform basata su .xsa e carica sia hardware sia software sulla board. AMD documenta il flusso di esecuzione di applicazioni embedded dopo la creazione della platform.

Parte di verifica e debug
#22. Se il LED non si accende: ordine di controllo

Controlla in questo ordine:

A. Hardware
axi_gpio_0 è davvero collegato al PS tramite AXI?
gpio_rtl_0_tri_o è stato fatto external?
il pin .xdc è corretto?
hai rigenerato bitstream dopo ogni modifica?
B. Export
hai riesportato il nuovo .xsa dopo le modifiche hardware?
la platform Vitis è allineata all’ultimo hardware?
C. Software
stai usando il DEVICE_ID giusto?
il channel è 1?
la direzione è output?
il delay non è troppo corto per vedere il blink?
23. File minimi che ti consiglio di avere
Vivado
design_1.bd
design_1_wrapper.v
constraints/board_led.xdc
Vitis
src/main.c
#24. Esempio di .xdc da creare

Puoi creare un file, per esempio:

board_led.xdc

con contenuto simile a questo:
```c
set_property PACKAGE_PIN T22 [get_ports gpio_rtl_0_tri_o]
set_property IOSTANDARD LVCMOS33 [get_ports gpio_rtl_0_tri_o]
```
Ripeto: il pin dipende dalla tua board.

#25. Cosa succede internamente, davvero

Questo è il punto chiave da capire:

Il C chiama XGpio_DiscreteWrite(...).
Il driver scrive in un registro del blocco AXI GPIO.
Il PS raggiunge il blocco via AXI.
Il bit del GPIO cambia.
L’uscita del blocco guida il pin del LED.

Questa è l’essenza di PS + AXI + PL su Zynq: il software controlla una periferica hardware memory-mapped. Il driver GPIO e gli esempi ufficiali AMD/Xilinx implementano proprio questo modello di accesso.

#26. Variante ancora più semplice: nessun driver, accesso diretto ai registri

Più avanti puoi anche fare accesso diretto all’indirizzo base del blocco AXI GPIO, ma per iniziare ti consiglio fortemente di usare XGpio, perché è il percorso documentato e più pulito. Gli esempi ufficiali sul driver GPIO sono pensati proprio per questo uso di base.

#27. Sequenza completa riassunta
In Vivado
Create Project
Create Block Design
Add ZYNQ7 Processing System
Run Block Automation
Add AXI GPIO
Configure AXI GPIO as 1-bit output
Run Connection Automation
Make GPIO external
Add .xdc for LED pin
Validate Design
Create HDL Wrapper
Generate Bitstream
Export Hardware (.xsa)
In Vitis
Create platform from .xsa
Create bare-metal application
scrivi main.c
build
program/run target
#28. Il tuo primo mini-progetto completo

Questi sono i soli artefatti che devi davvero scrivere a mano all’inizio:

main.c

Quello che ti ho già dato.

board_led.xdc

Con il pin LED corretto.

Tutto il resto viene generato da Vivado/Vitis.

#29. Cosa farei io come prossimo step dopo questo

Dopo che questo funziona, i due step naturali sono:

sostituire AXI GPIO con un tuo IP custom AXI-Lite,
oppure aggiungere più LED / switch / pulsanti e leggere input oltre a scrivere output.

Questo segue direttamente il percorso dei tutorial embedded AMD che usano AXI GPIO come periferica di base nel PL collegata al PS.