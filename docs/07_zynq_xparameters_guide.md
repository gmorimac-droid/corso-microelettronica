# 🧠 Come leggere xparameters.h (senza impazzire)

Questo file è generato automaticamente da Vitis e contiene:

👉 **tutti i parametri hardware del tuo design**

- indirizzi base
- ID periferiche
- interrupt
- configurazioni

---

# 🔵 1. Cos'è davvero xparameters.h

👉 È una **mappa software dell’hardware**

Traduce il tuo Block Design Vivado in macro C.

---

# 🎯 Regola d’oro

👉 **NON lo modifichi mai a mano**

👉 Lo leggi e lo usi

---

# 🧠 2. Struttura mentale

Pensa così:

```text
Vivado → hardware → export (.xsa)
        ↓
Vitis → xparameters.h
        ↓
C code
```

---

# 🔍 3. Esempio reale

Dentro trovi cose tipo:

```c
#define XPAR_AXIDMA_0_DEVICE_ID 0
#define XPAR_AXIDMA_0_BASEADDR 0x40400000
#define XPAR_AXIDMA_0_MM2S_INTROUT_INTR 61
#define XPAR_AXIDMA_0_S2MM_INTROUT_INTR 62
```

---

# 🧠 Traduzione

| Macro | Significato |
|------|------------|
| DEVICE_ID | identificatore driver |
| BASEADDR | indirizzo memoria |
| INTR | interrupt ID |

---

# 🔵 4. Tipi di macro principali

---

## 🟢 4.1 DEVICE_ID

```c
XPAR_AXIDMA_0_DEVICE_ID
```

👉 usato per inizializzare driver

```c
XAxiDma_LookupConfig(DEVICE_ID)
```

---

## 🔵 4.2 BASEADDR

```c
XPAR_AXI_GPIO_0_BASEADDR
```

👉 indirizzo memoria

Serve per accesso diretto:

```c
*(volatile int*)(BASEADDR + offset)
```

---

## 🔴 4.3 INTERRUPT

```c
XPAR_FABRIC_AXI_DMA_0_MM2S_INTROUT_INTR
```

👉 ID interrupt per GIC

Usato in:

```c
XScuGic_Connect(...)
```

---

## 🟡 4.4 HIGHADDR

```c
XPAR_AXI_GPIO_0_HIGHADDR
```

👉 fine range memoria

---

# 🧠 5. Naming pattern (IMPORTANTISSIMO)

Tutti seguono questo schema:

```text
XPAR_<IP>_<INSTANCE>_<PARAM>
```

---

## Esempio

```c
XPAR_AXI_DMA_0_BASEADDR
```

| Parte | Significato |
|------|-----------|
| AXI_DMA | tipo IP |
| 0 | istanza |
| BASEADDR | parametro |

---

# 🔥 6. Dove trovare quello che ti serve

---

## 🎯 Caso 1 — DMA

Cerca:

```text
AXIDMA
```

---

## 🎯 Caso 2 — GPIO

```text
GPIO
```

---

## 🎯 Caso 3 — interrupt

```text
INTR
```

---

# ⚙️ 7. Uso reale nel codice

---

## Inizializzazione DMA

```c
#define DMA_DEV_ID XPAR_AXIDMA_0_DEVICE_ID

XAxiDma_Config *CfgPtr;
CfgPtr = XAxiDma_LookupConfig(DMA_DEV_ID);
```

---

## Interrupt DMA

```c
#define TX_INTR_ID XPAR_FABRIC_AXI_DMA_0_MM2S_INTROUT_INTR
#define RX_INTR_ID XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR
```

---

## Accesso diretto memoria

```c
#define BASE XPAR_AXI_GPIO_0_BASEADDR

*(volatile int*)(BASE) = 1;
```

---

# ⚠️ 8. Errori tipici

---

## ❌ Usare nomi hardcoded

```c
#define DMA_DEV_ID 0
```

👉 sbagliato

---

## ✅ Corretto

```c
#define DMA_DEV_ID XPAR_AXIDMA_0_DEVICE_ID
```

---

## ❌ Copiare codice da internet

👉 ogni progetto ha numeri diversi

---

## ❌ Non aggiornare la platform

Se cambi hardware ma non aggiorni:

👉 xparameters.h è sbagliato

---

# 🔥 9. Problema classico (IMPORTANTISSIMO)

---

## Sintomo

```text
DMA non funziona
```

---

## Causa

👉 `.xsa` non aggiornato

---

## Soluzione

1. Export hardware
2. Update platform in Vitis

---

# 🧠 10. Come leggere velocemente il file

---

## Metodo pratico

### STEP 1

Cerca nome IP:

```text
CTRL + F → AXIDMA
```

---

### STEP 2

Trova:

- DEVICE_ID
- BASEADDR
- INTR

---

### STEP 3

Usali nel codice

---

# 🔍 11. Esempio completo

```c
#define DMA_DEV_ID XPAR_AXIDMA_0_DEVICE_ID
#define TX_INTR_ID XPAR_FABRIC_AXI_DMA_0_MM2S_INTROUT_INTR

XAxiDma_Config *CfgPtr;
CfgPtr = XAxiDma_LookupConfig(DMA_DEV_ID);
```

---

# 🧠 12. Insight importante

👉 xparameters.h = **colla tra HW e SW**

Se sbagli qui:

❌ tutto il sistema si rompe

---

# 🚀 13. Livello avanzato

Nel file trovi anche:

- larghezze bus
- configurazioni IP
- parametri clock

---

# 🎯 14. Regola finale

👉 NON memorizzare i valori

👉 memorizza il **pattern**

---

# 🧠 Frase chiave

👉 **xparameters.h è la mappa del tuo hardware vista dal software**

---

# ✅ Checklist rapida

- [ ] uso sempre macro XPAR
- [ ] non hardcodare numeri
- [ ] aggiorno platform dopo Vivado
- [ ] verifico interrupt ID
- [ ] verifico BASEADDR

---

# 🎉 Conclusione

Se capisci questo file:

👉 sei in grado di collegare correttamente PS ↔ PL

👉 hai fatto un salto enorme come embedded engineer

---