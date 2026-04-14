# Verifica di base e debug

Dopo aver costruito i fondamenti della progettazione digitale e aver raccolto gli errori più comuni, il passo successivo naturale è spostare l’attenzione sul lato della **validazione**. In questa pagina il focus è su due attività strettamente collegate:
- la **verifica di base**
- il **debug**

Questa lezione è molto importante perché un blocco digitale non può essere considerato “buono” solo perché la sua architettura sembra sensata o perché l’RTL appare ordinato. Un progetto serio richiede anche la capacità di:
- applicare stimoli significativi;
- osservare il comportamento nel tempo;
- confrontare il risultato ottenuto con quello atteso;
- localizzare gli errori;
- distinguere problemi del blocco da problemi dell’ambiente di prova.

Dal punto di vista progettuale, questa pagina serve a chiarire:
- che cosa significhi davvero verificare un blocco digitale;
- perché simulazione e debug siano parte del progetto e non attività accessorie;
- come leggere un comportamento temporale in modo utile;
- quali segnali convenga osservare;
- come costruire una mentalità di verifica già a livello dei fondamenti.

Questa pagina mantiene il taglio della sezione:
- didattico ma tecnico;
- concettuale ma vicino al progetto reale;
- orientato alla comprensione del comportamento del blocco;
- accompagnato da schemi ed esempi quando utili.

```mermaid
flowchart LR
    TB["Ambiente di prova"] --> STIM["Stimoli"]
    STIM --> DUT["Blocco da verificare"]
    DUT --> OBS["Osservazione"]
    OBS --> CHECK["Confronto con atteso"]
    CHECK --> DBG["Debug"]

    style DUT fill:#eef6ff,stroke:#1f6feb
    style CHECK fill:#eefbf0,stroke:#22863a
```

## 1. Perché serve la verifica

La prima domanda utile è: perché non basta che il progetto “sembri corretto”?

### 1.1 Perché la correttezza intuitiva non basta
Molti blocchi:
- sembrano ben progettati;
- hanno una struttura sensata;
- passano casi semplici a livello mentale;

ma possono comunque nascondere errori in:
- stato;
- controllo;
- latenza;
- protocollo;
- interfacce;
- timing osservabile.

### 1.2 Perché il comportamento va osservato
Un progetto digitale evolve nel tempo. Bisogna quindi verificare non solo:
- che cosa produce;
ma anche:
- quando lo produce;
- in quali condizioni;
- dopo quanti cicli;
- con quale protocollo.

### 1.3 Perché è importante
La verifica è la parte del flusso che mette davvero alla prova la microarchitettura.

---

## 2. Che cos’è la verifica di base

La **verifica di base** è l’insieme delle attività con cui si controlla che un blocco si comporti come previsto nelle condizioni di interesse.

### 2.1 Significato essenziale
Verificare un blocco significa:
- fornire ingressi o stimoli;
- osservare uscite e segnali rilevanti;
- confrontare il comportamento osservato con quello atteso.

### 2.2 Perché è importante
La verifica non riguarda solo il risultato finale, ma anche:
- sequenza delle azioni;
- gestione del clock;
- reset iniziale;
- transizioni di stato;
- corretto uso dei protocolli.

### 2.3 Visione intuitiva
La verifica è il momento in cui il progetto smette di essere una ipotesi e diventa un oggetto da testare in modo concreto.

---

## 3. Che cos’è il debug

Il **debug** è l’attività con cui si cerca di capire:
- dove nasce un comportamento scorretto;
- quale segnale si rompe per primo;
- se il problema è nel blocco o nell’ambiente di prova;
- quale parte della microarchitettura va corretta.

### 3.1 Perché è diverso dalla semplice osservazione
Osservare dice che qualcosa è successo. Fare debug significa ricostruire:
- la causa;
- la sequenza degli eventi;
- il punto reale del guasto.

### 3.2 Perché è importante
Il debug è la prova della qualità del progetto e della leggibilità dei suoi segnali interni.

### 3.3 Messaggio progettuale
Un buon progetto è spesso anche più facile da debuggare.

---

## 4. Verifica e microarchitettura

Una delle idee più importanti di questa pagina è che la verifica non si appoggia solo sulla funzione del blocco, ma sulla sua microarchitettura.

### 4.1 Perché
Per verificare bene un modulo bisogna sapere:
- dove stanno i registri;
- quale sia la latenza;
- quali siano i segnali di controllo;
- che ruolo abbiano gli stati della FSM;
- quando un dato diventa valido.

### 4.2 Perché è importante
Senza una lettura architetturale del blocco, la verifica rischia di restare superficiale.

### 4.3 Conseguenza
Verifica e progettazione sono attività profondamente intrecciate.

---

## 5. Stimoli: il primo passo della verifica

Ogni verifica inizia da uno o più **stimoli**.

### 5.1 Che cosa sono
Gli stimoli sono i valori e le sequenze temporali applicate agli ingressi del blocco.

### 5.2 Perché sono importanti
Gli stimoli determinano:
- quali casi stiamo provando;
- in quale ordine;
- in quale momento;
- rispetto a quale riferimento temporale.

### 5.3 Perché non basta “muovere i segnali”
Uno stimolo utile deve rappresentare:
- un caso nominale;
- un caso limite;
- una situazione interessante dal punto di vista del controllo;
- una sequenza che possa rivelare bug strutturali.

---

## 6. Stimoli per blocchi combinatori

Nel caso di un blocco combinatorio, la verifica tende a essere più semplice.

### 6.1 Che cosa si fa
Si applicano diverse combinazioni di ingressi e si osserva l’uscita corrispondente.

### 6.2 Che cosa conta
- coprire i casi principali;
- coprire le condizioni limite;
- verificare che l’uscita segua la funzione attesa.

### 6.3 Perché è importante
Anche nel combinatorio bisogna comunque ricordare che la verifica non riguarda solo il “valore giusto”, ma anche il modo coerente di osservare la rete.

---

## 7. Stimoli per blocchi sequenziali

Nel caso di blocchi sequenziali, la verifica deve tenere conto del tempo.

### 7.1 Che cosa significa
Gli stimoli vanno letti rispetto a:
- clock;
- reset;
- stato corrente;
- ciclo in cui l’input viene applicato;
- ciclo in cui il risultato deve apparire.

### 7.2 Perché è importante
Molti errori non emergono da un valore sbagliato in assoluto, ma dal fatto che:
- il dato viene campionato nel ciclo sbagliato;
- l’uscita compare troppo presto o troppo tardi;
- il reset non porta davvero il blocco nello stato iniziale atteso.

### 7.3 Conseguenza
La verifica dei blocchi sequenziali è sempre anche verifica del comportamento temporale.

---

## 8. Il ruolo del reset nella verifica

Il reset è uno dei primi elementi da controllare in un blocco sequenziale.

### 8.1 Perché
Se il reset non funziona come previsto:
- la FSM può partire in uno stato sbagliato;
- i registri possono avere valori inattesi;
- il testbench può interpretare male il comportamento iniziale.

### 8.2 Che cosa conviene osservare
- quando il reset viene attivato;
- quando viene rilasciato;
- quale stato iniziale assume il blocco;
- quali segnali funzionali partono in modo definito.

### 8.3 Perché è importante
Molti bug apparenti del blocco derivano in realtà da una lettura sbagliata della fase di reset.

---

## 9. Il ruolo del clock nella verifica

Anche il clock è centrale nella verifica dei blocchi sequenziali.

### 9.1 Perché
Molte osservazioni devono essere lette in corrispondenza dei fronti di clock o in relazione ai cicli.

### 9.2 Che cosa conviene chiedersi
- il dato è stato applicato prima del fronte rilevante?
- il registro si è aggiornato nel ciclo corretto?
- la FSM è avanzata nel passo atteso?
- la pipeline ha effettivamente fatto avanzare il dato di uno stadio?

### 9.3 Perché è importante
Il clock è la griglia temporale su cui si interpreta quasi tutta la verifica sequenziale.

---

## 10. Comportamento atteso

Il cuore della verifica è sempre il confronto con il **comportamento atteso**.

### 10.1 Che cosa significa
Per ogni caso di prova bisogna avere chiaro:
- quale risultato aspettarsi;
- in quale ciclo;
- in quale stato;
- con quali segnali di validità o protocollo.

### 10.2 Perché è importante
Senza comportamento atteso esplicito, l’osservazione rischia di diventare vaga o interpretata a posteriori.

### 10.3 Messaggio progettuale
Verificare bene significa rendere esplicita la relazione tra:
- ingresso applicato;
- architettura del blocco;
- risultato atteso nel tempo.

---

## 11. Verifica di datapath e controllo

Molti moduli richiedono di verificare sia il percorso dati sia il comportamento del controllo.

### 11.1 Datapath
Conviene osservare:
- dati in ingresso;
- registri intermedi;
- uscita finale;
- latenza del dato;
- allineamento tra input e output.

### 11.2 Controllo
Conviene osservare:
- stato della FSM;
- segnali di enable;
- selettori di mux;
- segnali di validità;
- transizioni tra fasi operative.

### 11.3 Perché è importante
Molti bug stanno proprio nel rapporto tra:
- dato che avanza;
- controllo che dovrebbe governarlo.

---

## 12. Verifica delle interfacce

Le interfacce richiedono una verifica specifica.

### 12.1 Che cosa conviene controllare
- quando il dato è dichiarato valido;
- quando il consumer lo accetta;
- se il protocollo viene rispettato;
- se il dato resta stabile quando richiesto;
- se esistono perdita o duplicazione di trasferimenti.

### 12.2 Perché è importante
Molti blocchi interni funzionano bene, ma falliscono nel momento dell’integrazione proprio a causa di protocolli interpretati male.

### 12.3 Conseguenza
La verifica delle interfacce è una parte fondamentale della qualità del progetto.

---

## 13. Simulazione come strumento di verifica

Uno degli strumenti più importanti della verifica di base è la **simulazione**.

### 13.1 Che cosa permette
- applicare stimoli;
- osservare il comportamento nel tempo;
- confrontare segnali e stati;
- leggere la risposta del blocco ai fronti di clock;
- controllare protocolli e latenza.

### 13.2 Perché è importante
La simulazione rende visibile il comportamento dinamico del progetto.

### 13.3 Perché non basta da sola
Simulare tanto non garantisce automaticamente una buona verifica. Conta:
- quali casi si provano;
- quali segnali si osservano;
- che cosa ci si aspetta;
- come si interpreta il risultato.

---

## 14. Waveform e osservazione temporale

Le waveform sono uno degli strumenti più potenti per leggere il comportamento del blocco.

### 14.1 Che cosa mostrano
- ingressi;
- uscite;
- clock;
- reset;
- stato;
- registri intermedi;
- segnali di validità;
- enable e controllo.

### 14.2 Perché sono importanti
Le waveform permettono di rispondere a domande come:
- l’uscita è giusta ma nel ciclo sbagliato?
- il reset ha realmente inizializzato il blocco?
- la FSM cambia stato nel momento previsto?
- il dato si ferma in uno stadio di pipeline?

### 14.3 Conseguenza
La verifica di base è spesso inseparabile dalla capacità di leggere bene una waveform.

---

## 15. Da osservazione a verifica strutturata

Un altro passaggio importante è distinguere:
- semplice osservazione;
- verifica davvero utile.

### 15.1 Osservazione semplice
Guardo le waveform e cerco di capire “a occhio” se il comportamento sembra corretto.

### 15.2 Verifica più strutturata
Definisco:
- casi di prova;
- risultati attesi;
- momenti in cui il controllo deve valere;
- segnali da osservare in modo sistematico.

### 15.3 Perché è importante
Anche senza entrare in metodologie avanzate, è già utile impostare una mentalità più disciplinata.

---

## 16. Che cosa osservare per primi durante il debug

Quando emerge un errore, non conviene guardare subito tutto.

### 16.1 Primo livello
Conviene partire da:
- clock;
- reset;
- ingressi principali;
- uscite osservate;
- segnali di validità o completamento.

### 16.2 Secondo livello
Se l’errore non è chiaro, si passa a:
- stato della FSM;
- registri intermedi;
- mux selezionati;
- segnali di controllo;
- stadi di pipeline.

### 16.3 Perché è importante
Un debug ordinato riduce molto il rumore e aiuta a trovare il punto reale dell’errore.

---

## 17. Debug di blocchi combinatori

Il debug combinatorio ha alcune caratteristiche specifiche.

### 17.1 Che cosa conviene cercare
- combinazioni di ingressi che producono uscita errata;
- casi limite non coperti;
- condizioni di selezione sbagliate;
- comparazioni o decodifiche interpretate male.

### 17.2 Perché è importante
Anche un blocco senza stato può nascondere errori di struttura o di interpretazione funzionale.

### 17.3 Segnale tipico di problema
L’uscita non riflette correttamente la funzione attesa per una certa combinazione di input.

---

## 18. Debug di blocchi sequenziali

Il debug sequenziale richiede sempre una lettura nel tempo.

### 18.1 Che cosa conviene cercare
- stato iniziale dopo reset;
- aggiornamento corretto dei registri;
- transizione di stato al ciclo atteso;
- latenza del dato;
- coerenza tra controllo e percorso dati.

### 18.2 Perché è importante
Molti bug sembrano “funzionali”, ma in realtà sono errori di allineamento temporale.

### 18.3 Domanda chiave
Il blocco fa la cosa giusta **nel momento giusto**?

---

## 19. Debug di pipeline e latenza

Quando il blocco ha più stadi, il debug deve seguire il dato nel tempo.

### 19.1 Che cosa conviene osservare
- ingresso del dato;
- registri di stadio;
- uscita finale;
- segnali di validità;
- eventuali stall o attese.

### 19.2 Perché è importante
Il dato può essere corretto ma comparire con una latenza diversa da quella attesa.

### 19.3 Conseguenza
Per le pipeline il debug è spesso anche debug della cronologia del dato.

---

## 20. Debug delle interfacce e degli handshake

Un altro caso molto importante è il debug delle interfacce.

### 20.1 Che cosa conviene controllare
- quando `valid` sale e scende;
- quando `ready` è attivo;
- se il dato resta stabile finché richiesto;
- se il trasferimento avviene davvero quando previsto;
- se il producer o il consumer si comportano in modo scorretto.

### 20.2 Perché è importante
Molti errori di integrazione non sono nel dato, ma nella disciplina del trasferimento.

### 20.3 Messaggio progettuale
Il debug del protocollo è spesso il debug più istruttivo per capire davvero un sistema.

---

## 21. Errori comuni nella verifica

Ci sono alcuni errori molto frequenti che indeboliscono la verifica di base.

### 21.1 Verificare solo il caso nominale
Si ignorano:
- reset;
- casi limite;
- sequenze anomale;
- condizioni di attesa;
- protocolli incompleti.

### 21.2 Guardare troppi segnali senza criterio
La waveform diventa difficile da leggere e il debug si confonde.

### 21.3 Non definire bene l’atteso
Si finisce per decidere “a posteriori” se il comportamento sembra sensato.

### 21.4 Confondere bug del blocco e bug dell’ambiente di prova
A volte il DUT è corretto ma lo stimolo o l’osservazione sono impostati male.

### 21.5 Trascurare la dimensione temporale
Molti errori emergono solo guardando correttamente i cicli e i fronti di clock.

---

## 22. Buone pratiche di verifica e debug

Anche a livello introduttivo esistono alcune ottime abitudini.

### 22.1 Parti sempre dal comportamento atteso
Prima di simulare, chiarisci:
- che cosa deve succedere;
- in quale ordine;
- con quale latenza.

### 22.2 Verifica prima reset e clock
Sono la base della lettura temporale del blocco.

### 22.3 Osserva pochi segnali ma quelli giusti
Inizia da:
- ingressi;
- uscite;
- stato;
- registri chiave;
- segnali di validità o controllo.

### 22.4 Segui il percorso del dato
Se il dato è sbagliato, chiediti:
- dove si rompe per primo?

### 22.5 Pensa alla verifica già durante il progetto
Un buon blocco è più facile da testare, osservare e debuggare.

---

## 23. Collegamento con il resto della sezione

Questa pagina si collega direttamente alle prossime tappe del branch:
- **`from-block-to-system.md`**, perché la verifica cambia ancora quando il blocco viene inserito in un sistema più grande;
- **`fpga-asic-soc-contexts.md`**, dove verifica, osservabilità e debug avranno sfumature diverse nei vari contesti progettuali;
- **`case-study.md`**, che ricomporrà tutti i concetti della sezione in un esempio unico, includendo anche il lato della validazione.

Si collega inoltre a quasi tutte le pagine precedenti, perché:
- ogni datapath va verificato;
- ogni FSM va osservata;
- ogni pipeline va controllata nel tempo;
- ogni interfaccia va validata secondo il proprio protocollo.

---

## 24. In sintesi

La verifica di base e il debug sono il passaggio che trasforma un blocco progettato in un blocco davvero compreso e validato.

- La **verifica** applica stimoli e confronta il comportamento con l’atteso.
- La **simulazione** rende visibile il comportamento nel tempo.
- Le **waveform** aiutano a leggere clock, reset, stato, dati e protocolli.
- Il **debug** isola la causa reale dell’errore.

Capire bene questi temi significa completare il ciclo fondamentale della progettazione digitale: non solo costruire una microarchitettura, ma anche dimostrare che si comporta nel modo giusto.

## Prossimo passo

Il passo successivo naturale è **`from-block-to-system.md`**, perché adesso conviene allargare la prospettiva e vedere come un blocco digitale, una volta progettato e verificato, si inserisca in un sistema più grande:
- gerarchia
- integrazione tra moduli
- interconnessioni
- ruolo dell’architettura di sistema
