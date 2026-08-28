import SwiftUI

/// Explains the automations Schei exposes — the same ones SyncSpend built around
/// Apple Pay, minus the account.
struct ShortcutsHelpView: View {
    var body: some View {
        List {
            Section {
                helpRow(
                    symbol: "bolt.fill",
                    title: "Aggiungi spesa",
                    detail: "L'azione principale: importo, esercente, categoria, conto, nota e data. Salva senza aprire l'app."
                )
                helpRow(
                    symbol: "plus.app.fill",
                    title: "Apri nuova spesa",
                    detail: "Apre Schei direttamente sulla schermata di inserimento, con i campi già compilati."
                )
                helpRow(
                    symbol: "arrow.triangle.2.circlepath",
                    title: "Sincronizza con Obsidian",
                    detail: "Forza la scrittura nel vault, utile a fine giornata."
                )
                helpRow(
                    symbol: "sum",
                    title: "Totale speso",
                    detail: "Restituisce quanto hai speso oggi, questa settimana, questo mese o quest'anno."
                )
            } header: {
                Text("Azioni disponibili in Comandi rapidi")
            }

            Section {
                helpRow(
                    symbol: "eurosign.circle.fill",
                    title: "Spesa veloce",
                    detail: "Registra con un tocco l'importo che scegli quando aggiungi il controllo. Tienilo premuto per cambiarlo, o aggiungine più d'uno: un caffè, un pranzo, un pieno."
                )
                helpRow(
                    symbol: "square.and.pencil",
                    title: "Nuova spesa",
                    detail: "Apre invece questa schermata, per quando servono categoria, nota o la scansione di uno scontrino."
                )
            } header: {
                Text("Centro di Controllo e schermata di blocco")
            } footer: {
                Text("Un controllo non può fare domande: tocchi e agisce. Per farti chiedere l'importo ogni volta, crea in Comandi rapidi una scorciatoia con «Chiedi input» seguita da «Spesa veloce», e aggiungi quella scorciatoia alla schermata di blocco.")
            }

            Section {
                step(1, "Apri l'app Comandi rapidi e crea un'automazione personale.")
                step(2, "Scegli l'attivazione «Transazione» e seleziona la carta che usi con Apple Pay.")
                step(3, "Aggiungi l'azione «Aggiungi spesa» di Schei.")
                step(4, "Collega Importo e Esercente della transazione ai campi dell'azione.")
                step(5, "Disattiva «Chiedi prima di eseguire» per registrare la spesa in automatico.")
            } header: {
                Text("Automazione Apple Pay")
            } footer: {
                Text("L'attivazione «Transazione» richiede una carta aggiunta a Wallet. iOS la esegue subito dopo il pagamento.")
            }

            Section {
                step(1, "Impostazioni › Accessibilità › Tocco › Tocco posteriore.")
                step(2, "Scegli Doppio tocco o Triplo tocco.")
                step(3, "Seleziona il comando rapido che usa «Apri nuova spesa».")
            } header: {
                Text("Tocco posteriore")
            } footer: {
                Text("Funziona anche con il tasto Azione e con i controlli del Centro di Controllo.")
            }
        }
        .navigationTitle("Automazioni")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func helpRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(ScheiTheme.ink)
                .frame(width: 24)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(ScheiTheme.card)
                .frame(width: 22, height: 22)
                .background(ScheiTheme.ink, in: Circle())
            Text(text)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}
