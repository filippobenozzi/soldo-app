<div align="center">
  <img src="altstore/icon.png" width="120" alt="Schei">
  <h1>Schei</h1>
  <p><strong>Un modo veloce e minimale per segnare le spese, sincronizzate con il tuo vault Obsidian.</strong></p>
  <p>Nessun account · Nessun abbonamento · Nessuna pubblicità · Nessun tracciamento</p>
</div>

---

Schei è un tracciatore di spese per iPhone e iPad, pensato per chi tiene le proprie
note e i propri dati in **Obsidian**. Registri una spesa in due secondi con un
tastierino dedicato, e Schei la scrive nel tuo vault come normale file Markdown —
leggibile, versionabile, tuo.

L'app è ispirata a [SyncSpend](https://apps.apple.com/app/syncspend/id6759112033),
di cui riprende l'impostazione, con tre differenze sostanziali:

| SyncSpend | Schei |
| --- | --- |
| Sincronizzazione con **Notion** (API, account, token) | Sincronizzazione con **Obsidian**: scegli la cartella del vault, si scrive su file |
| **Abbonamento Pro** (mensile, annuale, a vita) | Tutto gratis, nessun paywall nel codice |
| Sincronizzazione **iCloud** fra dispositivi | Il vault fa da archivio condiviso; in più c'è export/import JSON |

Schei è un progetto indipendente, non affiliato con SyncSpend né con i suoi autori.

## Funzionalità

- **Registrazione rapida** — tastierino numerico dedicato, categorie e conti a portata di pollice, data con scorciatoie Oggi/Ieri.
- **Sincronizzazione Obsidian** in quattro formati, con anteprima dal vivo nelle impostazioni.
- **Scansione dello scontrino** — inquadri, e importo, negozio e data si compilano da soli, dopo una schermata di conferma che mostra cosa è stato letto. Dal nome e dalla via stampati Schei risale al posto, quindi alle coordinate e alla categoria.
- **Luogo automatico** — quando apri una nuova spesa, Schei riconosce il negozio in cui ti trovi, lo propone come esercente e sceglie la categoria dal tipo di posto.
- **Spesa veloce** — dal Centro di Controllo, dalla schermata di blocco o dal tasto Azione: si apre il tastierino, digiti l'importo e tocchi Fatto. Luogo e categoria arrivano da soli, e un terzo pulsante inquadra lo scontrino.
- **Widget** — totale del mese e budget (piccolo, medio), ultime spese (medio, grande) e widget per la schermata di blocco.
- **Comandi rapidi** — azioni `Aggiungi spesa`, `Apri nuova spesa`, `Totale speso`, `Sincronizza`, utilizzabili con Siri, Tocco posteriore, tasto Azione e automazioni Apple Pay.
- **Analisi** — grafici per giorno, per mese e per categoria, confronto col periodo precedente e proiezione di fine mese.
- **Budget mensile** opzionale, con anello di avanzamento su Home e nei widget.
- **Categorie e conti** personalizzabili: nome, icona SF Symbol, colore, ordinamento, archiviazione.
- **Backup JSON** esportabile e importabile, opzionalmente scritto anche nel vault.

## Aspetto

Schei è **in bianco e nero**, come l'app da cui prende le mosse: sfondo `#F5F5F5`,
schede bianche, inchiostro nero, badge `#EDEDED`, e nessun colore d'accento. In modo
scuro tutto si inverte. Le categorie hanno comunque un colore, usato solo se attivi
*Impostazioni › Icone a colori*; altrimenti i grafici a torta usano una scala di grigi.

## Scontrini e luoghi

**Scansione.** Dal pulsante in alto a destra della schermata di inserimento puoi
inquadrare uno scontrino o scegliere una foto. Schei usa lo scanner di sistema
(ritaglio e raddrizzamento automatici) e poi Vision per il riconoscimento del testo,
in italiano e inglese, abbassando la soglia di altezza minima del testo — quella
predefinita è pensata per cartelli, non per la stampa fitta di uno scontrino.

Il parser ricostruisce le righe stampate unendo i frammenti che stanno alla stessa
altezza — è questo che gli permette di leggere `TOTALE ... 12,50` come una riga sola —
e poi cerca:

- **l'importo**, dando la precedenza a `TOTALE COMPLESSIVO`, `TOTALE DA PAGARE`,
  `IMPORTO PAGATO`, `TOTALE EURO`, `TOTAL`; ignorando `SUBTOTALE`, `IVA`, `SCONTO`,
  `RESTO`, `ARROTONDAMENTO`; e leggendo la riga successiva quando la cifra è a capo.
  Se non trova nessuna parola chiave usa l'importo più alto dello scontrino;
- **il negozio**, dalle prime righe, scartando indirizzi, partite IVA e diciture fiscali;
- **la data e l'ora**, in formato italiano o americano;
- **via, CAP e città**, e la partita IVA.

**Conferma prima di compilare.** Il risultato non finisce dritto nei campi: appare
una schermata che mostra l'importo trovato, il negozio, la data e — in fondo — tutto
il testo riconosciuto. Se il totale è sbagliato, tocchi una delle altre cifre lette
sullo scontrino; se non è stato letto nulla, lo vedi subito e capisci perché.

**Dal negozio al luogo.** Con nome e via, Schei interroga Apple Maps e ottiene il
posto: coordinate, categoria del punto di interesse e quindi la categoria di spesa.

**Dove sei.** Se dai il permesso, aprendo una nuova spesa Schei cerca i punti di
interesse nel raggio di 160 metri e propone il più vicino. Puoi cambiarlo dall'elenco
dei posti vicini. La corrispondenza fra tipo di posto e categoria è in
[`PlaceCategoryTable.swift`](Schei/Location/PlaceCategoryTable.swift): supermercati e
panetterie → Spesa, ristoranti e bar → Ristoranti, distributori e parcheggi →
Trasporti, farmacie → Salute, e così via. Il confronto avviene sul *nome* della
categoria, quindi continua a funzionare anche se rinomini le tue.

Nulla di tutto questo esce dal telefono se non verso Apple Maps per la singola
ricerca: la posizione viene letta solo mentre registri una spesa, mai in background,
e le foto degli scontrini non vengono salvate.

## Come Schei scrive nel vault

In **Impostazioni › Obsidian** scegli la cartella del vault (una qualsiasi cartella
raggiungibile dall'app File: iCloud Drive, `Su iPhone › Obsidian`, una chiavetta…)
e il formato di scrittura. L'accesso viene conservato con un *security-scoped
bookmark*, quindi va concesso una volta sola.

<details>
<summary><strong>Una nota per spesa</strong> — front matter YAML, pronta per Dataview (predefinito)</summary>

`Schei/Spese/2026-08-28 Coop 12.50.md`

```markdown
---
tipo: spesa
id: 6f1a2b3c-4d5e-6f70-8192-a3b4c5d6e7f8
data: 2026-08-28
ora: "14:32"
importo: 12.50
valuta: EUR
categoria: Spesa
conto: Carta
esercente: Coop
luogo: Coop Via Verdi
location: [44.493810, 11.342720]
coordinate: "44.49381, 11.34272"
tags:
  - spesa
---

# Coop — 12,50 €

**Data:** 2026-08-28 14:32 · **Categoria:** Spesa · **Conto:** Carta

**Luogo:** [Coop Via Verdi](https://maps.apple.com/?ll=44.49381,11.34272&q=Coop)

Pane e latte
```

`location` è la chiave che leggono i plugin di mappa di Obsidian, quindi le tue spese
compaiono da sole sulla mappa del vault.

Modificando la spesa in Schei la nota viene aggiornata; se cambia il nome del file,
la vecchia nota viene rimossa. Eliminando la spesa, la nota viene cancellata.
</details>

<details>
<summary><strong>Nota unica</strong> — una tabella Markdown</summary>

`Schei/Spese.md`

```markdown
| Data | Ora | Importo | Valuta | Categoria | Conto | Esercente | Luogo | Nota |
| --- | --- | ---: | --- | --- | --- | --- | --- | --- |
| 2026-08-28 | 14:32 | 12.50 | EUR | Spesa | Carta | Coop | Coop Via Verdi | Pane e latte |
```

Il file viene **rigenerato per intero** a ogni sincronizzazione, così modifiche ed
eliminazioni fatte in Schei si riflettono sempre. Non modificarlo a mano.
</details>

<details>
<summary><strong>Nota giornaliera</strong> — una riga nel diario del giorno</summary>

`Diario/2026-08-28.md`

```markdown
## Spese

- **12,50 €** · Coop · Spesa · Carta — Pane e latte ^soldo-6f1a2b3c4d5e
```

Schei crea la nota se non esiste e inserisce la riga in fondo alla sezione indicata,
**senza toccare il resto del file**. Il block reference finale (`^soldo-…`) le
permette di ritrovare la riga per aggiornarla o eliminarla, e ti permette di
linkarla da altre note.
</details>

<details>
<summary><strong>CSV</strong> — per fogli di calcolo e dataviewjs</summary>

`Schei/Spese.csv`

```csv
id,data,ora,importo,valuta,categoria,conto,esercente,luogo,latitudine,longitudine,nota
"6f1a…","2026-08-28","14:32","12.50","EUR","Spesa","Carta","Coop","Coop Via Verdi","44.493810","11.342720","Pane e latte"
```

Come la nota unica, viene rigenerato a ogni sincronizzazione.
</details>

Percorso, nome dei file, formato della data, titolo della sezione e template del
nome nota sono tutti configurabili. I segnaposto disponibili sono
`{{data}}`, `{{ora}}`, `{{importo}}`, `{{valuta}}`, `{{categoria}}`, `{{conto}}`,
`{{esercente}}`, `{{nota}}`, `{{id}}`.

## Installazione con AltStore

1. Installa [AltStore](https://altstore.io) (o SideStore) sul tuo iPhone.
2. In AltStore apri **Browse › Sources › +** e aggiungi:

   ```
   https://raw.githubusercontent.com/filippobenozzi/soldo-app/main/altstore/source.json
   ```

3. Apri la sorgente **Schei** e installa l'app.

In alternativa scarica `Schei.ipa` dall'ultima
[release](https://github.com/filippobenozzi/soldo-app/releases) e installala con
AltStore o Sideloadly.

### Cose da sapere sul sideloading

- Con un **Apple ID gratuito** le app firmate scadono dopo **7 giorni**: AltStore le
  rinnova da solo finché AltServer è raggiungibile.
- Sempre con un Apple ID gratuito puoi tenere **3 app** attive alla volta, e
  **ogni estensione conta come un'app**. Schei con il widget ne occupa quindi due.
  Per questo ogni release contiene anche **`Schei-no-widget.ipa`**: stessa app, senza
  estensione widget, un solo slot.
- L'**App Group** `group.im.filippo.soldo` è usato sia dal widget sia dal database,
  così la spesa veloce può scrivere senza avviare l'app. Se il tuo metodo di
  sideloading non riesce a registrarlo, l'app continua a funzionare normalmente: il
  database resta nel contenitore dell'app, il widget resta vuoto e la spesa veloce
  ripiega sull'apertura della schermata di inserimento.
- Passando dalla 1.1.0 alla 1.2.0 il database viene **copiato** nel contenitore
  condiviso: l'originale non viene mai cancellato, e se la copia non riesce Schei
  continua a usare quello di prima.
- Il controllo del Centro di Controllo richiede iOS 18 o successivo.
- Impostazioni › Info mostra se il **contenitore condiviso** è attivo: è la prova che
  l'App Group è stato registrato. Se dice «non disponibile», i widget resteranno
  vuoti — l'app funziona lo stesso.

## Compilare in locale

Serve un Mac con Xcode 16 o superiore.

```bash
git clone https://github.com/filippobenozzi/soldo-app.git
cd soldo-app
./Tools/bootstrap.sh   # installa XcodeGen se manca e genera Schei.xcodeproj
open Schei.xcodeproj
```

Il file `.xcodeproj` non è versionato: viene generato da
[XcodeGen](https://github.com/yonaskolb/XcodeGen) a partire da `project.yml`.

Per compilare l'IPA non firmata come fa la CI:

```bash
xcodebuild archive -project Schei.xcodeproj -scheme Schei -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -archivePath build/Schei.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
./Tools/package-ipa.sh build/Schei.xcarchive artifacts/Schei.ipa
```

Le verifiche — export Obsidian su cartelle vere, parser degli scontrini su testo di
scontrini reali, tabella dei luoghi — girano senza simulatore:

```bash
./Tools/run-checks.sh
```

## Pubblicare una nuova versione

La CI (`.github/workflows/build.yml`) compila a ogni push e pubblica una release
quando trova un tag:

```bash
git tag v1.0.1 && git push origin v1.0.1
```

Oppure da **Actions › Build › Run workflow**, indicando la versione. La CI crea la
release con le due IPA e aggiorna da sola `altstore/source.json`, così AltStore vede
subito l'aggiornamento.

## Automazioni

Il controllo **Spesa veloce** — per Centro di Controllo, schermata di blocco e tasto
Azione — apre il tastierino di Schei: importo, Fatto, finito. Il luogo e la categoria
vengono rilevati mentre digiti, e il pulsante centrale inquadra lo scontrino.

Un controllo iOS non può mostrare una tastiera propria né fare domande: può solo
eseguire un'azione. Per farsi chiedere l'importo dal sistema senza aprire nulla,
la strada è una scorciatoia con «Chiedi input» seguita dall'azione **Spesa veloce**,
aggiunta alla schermata di blocco.

Le azioni compaiono anche tenendo premuta l'icona dell'app e in Comandi rapidi.

L'azione **Aggiungi spesa** accetta importo, esercente, categoria, conto, nota e data,
e salva senza aprire l'app. Per registrare automaticamente i pagamenti Apple Pay:

1. Comandi rapidi › Automazione › **Transazione**, scegli la carta.
2. Aggiungi l'azione **Aggiungi spesa** di Schei.
3. Collega *Importo* e *Esercente* della transazione ai campi dell'azione.
4. Disattiva *Chiedi prima di eseguire*.

## Struttura del progetto

```
Shared/            codice condiviso fra app e widget (valute, snapshot, colori)
Schei/
  App/             entry point, routing, sincronizzazione, backup, statistiche
  Models/          modelli SwiftData (spese, categorie, conti)
  Obsidian/        bookmark del vault, renderer Markdown/CSV, motore di scrittura
  Location/        CoreLocation, ricerca luoghi, tabella tipo-di-posto → categoria
  Receipt/         scanner di sistema, OCR Vision, parser degli scontrini
  Intents/         azioni per Comandi rapidi e Siri
  Features/        schermate SwiftUI
ScheiWidget/       estensione WidgetKit e controllo del Centro di Controllo
Tests/             verifiche di export, parser scontrini e mappatura luoghi
Tools/             script di bootstrap, packaging e pubblicazione
```

Architettura: SwiftUI + SwiftData, iOS 17 come minimo. Il widget non apre il
database: l'app gli lascia uno snapshot JSON nel container dell'App Group.

## Licenza

[MIT](LICENSE).
