# Presentazione del corso

## Perché questo corso

La progettazione microelettronica digitale è uno dei punti di incontro più importanti tra:
- teoria dei circuiti digitali;
- architettura dei sistemi hardware;
- linguaggi RTL;
- verifica;
- implementazione su FPGA, ASIC e SoC.

Molto spesso però questi temi vengono studiati in modo frammentato:
- da una parte la logica combinatoria e sequenziale;
- da un’altra i linguaggi HDL;
- altrove ancora i flussi di sintesi, verifica o integrazione di sistema.

Questo corso nasce per evitare proprio questa frammentazione.

L’obiettivo non è insegnare solo una sintassi, né limitarsi a una raccolta di definizioni teoriche. L’obiettivo è costruire una comprensione coerente della progettazione digitale come disciplina unitaria, in cui:
- i segnali portano informazione;
- i registri strutturano il tempo;
- il controllo governa il comportamento;
- il datapath realizza la funzione;
- l’RTL traduce l’architettura;
- la verifica mette davvero alla prova il progetto;
- il contesto finale di implementazione cambia le priorità ma non i fondamenti.

In questo senso, il corso è pensato come una vera base progettuale, utile sia in ambito universitario sia come preparazione seria a contesti professionali.

---

## Che cosa troverai in questo corso

Il corso è costruito come un percorso progressivo che parte dai concetti fondamentali e arriva a una lettura architetturale completa del blocco digitale.

Nel percorso vengono affrontati in modo ordinato:
- segnali, bit e rappresentazione dell’informazione;
- logica combinatoria;
- logica sequenziale e memoria;
- clock, reset e comportamento nel tempo;
- registri, multiplexer e datapath;
- FSM e logica di controllo;
- pipeline, latenza e throughput;
- interfacce e handshake;
- passaggio dal comportamento all’RTL;
- sintesi, area e timing;
- errori comuni di progettazione;
- verifica di base e debug;
- passaggio dal blocco al sistema;
- differenze di sensibilità tra FPGA, ASIC e SoC;
- caso di studio conclusivo.

Il risultato è un corso che non si limita a spiegare “che cosa sono” i singoli concetti, ma cerca di mostrare come collaborino nella costruzione di una microarchitettura reale.

---

## A chi è rivolto

Questo corso è pensato soprattutto per:
- studenti di ingegneria elettronica, informatica o affini;
- chi sta iniziando a studiare VHDL, Verilog o SystemVerilog e vuole una base concettuale più forte;
- chi ha già visto un HDL ma sente di non avere ancora una visione solida di datapath, controllo, timing e verifica;
- chi vuole un ponte ordinato verso argomenti più avanzati come FPGA, ASIC, SoC e UVM.

Può essere utile anche a chi ha già una certa familiarità con la progettazione digitale ma desidera:
- ripassare i concetti fondamentali;
- consolidare il lessico architetturale;
- rileggere i blocchi hardware con una struttura mentale più chiara.

---

## Che cosa non è questo corso

È utile chiarire anche che cosa questo corso **non** vuole essere.

Non è:
- un manuale di un tool specifico;
- un corso limitato a un singolo linguaggio HDL;
- una raccolta di sole formule di logica booleana;
- una guida esclusivamente orientata alla sintassi;
- un corso avanzato di verification methodology.

Questa sezione è invece una base comune, costruita per rendere più leggibili e più naturali tutte le sezioni successive del percorso.

---

## Il metodo del corso

Il corso adotta un’impostazione precisa.

### 1. Prima i concetti, poi i linguaggi
Si parte dalla comprensione di:
- informazione;
- stato;
- tempo;
- controllo;
- datapath;
- integrazione.

Solo dopo questi concetti diventano davvero leggibili dentro un HDL.

### 2. Lettura architetturale dei blocchi
Ogni argomento viene trattato cercando di rispondere non solo a:
- “che cos’è?”
ma anche a:
- “che ruolo ha nel progetto?”
- “come si collega al resto?”
- “che cosa implica per timing, controllo e verifica?”

### 3. Attenzione al comportamento temporale
Il corso insiste molto sul fatto che i sistemi digitali non si capiscono davvero senza leggere:
- cicli;
- latenza;
- validità del dato;
- aggiornamento dello stato;
- rapporto tra registri e logica combinatoria.

### 4. Collegamento con il progetto reale
Anche quando il taglio è introduttivo, la prospettiva resta sempre progettuale:
- come si organizza una microarchitettura;
- come si ragiona su area e timing;
- come si verifica un blocco;
- come si integra un modulo in un sistema più grande.

---

## Che cosa imparerai davvero

Alla fine del corso non avrai semplicemente incontrato una serie di parole chiave. Avrai costruito una struttura mentale più solida per leggere e progettare blocchi digitali.

In particolare, dovresti riuscire a:
- distinguere con chiarezza logica combinatoria e sequenziale;
- capire il ruolo di clock, reset e stato;
- leggere registri, mux, FSM e datapath come elementi architetturali;
- comprendere il significato di pipeline, latenza e throughput;
- interpretare le interfacce come contratti di comunicazione;
- capire il passaggio dalla specifica alla microarchitettura e poi all’RTL;
- leggere un blocco anche dal punto di vista di sintesi, area e timing;
- impostare una verifica di base e un debug ordinato;
- collocare i moduli dentro sistemi più grandi e nei contesti FPGA, ASIC e SoC.

---

## Perché questo corso è propedeutico agli altri

Uno degli scopi principali del corso è fare da base comune per il resto del materiale.

Questa sezione prepara in modo naturale a:
- **VHDL**, **Verilog** e **SystemVerilog**, perché rende più chiaro che cosa si stia descrivendo quando si scrive RTL;
- **FPGA** e **ASIC**, perché introduce già i concetti di sintesi, area, timing e compromesso architetturale;
- **SoC**, perché porta a leggere il blocco come parte di un sistema;
- **UVM** e verifica più strutturata, perché chiarisce prima i fondamenti del comportamento da verificare.

In altre parole, questo corso prova a costruire le fondamenta su cui gli altri branch possono poggiare con maggiore naturalezza.

---

## Come è organizzato il percorso

Il corso è costruito come una progressione in quattro movimenti principali.

### Fondamenti del comportamento digitale
Qui si costruiscono le basi:
- informazione;
- combinatoria;
- sequenziale;
- tempo.

### Blocchi architetturali fondamentali
Qui compaiono:
- registri;
- mux;
- datapath;
- FSM;
- pipeline;
- interfacce.

### Traduzione nel progetto reale
Qui si affrontano:
- passaggio all’RTL;
- sintesi;
- area;
- timing;
- errori comuni;
- verifica e debug.

### Allargamento alla scala di sistema
Qui il blocco viene riletto come parte di:
- una gerarchia;
- un sistema;
- un contesto FPGA, ASIC o SoC.

Il percorso si chiude poi con un caso di studio che ricompone tutto in un esempio unitario.

---

## Lo stile delle lezioni

Le lezioni del corso seguono una linea precisa:
- spiegazione chiara;
- rigore tecnico;
- linguaggio accessibile ma non superficiale;
- attenzione al significato progettuale;
- uso di esempi e schemi per chiarire i punti importanti.

Quando utile, vengono introdotti:
- diagrammi a blocchi;
- schemi temporali concettuali;
- esempi di microarchitettura;
- piccoli richiami a RTL o protocolli.

L’idea è accompagnare lo studente non solo a “riconoscere” i concetti, ma a saperli collegare tra loro.

---

## Che atteggiamento richiede il corso

Questo corso premia soprattutto un certo modo di guardare i sistemi digitali.

Conviene affrontarlo non chiedendosi solo:
- “che cos’è un registro?”
- “che cos’è una FSM?”
- “che cos’è un mux?”

ma anche:
- “perché serve?”
- “che ruolo ha nella microarchitettura?”
- “che cosa cambia nel tempo?”
- “come influisce sul controllo, sulla verifica e sul sistema?”

Questo cambio di prospettiva è una parte fondamentale del valore del corso.

---

## In sintesi

Questo corso è una introduzione strutturata ai fondamenti della progettazione microelettronica digitale.

Non è costruito per insegnare solo una sintassi o solo una teoria astratta. È costruito per aiutarti a vedere il progetto digitale come un insieme coerente di:
- informazione;
- stato;
- tempo;
- controllo;
- datapath;
- interfacce;
- RTL;
- verifica;
- integrazione di sistema.

Se seguito con continuità, il corso fornisce una base molto solida per affrontare in modo più maturo tutto ciò che viene dopo:
- HDL;
- FPGA;
- ASIC;
- SoC;
- verifica avanzata.

## Prossimo passo

Il modo più naturale di usare questa pagina è metterla come **pagina di presentazione del corso** prima dell’`index.md` della sezione, oppure fonderne parti nell’`index.md` stesso per avere una apertura più editoriale e istituzionale del percorso.
