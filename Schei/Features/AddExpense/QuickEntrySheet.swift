import SwiftData
import SwiftUI

/// The compact amount-first sheet the Control Centre button opens.
///
/// One number, one tap. The place — and with it the category — is worked out from
/// where you are while you type, and the receipt button fills the amount in for you
/// when you would rather point the camera at the till slip.
struct QuickEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Environment(SyncCoordinator.self) private var coordinator
    @Environment(LocationService.self) private var locationService

    @Query(sort: \SpendingCategory.sortIndex) private var allCategories: [SpendingCategory]
    @Query(sort: \PaymentAccount.sortIndex) private var allAccounts: [PaymentAccount]

    let draft: ExpenseDraft?

    @State private var amountText = ""
    @State private var place: DetectedPlace?
    @State private var category: SpendingCategory?
    @State private var isLocating = false
    @State private var didLoad = false

    @State private var isScanningReceipt = false
    @State private var pendingScan: PendingScan?
    @State private var receiptNote: String?

    private struct PendingScan: Identifiable {
        let id = UUID()
        let scan: ReceiptScan
    }

    private var categories: [SpendingCategory] { allCategories.filter { !$0.isArchived } }

    private var parsedAmount: Decimal? {
        guard let value = Money.parse(amountText), value > 0 else { return nil }
        return value
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Quanto hai speso?")
                .font(.headline)
                .padding(.top, 18)

            amountField
            contextLine

            Keypad(
                onDigit: appendDigit,
                onSeparator: appendSeparator,
                onDelete: deleteLast,
                onLongDelete: { amountText = "" }
            )

            buttons
        }
        .background(ScheiTheme.groupedBackground)
        .presentationDetents([.height(560)])
        .presentationDragIndicator(.visible)
        .onAppear(perform: load)
        .task { await detectPlace() }
        .fullScreenCover(isPresented: $isScanningReceipt) {
            DocumentScannerView(
                onFinish: { images in
                    isScanningReceipt = false
                    Task { await scan(images: images) }
                },
                onCancel: { isScanningReceipt = false }
            )
            .ignoresSafeArea()
        }
        .sheet(item: $pendingScan) { pending in
            ReceiptReviewView(scan: pending.scan, currencyCode: settings.currencyCode) { result in
                apply(result: result)
            }
        }
    }

    // MARK: - Pieces

    private var amountField: some View {
        HStack {
            Text(amountText.isEmpty ? "0" : amountText)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.snappy, value: amountText)
                .foregroundStyle(parsedAmount == nil ? Color.secondary : Color.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(Money.symbol(for: settings.currencyCode))
                .font(.title2)
                .foregroundStyle(.secondary)

            Spacer()

            if !amountText.isEmpty {
                Button {
                    amountText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ScheiTheme.card)
        )
        .padding(.horizontal)
    }

    @ViewBuilder
    private var contextLine: some View {
        HStack(spacing: 6) {
            if isLocating {
                ProgressView().controlSize(.mini)
                Text("Cerco dove sei…")
            } else if let place {
                Image(systemName: "mappin.circle.fill")
                Text(place.name).lineLimit(1)
                if let category {
                    Text("·")
                    Text(category.name)
                }
            } else if let receiptNote {
                Image(systemName: "doc.text.viewfinder")
                Text(receiptNote).lineLimit(1)
            } else if let category {
                Image(systemName: category.symbolName)
                Text(category.name)
            } else {
                Text(" ")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(height: 18)
        .padding(.horizontal)
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            Button("Annulla") { dismiss() }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.secondary)

            Button {
                isScanningReceipt = true
            } label: {
                Image(systemName: "doc.text.viewfinder")
                    .font(.title3)
                    .frame(height: 22)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(ScheiTheme.ink)
            .disabled(!DocumentScannerView.isAvailable)
            .accessibilityLabel("Scansiona scontrino")

            Button("Fatto", action: save)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(ScheiTheme.ink)
                .disabled(parsedAmount == nil)
        }
        .padding(.horizontal)
        .padding(.bottom, 18)
    }

    // MARK: - Amount entry

    private func appendDigit(_ digit: String) {
        Haptics.tap()
        if let separator = amountText.firstIndex(of: ",") {
            let decimals = amountText.distance(from: separator, to: amountText.endIndex) - 1
            guard decimals < 2 else { return }
        } else if amountText.count >= 9 {
            return
        }
        if amountText == "0" { amountText = "" }
        amountText.append(digit)
    }

    private func appendSeparator() {
        Haptics.tap()
        guard !amountText.contains(",") else { return }
        amountText = amountText.isEmpty ? "0," : amountText + ","
    }

    private func deleteLast() {
        Haptics.tap()
        guard !amountText.isEmpty else { return }
        amountText.removeLast()
    }

    // MARK: - Context

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        amountText = (draft?.amountText ?? "").replacingOccurrences(of: ".", with: ",")
        category = categories.first { $0.id == settings.defaultCategoryID } ?? categories.first
    }

    private func detectPlace() async {
        guard settings.detectLocation else { return }

        if locationService.authorizationStatus == .notDetermined {
            locationService.requestPermission()
            try? await Task.sleep(for: .seconds(1))
        }
        guard locationService.isAuthorized else { return }

        isLocating = true
        let nearest = await locationService.currentPlace()
        isLocating = false

        guard let nearest else { return }
        place = nearest
        if settings.autoCategoryFromPlace,
           let matched = PlaceCategoryMapper.match(nearest, in: categories) {
            category = matched
        }
    }

    // MARK: - Receipt

    private func scan(images: [UIImage]) async {
        guard let image = images.first else { return }
        receiptNote = "Sto leggendo lo scontrino…"
        do {
            let lines = try await ReceiptTextRecognizer.recognizeLines(in: image)
            receiptNote = nil
            pendingScan = PendingScan(scan: ReceiptParser.parse(lines: lines))
        } catch {
            receiptNote = error.localizedDescription
        }
    }

    private func apply(result: ReceiptReviewResult) {
        if let amount = result.amount, amount > 0 {
            amountText = Money.machineString(amount).replacingOccurrences(of: ".", with: ",")
        }
        if !result.merchant.isEmpty {
            receiptNote = result.merchant
        }
        Haptics.success()
    }

    // MARK: - Saving

    private func save() {
        guard let amount = parsedAmount else { return }

        let expense = Expense(
            amount: amount,
            currencyCode: settings.currencyCode,
            date: .now,
            merchant: place?.name ?? receiptNote ?? "",
            category: category,
            account: allAccounts.first { $0.id == settings.defaultAccountID }
        )
        expense.apply(place: place)
        context.insert(expense)
        try? context.save()

        coordinator.dataDidChange(context: context)
        Haptics.success()
        dismiss()
    }
}
