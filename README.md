# Ottimizzazione della guida per F1 - Circuito di Monza

Progetto di ottimizzazione (Matlab + Python) per stimare una strategia di percorrenza del circuito di Monza, bilanciando:
- tempo sul giro
- consumo di carburante
- limiti fisici di aderenza, accelerazione/frenata e velocita massima

Il lavoro include anche una sezione di reverse engineering per risalire ai parametri di guida (velocita ai nodi) a partire da tempi target storici o personalizzati.

## Obiettivi del progetto

1. Minimizzare il tempo sul giro con vincoli fisici (Punto 1).
2. Estendere il modello includendo il consumo carburante nella funzione obiettivo (Punto 2).
3. Generare un dataset multi-scenario variando aderenza e peso consumo.
4. Effettuare reverse engineering per trovare configurazioni coerenti con tempi storici o target utente.

## Struttura del repository

- `monza_punto_1.m`
  - Ottimizzazione solo tempo (qualifica).
  - Decision variable principali: velocita di picco per tratto.
  - Output: tempi per tratto, tempo totale, top speed e velocita media.

- `monza_punto_2.m`
  - Ottimizzazione ibrida: tempo + consumo.
  - Introduce il parametro `W_consumo` che pesa il costo del carburante.
  - Verifica anche il vincolo di gara (`53 giri`, `145 L`).

- `dataset.py`
  - Sweep parametrico su `mu` (aderenza) e `W` (peso consumo).
  - Per ogni coppia risolve il problema e salva il tempo su `monza_dataset.xlsx`.
  - Crea anche un foglio Excel `README` con metadata del dataset.

- `monza_punto_1_reverse.m`
  - Reverse engineering con modello fisico:
    - modalita storica (serie tempi F1)
    - modalita tempo personalizzato
  - Stima velocita ai nodi coerenti con il tempo target.

- `monza_punto_2_reverse.m`
  - Reverse engineering data-driven su `monza_dataset.xlsx`.
  - Dato un tempo target, cerca coppie (`mu`, `W`) entro tolleranza.
  - Offre menu con tempi storici F1 o input custom.

- `requirements.txt`
  - Dipendenze Python per la generazione dataset.

## Modellazione del circuito

Il circuito e discretizzato in 10 tratti principali:
- S-P1, P1-P2, P2-P3, P3-P4, P4-P5, P5-P6, P6-P7, P7-P8, P8-P9, P9-S

Per ciascun tratto `i`:
- `x_acc(i)`: distanza in accelerazione
- `x_const(i)`: distanza a velocita costante
- `x_brake(i)`: distanza in frenata
- `L(i) = x_acc(i) + x_const(i) + x_brake(i)`

Dati principali usati nei codici:
- lunghezza totale ~5793 m
- velocita massima: 360 km/h
- coefficiente aerodinamico equivalente: `k_aero = 0.387`
- gravita: `g = 9.81 m/s^2`
- massa: tipicamente 620 kg (qualifica) o 722 kg (assetto gara)

## Funzione obiettivo e vincoli

### Punto 1 (solo tempo)

Si minimizza il tempo totale:

`T = sum_i (t_acc(i) + t_const(i) + t_brake(i))`

con approssimazioni cinematiche a velocita media nelle fasi di accelerazione/frenata.

### Punto 2 (tempo + consumo)

Si minimizza una funzione ibrida:

`J = T + W * C`

con:
- `T`: tempo sul giro
- `C`: consumo stimato (proporzionale a `v^2` per tratto/fase)
- `W`: peso strategico del consumo (s/L)

Interpretazione di `W`:
- basso `W`: setup aggressivo, priorita prestazione
- alto `W`: setup conservativo, priorita efficienza carburante

### Vincoli principali

- Vincolo geometrico per ogni tratto:
  - `x_acc + x_const + x_brake = L`
- Bound sulle velocita:
  - `v_lim <= v_peak <= 360 km/h` (con limiti specifici sui tratti curvilinei)
- Vincoli dinamici da bilancio energetico (accelerazione/frenata):
  - energia cinetica richiesta <= lavoro delle forze disponibili
  - contributo del drag aerodinamico incluso
- Vincolo di tenuta in curva (tramite limite su velocita ai nodi)

## Parametri fisici e scenari (dal lavoro presentato)

- Qualifica (scenario tipico):
  - `mu` alto (es. ~3)
  - massa minore (serbatoio scarico)
- Gara (scenario tipico):
  - `mu` ridotto (es. condizioni piu conservative/degrado)
  - massa maggiore con carburante

Nel progetto sono discussi anche:
- differenza tra assetto da qualifica e da gara
- sensibilita del tempo ai parametri fisici
- alert su consumo gara quando si sfora il limite disponibile

## Dataset generato con Python

Lo script `dataset.py` genera combinazioni su griglia:
- `mu` da 1.0 a 3.4/3.5 (step 0.2, in codice fino a 3.4 incluso con `np.arange`)
- `W` da 0.4 a 20.0 (step 0.2)

Nel codice attuale:
- `mu_vals = np.arange(1.0, 3.6, 0.2)`
- `W_vals  = np.arange(0.4, 20.2, 0.2)`
- combinazioni totali: 1287

Output:
- `monza_dataset.xlsx` con foglio `Dataset`:
  - `mu`, `W`, `Tempo [s]`, `Tempo [min]`
- foglio `README` interno con descrizione range e colonne

## Reverse engineering

### Reverse fisico (`monza_punto_1_reverse.m`)

Data una serie di tempi target (storici o custom), stima le velocita ai nodi cercando coerenza fisica con il modello.

Approccio:
- distribuisce il tempo target sui settori (pesi derivati da scenario di riferimento)
- usa `lsqnonlin` per minimizzare residui di tempo per settore
- all interno di ogni valutazione, usa `fmincon` per stimare `v_peak` con vincoli fisici

Output:
- velocita nodali stimate per tratto
- confronto tempo target vs tempo ricostruito
- breakdown per fasi (acc, costante, frenata)

### Reverse data-driven (`monza_punto_2_reverse.m`)

Dato un tempo target:
- cerca nel dataset tutte le righe entro tolleranza (0.1%)
- se non trova match, propone la combinazione piu vicina
- interpreta `mu` come tipologia di aderenza/gomma e `W` come peso consumo

## Come eseguire

## Prerequisiti

- Matlab con Optimization Toolbox (`fmincon`, `lsqnonlin`)
- Python 3.x per `dataset.py`

## Setup Python

```bash
pip install -r requirements.txt
```

## Esecuzione script principali

### 1) Punto 1: solo tempo

In Matlab:

```matlab
run('monza_punto_1.m')
```

### 2) Punto 2: tempo + consumo

In Matlab:

```matlab
run('monza_punto_2.m')
```

### 3) Generazione dataset

In terminale:

```bash
python dataset.py
```

### 4) Reverse engineering fisico

In Matlab:

```matlab
run('monza_punto_1_reverse.m')
```

### 5) Reverse engineering sul dataset

Prima genera il dataset (`monza_dataset.xlsx`), poi:

```matlab
run('monza_punto_2_reverse.m')
```

## Note metodologiche

- Il modello usa una discretizzazione per tratti e una stima semplificata dei tempi in fase di accelerazione/frenata tramite velocita media.
- La parte dinamica e resa con vincoli energetici, includendo la resistenza aerodinamica.
- Le velocita limite in curva dipendono da `mu` e dal raggio/parametri geometrici adottati.
- In ottica gara, il termine di consumo permette di esplorare compromessi prestazione-efficienza.

## Risultati attesi (qualitativi)

- Aumentando `mu`, il modello tende a consentire velocita nodali/di picco maggiori e tempi inferiori.
- Aumentando `W`, il profilo velocita diventa piu conservativo e il consumo stimato diminuisce.
- Il reverse engineering restituisce velocita ai nodi interpretabili rispetto a target cronometrici differenti.

## Autori
- Nicole Bovolenta
- Daniele Cantagallo
- Luca Tortoriello
