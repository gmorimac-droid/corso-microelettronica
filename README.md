# Corso di Microelettronica Digitale

Repository base per un corso su:
- VHDL
- Verilog
- SystemVerilog
- Verification e UVM
- Tool FPGA e ASIC
- Script TCL e flow di progetto

## Avvio locale

```bash
python3 -m pip install -r requirements.txt
mkdocs serve
```

Apri poi `http://127.0.0.1:8000`.

## Pubblicazione su GitHub Pages

Il workflow `.github/workflows/deploy.yml` pubblica automaticamente il sito quando fai push su `main`.

## Struttura

- `docs/`: contenuti del corso in MkDocs
- `code/`: esempi di codice e script
- `mkdocs.yml`: navigazione del sito
