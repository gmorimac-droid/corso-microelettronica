
Programmi TCL eseguibili con wish o tclwish.

- [Task Dashboard](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/tcl/task_dashboard.tcl)

- [editor grafico di workflow](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/tcl/workflow_editor.tcl)

# Engineering Workbench — Manuale Tecnico
[Repository](https://github.com/gmorimac-droid/corso-microelettronica/blob/main/code/tcl/WorkBench/)

## 1. Introduzione

L'**Engineering Workbench (Tcl/Tk)** è uno strumento di orchestrazione e analisi progettato per supportare attività di:

* simulazione
* validazione
* gestione test
* analisi risultati

nei seguenti domini:

* sistemi radar
* sistemi satellitari
* sistemi underwater
* progettazione HDL (Verilog/VHDL)

Il workbench funge da **interfaccia operativa unificata** per l'esecuzione e l'analisi di pipeline tecniche.

---

## 2. Scopo del sistema

Il workbench ha lo scopo di:

* standardizzare l’esecuzione di test e simulazioni
* centralizzare log, risultati e metriche
* facilitare il confronto con baseline
* migliorare la tracciabilità delle run

**Nota:** Il workbench non esegue direttamente le simulazioni.
Le elaborazioni sono delegate a strumenti esterni.

---

## 3. Architettura del sistema

### 3.1 Schema funzionale

```text
Workbench (GUI Tcl/Tk)
        ↓
Launcher (CLI orchestration)
        ↓
Strumenti esterni (Python / C++ / Matlab / HDL)
        ↓
Output (log, metriche, report)
        ↓
Analisi (Workbench)
```

---

## 4. Struttura del progetto

### 4.1 Layout standard

```text
project_root/
  workbench_full_integrated_v1.tcl
  configs/
  workflows/
  baselines/
  runs/
  scripts/
  experiments_db.tcl
```

### 4.2 Descrizione delle directory

| Directory          | Descrizione                              |
| ------------------ | ---------------------------------------- |
| configs            | File di configurazione delle simulazioni |
| workflows          | Definizioni pipeline operative           |
| baselines          | Dati di riferimento per validazione      |
| runs               | Output delle esecuzioni                  |
| scripts            | Script eseguibili                        |
| experiments_db.tcl | Database esperimenti                     |

---

## 5. Avvio del sistema

### 5.1 Requisiti

* Tcl/Tk installato
* Interprete `wish`
* Ambiente di esecuzione per script (Python, Matlab, ecc.)

### 5.2 Avvio

```bash
cd project_root
wish workbench_full_integrated_v1.tcl
```

---

## 6. Flusso operativo

### 6.1 Configurazione

1. Preparare file di configurazione
2. Definire eventuale workflow
3. Preparare script eseguibili

---

### 6.2 Esecuzione

Nel tab **Launcher**:

| Campo       | Descrizione            |
| ----------- | ---------------------- |
| Profile     | Tipo di esecuzione     |
| Config path | File di configurazione |
| Case name   | Identificativo run     |
| Output root | Directory output       |
| Workdir     | Directory script       |

---

### 6.3 Comando eseguito

Il workbench costruisce ed esegue:

```bash
<tool> --config <file> --output <dir>
```

---

### 6.4 Output generato

Ogni run produce una directory:

```text
runs/<case_timestamp>/
```

Contenuto minimo:

```text
run.log
metrics.csv
```

Contenuto opzionale:

```text
summary.json
preview.png
report.html
```

---

## 7. Analisi dei risultati

### 7.1 Runtime Log

* Visualizzazione output in tempo reale
* Evidenziazione:

  * ERROR
  * WARN
  * INFO

---

### 7.2 Result Browser

Funzionalità:

* navigazione file
* preview immagini
* apertura log e CSV

---

### 7.3 Log Analyzer

Parsing automatico di:

* ERROR
* WARN
* INFO

Supporta analisi diagnostica delle run.

---

## 8. Validation

### 8.1 File richiesti

#### metrics.csv

```csv
metric,value,min,max
```

#### baseline.csv

```csv
metric,value
```

---

### 8.2 Logica di validazione

| Condizione        | Esito |
| ----------------- | ----- |
| value ∈ [min,max] | PASS  |
| fuori range       | FAIL  |
| soglia assente    | WARN  |

---

## 9. Workflow

### 9.1 Funzionalità

* definizione pipeline
* orchestrazione nodi
* esecuzione sequenziale/logica

### 9.2 Tipi di nodi

* Start
* Process
* Decision
* End

---

## 10. Script esterni

### 10.1 Interfaccia standard

Gli script devono supportare:

```bash
--config <file>
--output <dir>
```

---

### 10.2 Esempio minimo

```python
import argparse, os

parser = argparse.ArgumentParser()
parser.add_argument('--config')
parser.add_argument('--output')
args = parser.parse_args()

os.makedirs(args.output, exist_ok=True)

with open(os.path.join(args.output, "run.log"), "w") as f:
    f.write("INFO start\n")
```

---

## 11. Convenzioni operative

### 11.1 Naming run

```text
runs/<case>_YYYYMMDD_HHMMSS/
```

---

### 11.2 Logging standard

```text
INFO ...
WARN ...
ERROR ...
```

---

### 11.3 Metriche

Formato standard:

```csv
metric,value,min,max
```

---

## 12. Domini applicativi

Il workbench è applicabile a:

### Radar

* detection
* tracking
* SNR analysis

### Satellite

* visibility
* link budget
* coverage

### Underwater

* beamforming
* detection
* classification

### HDL

* simulation
* regression
* coverage

---

## 13. Best Practices

* separare GUI e logica di calcolo
* usare config esterni versionati
* mantenere output standardizzati
* usare baseline per regressione
* uniformare CLI degli script

---

## 14. Limitazioni

* assenza di schema progetto centralizzato completo
* dipendenza da tool esterni
* workflow engine non completamente automatizzato

---

## 15. Estensioni future

Possibili evoluzioni:

* Run History persistente
* Artifact Browser avanzato
* Project schema unificato
* integrazione diretta con Matlab/HDL
* orchestrazione distribuita

---

## 16. Conclusioni

Il workbench rappresenta una piattaforma di:

* orchestrazione tecnica
* analisi strutturata
* validazione sistematica

Il valore del sistema cresce proporzionalmente alla qualità:

* degli script esterni
* delle convenzioni adottate
* della struttura dei dati
