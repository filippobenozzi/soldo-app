import SwiftUI

/// What the user confirmed after a scan.
struct ReceiptReviewResult {
    var amount: Decimal?
    var merchant: String
    var date: Date?
}

/// Shows what OCR actually read before anything is written into the form.
///
/// Besides being safer than filling the fields silently, this is the screen that
/// makes a bad scan diagnosable: the recognised text is right there, and every
/// figure found on the receipt can be picked with one tap when the automatic
/// choice is wrong.
struct ReceiptReviewView: View {
    let scan: ReceiptScan
    let currencyCode: String
    var onUse: (ReceiptReviewResult) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String
    @State private var merchant: String
    @State private var date: Date
    @State private var useDate: Bool
    @State private var isShowingText = false

    init(scan: ReceiptScan, currencyCode: String, onUse: @escaping (ReceiptReviewResult) -> Void) {
        self.scan = scan
        self.currencyCode = currencyCode
        self.onUse = onUse
        _amountText = State(initialValue: scan.total.map {
            Money.machineString($0).replacingOccurrences(of: ".", with: ",")
        } ?? "")
        _merchant = State(initialValue: scan.merchant ?? "")
        _date = State(initialValue: scan.date ?? .now)
        _useDate = State(initialValue: scan.date != nil)
    }

    private var parsedAmount: Decimal? {
        guard let value = Money.parse(amountText), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("0,00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text(Money.symbol(for: currencyCode))
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Importo")
                } footer: {
                    if scan.total == nil {
                        Text("Non ho trovato una riga di totale. Scegli qui sotto una delle cifre lette, oppure scrivila a mano.")
                    }
                }

                if scan.candidateAmounts.count > 1 {
                    Section("Altre cifre sullo scontrino") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(scan.candidateAmounts, id: \.self) { candidate in
                                    let isSelected = candidate == parsedAmount
                                    Button {
                                        amountText = Money.machineString(candidate)
                                            .replacingOccurrences(of: ".", with: ",")
                                    } label: {
                                        Text(Money.string(candidate, currencyCode: currencyCode))
                                            .font(.system(.footnote, design: .rounded, weight: .medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .foregroundStyle(isSelected ? SoldoTheme.card : SoldoTheme.ink)
                                            .background(isSelected ? SoldoTheme.ink : SoldoTheme.badge, in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .scrollClipDisabled()
                    }
                }

                Section("Dettagli") {
                    HStack(spacing: 12) {
                        Image(systemName: "storefront").foregroundStyle(.secondary).frame(width: 22)
                        TextField("Esercente", text: $merchant)
                    }

                    Toggle("Usa la data dello scontrino", isOn: $useDate)
                        .soldoSwitch()
                    if useDate {
                        DatePicker("Data", selection: $date)
                    }

                    if let street = scan.street {
                        LabeledContent("Indirizzo", value: street).font(.caption)
                    }
                    if let locality = scan.locality {
                        LabeledContent("Città", value: locality).font(.caption)
                    }
                    if let vat = scan.vatNumber {
                        LabeledContent("P. IVA", value: vat).font(.caption)
                    }
                }

                Section {
                    DisclosureGroup("Testo riconosciuto (\(scan.lines.count) righe)", isExpanded: $isShowingText) {
                        if scan.lines.isEmpty {
                            Text("Nessun testo riconosciuto. Riprova con più luce, inquadrando lo scontrino da vicino e ben disteso.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(scan.lines.joined(separator: "\n"))
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                } footer: {
                    Text("Se qualcosa è stato letto male, correggilo qui: nulla viene salvato finché non tocchi Usa.")
                }
            }
            .navigationTitle("Dallo scontrino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Usa") {
                        onUse(
                            ReceiptReviewResult(
                                amount: parsedAmount,
                                merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
                                date: useDate ? date : nil
                            )
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
