<div align="center">
  <img src="altstore/icon.png" width="120" alt="Soldo">
  <h1>Soldo</h1>
  <p><strong>Un modo veloce e minimale per segnare le spese, sincronizzate con il tuo vault Obsidian.</strong></p>
  <p>Nessun account · Nessun abbonamento · Nessuna pubblicità · Nessun tracciamento</p>
</div>

---

Soldo è un tracciatore di spese per iPhone e iPad, pensato per chi tiene le proprie
note e i propri dati in **Obsidian**. Registri una spesa in due secondi con un
tastierino dedicato, e Soldo la scrive nel tuo vault come normale file Markdown —
leggibile, versionabile, tuo.

L'app è ispirata a [SyncSpend](https://apps.apple.com/app/syncspend/id6759112033),
di cui riprende l'impostazione, con tre differenze sostanziali:

| SyncSpend | Soldo |
| --- | --- |
| Sincronizzazione con **Notion** (API, account, token) | Sincronizzazione con **Obsidian**: scegli la cartella del vault, si scrive su file |
| **Abbonamento Pro** (mensile, annuale, a vita) | Tutto gratis, nessun paywall nel codice |
| Sincronizzazione **iCloud** fra dispositivi | Il vault fa da archivio condiviso; in più c'è export/import JSON |

Soldo è un progetto indipendente, non affiliato con SyncSpend né con i suoi autori.

## Funzionalità

- **Registrazione rapida** — tastierino numerico dedicato, categorie e conti a portata di pollice, data con scorciatoie Oggi/Ieri.
- **Sincronizzazione Obsidian** in quattro formati, con anteprima dal vivo nelle impostazioni.
- **Widget** — totale del mese e budget (piccolo, medio), ultime spese (medio, grande), widget per schermata di blocco e controllo del Centro di Controllo per l'inserimento rapido (iOS 18+).
- **Comandi rapidi** — azioni `Aggiungi spesa`, `Apri nuova spesa`, `Totale speso`, `Sincronizza`, utilizzabili con Siri, Tocco posteriore, tasto Azione e automazioni Apple Pay.
- **Analisi** — grafici per giorno, per mese e per categoria, confronto col periodo precedente e proiezione di fine mese.
- **Budget mensile** opzionale, con anello di avanzamento su Home e nei widget.
- **Categorie e conti** personalizzabili: nome, icona SF Symbol, colore, ordinamento, archiviazione.
- **Backup JSON** esportabile e importabile, opzionalmente scritto anche nel vault.

## Come Soldo scrive nel vault

In **Impostazioni › Obsidian** scegli la cartella del vault (una qualsiasi cartella
raggiungibile dall'app File: iCloud Drive, `Su iPhone › Obsidian`, una chiavetta…)
e il formato di scrittura. L'accesso viene conservato con un *security-scoped
bookmark*, quindi va concesso una volta sola.

<details>
<summary><strong>Una nota per spesa</strong> — front matter YAML, pronta per Dataview (predefinito)</summary>

`Soldo/Spese/2026-08-28 Coop 12.50.md`

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
tags:
  - spesa
---

# Coop — 12,50 €

**Data:** 2026-08-28 14:32 · **Categoria:** Spesa · **Conto:** Carta

Pane e latte
```

Modificando la spesa in Soldo la nota viene aggiornata; se cambia il nome del file,
la vecchia nota viene rimossa. Eliminando la spesa, la nota viene cancellata.
</details>

<details>
<summary><strong>Nota unica</strong> — una tabella Markdown</summary>

`Soldo/Spese.md`

```markdown
| Data | Ora | Importo | Valuta | Categoria | Conto | Esercente | Nota |
| --- | --- | ---: | --- | --- | --- | --- | --- |
| 2026-08-28 | 14:32 | 12.50 | EUR | Spesa | Carta | Coop | Pane e latte |
```

Il file viene **rigenerato per intero** a ogni sincronizzazione, così modifiche ed
eliminazioni fatte in Soldo si riflettono sempre. Non modificarlo a mano.
</details>

<details>
<summary><strong>Nota giornaliera</strong> — una riga nel diario del giorno</summary>

`Diario/2026-08-28.md`

```markdown
## Spese

- **12,50 €** · Coop · Spesa · Carta — Pane e latte ^soldo-6f1a2b3c4d5e
```

Soldo crea la nota se non esiste e inserisce la riga in fondo alla sezione indicata,
**senza toccare il resto del file**. Il block reference finale (`^soldo-…`) le
permette di ritrovare la riga per aggiornarla o eliminarla, e ti permette di
linkarla da altre note.
</details>

<details>
<summary><strong>CSV</strong> — per fogli di calcolo e dataviewjs</summary>

`Soldo/Spese.csv`

```csv
id,data,ora,importo,valuta,categoria,conto,esercente,nota
"6f1a…","2026-08-28","14:32","12.50","EUR","Spesa","Carta","Coop","Pane e latte"
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

3. Apri la sorgente **Soldo** e installa l'app.

In alternativa scarica `Soldo.ipa` dall'ultima
[release](https://github.com/filippobenozzi/soldo-app/releases) e installala con
AltStore o Sideloadly.

### Cose da sapere sul sideloading

- Con un **Apple ID gratuito** le app firmate scadono dopo **7 giorni**: AltStore le
  rinnova da solo finché AltServer è raggiungibile.
- Sempre con un Apple ID gratuito puoi tenere **3 app** attive alla volta, e
  **ogni estensione conta come un'app**. Soldo con il widget ne occupa quindi due.
  Per questo ogni release contiene anche **`Soldo-no-widget.ipa`**: stessa app, senza
  estensione widget, un solo slot.
- Il widget legge i dati tramite l'**App Group** `group.im.filippo.soldo`. Se il
  metodo di sideloading che usi non riesce a registrarlo, l'app continua a
  funzionare normalmente e solo il widget resta vuoto.

## Compilare in locale

Serve un Mac con Xcode 16 o superiore.

```bash
git clone https://github.com/filippobenozzi/soldo-app.git
cd soldo-app
./Tools/bootstrap.sh   # installa XcodeGen se manca e genera Soldo.xcodeproj
open Soldo.xcodeproj
```

Il file `.xcodeproj` non è versionato: viene generato da
[XcodeGen](https://github.com/yonaskolb/XcodeGen) a partire da `project.yml`.

Per compilare l'IPA non firmata come fa la CI:

```bash
xcodebuild archive -project Soldo.xcodeproj -scheme Soldo -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -archivePath build/Soldo.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
./Tools/package-ipa.sh build/Soldo.xcarchive artifacts/Soldo.ipa
```

Le verifiche sulla logica di export Obsidian girano senza simulatore:

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

L'azione **Aggiungi spesa** accetta importo, esercente, categoria, conto, nota e data,
e salva senza aprire l'app. Per registrare automaticamente i pagamenti Apple Pay:

1. Comandi rapidi › Automazione › **Transazione**, scegli la carta.
2. Aggiungi l'azione **Aggiungi spesa** di Soldo.
3. Collega *Importo* e *Esercente* della transazione ai campi dell'azione.
4. Disattiva *Chiedi prima di eseguire*.

## Struttura del progetto

```
Shared/            codice condiviso fra app e widget (valute, snapshot, colori)
Soldo/
  App/             entry point, routing, sincronizzazione, backup, statistiche
  Models/          modelli SwiftData (spese, categorie, conti)
  Obsidian/        bookmark del vault, renderer Markdown/CSV, motore di scrittura
  Intents/         azioni per Comandi rapidi e Siri
  Features/        schermate SwiftUI
SoldoWidget/       estensione WidgetKit e controllo del Centro di Controllo
Tests/             verifiche della logica di export, eseguibili senza simulatore
Tools/             script di bootstrap, packaging e pubblicazione
```

Architettura: SwiftUI + SwiftData, iOS 17 come minimo. Il widget non apre il
database: l'app gli lascia uno snapshot JSON nel container dell'App Group.

## Licenza

[MIT](LICENSE).
