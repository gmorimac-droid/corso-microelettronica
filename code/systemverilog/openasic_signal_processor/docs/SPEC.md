# OpenASIC Signal Processor — SPEC

## 1. Obiettivo del progetto

Realizzare un ASIC digitale che riceve campioni tramite SPI, li bufferizza, li elabora con un filtro FIR a 8 tap, applica una decimazione programmabile e rende disponibile il risultato tramite uscita parallela e registri di stato.

Il progetto è pensato per essere:

- completamente realizzabile con tool gratuiti
- verificabile a livello RTL
- sintetizzabile e instradabile con flow open-source
- abbastanza articolato da rappresentare un progetto ASIC realistico

---

## 2. Requisiti funzionali

Il chip deve:

1. ricevere configurazione e dati via SPI slave
2. memorizzare temporaneamente i campioni in una FIFO sincrona
3. applicare un filtro FIR a 8 tap a coefficienti fissi
4. applicare una decimazione programmabile da 1 a 16
5. esporre registri di controllo e stato
6. fornire in uscita:
   - ultimo campione elaborato
   - flag di validità
   - flag di busy / done / overflow / underflow

---

## 3. Parametri principali

| Parametro | Valore |
|----------|--------|
| Clock principale | 10 MHz |
| Reset | attivo basso |
| Larghezza dati | 16 bit signed |
| Coefficienti FIR | fissi |
| Numero tap FIR | 8 |
| Decimazione | 1..16 |
| FIFO depth | 16 parole |
| Domini di clock | 1 nella V1 |

---

## 4. Interfacce esterne

### Ingressi
- `clk`
- `rst_n`
- `spi_sclk`
- `spi_cs_n`
- `spi_mosi`

### Uscite
- `spi_miso`
- `data_out[15:0]`
- `data_valid`
- `busy`
- `irq` (opzionale nella V1)

---

## 5. Formato dati

### Campioni
- signed 16 bit
- complemento a due

### Coefficienti FIR
Valori fissi nella V1:

```text
h[0] = -8
h[1] =  0
h[2] = 40
h[3] = 96
h[4] = 96
h[5] = 40
h[6] =  0
h[7] = -8
```

Somma = 256  
Normalizzazione: shift destro di 8 bit dopo accumulo.

---

## 6. Mappa registri

### 0x00 — CTRL
| Bit | Nome | Descrizione |
|-----|------|-------------|
| 0 | enable | abilita il processamento |
| 1 | soft_reset | reset interno moduli |
| 2 | start | avvia l’elaborazione |
| 3 | bypass_fir | bypass del FIR |
| 4 | bypass_decim | bypass del decimatore |

### 0x04 — STATUS
| Bit | Nome | Descrizione |
|-----|------|-------------|
| 0 | busy | pipeline attiva |
| 1 | done | elaborazione completata |
| 2 | fifo_overflow | overflow FIFO |
| 3 | fifo_underflow | underflow FIFO |
| 4 | data_valid | `data_out` valido |

### 0x08 — DECIM_FACTOR
| Bit | Nome | Descrizione |
|-----|------|-------------|
| [3:0] | decim_factor | fattore di decimazione |

### 0x0C — INPUT_COUNT
Numero campioni ricevuti.

### 0x10 — OUTPUT_COUNT
Numero campioni prodotti.

### 0x14 — DATA_OUT
Ultimo campione elaborato.

---

## 7. Modalità operative

### 7.1 Register access mode
La SPI viene usata per:
- scrivere registri
- leggere registri
- configurare il chip

### 7.2 Sample input mode
La SPI invia campioni al blocco FIFO/datapath.

---

## 8. Flusso elaborativo

1. il campione entra via SPI
2. viene scritto nella FIFO
3. il FIR calcola il campione filtrato
4. il decimatore decide se produrre output
5. se l’output è valido:
   - aggiorna `data_out`
   - alza `data_valid`
   - incrementa `OUTPUT_COUNT`

---

## 9. Casi di test minimi

### Smoke test
- reset
- scrittura registri
- start/stop pipeline

### FIR test
- risposta all’impulso
- risposta a gradino
- rampa crescente

### Decimation test
- fattore = 1
- fattore = 2
- fattore = 4
- fattore = 8

### FIFO test
- overflow
- underflow

### SPI test
- read/write registri
- trasferimento campioni

---

## 10. Vincoli progettuali

### V1
- un solo clock interno
- niente multi-clock
- niente SRAM macro esterne
- niente coefficienti FIR programmabili
- niente DMA o bus complessi
- niente CPU embedded

### Obiettivo V1
Chiudere un progetto completo:
- RTL
- simulazione
- sintesi
- placement & routing
- STA
- DRC / LVS
- GDS finale

---

## 11. Criteri di completamento

Il progetto è considerato completato quando:

- tutti i test RTL essenziali passano
- la sintesi è pulita
- il flow ASIC termina senza errori bloccanti
- il clock target di 10 MHz è supportato
- DRC/LVS risultano puliti o con issue documentate
- viene generato il GDS

---

## 12. Estensioni future

### V2
- coefficienti FIR scrivibili via registri
- interrupt completo
- FIFO più grande

### V3
- FIR 16 tap
- modalità bypass dinamica
- memoria interna di debug
- interfaccia output più ricca
