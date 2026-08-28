import PhotosUI
import SwiftData
import SwiftUI

/// The fast-logging screen: a big amount, a numeric keypad and one tap per field.
/// It can also fill itself in — from where you are, or from a scanned receipt.
struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Environment(SyncCoordinator.self) private var coordinator
    @Environment(LocationService.self) private var locationService

    @Query(sort: \SpendingCategory.sortIndex) private var allCategories: [SpendingCategory]
    @Query(sort: \PaymentAccount.sortIndex) private var allAccounts: [PaymentAccount]

    private let editingExpense: Expense?
    private let initialDraft: ExpenseDraft?

    @State private var amountText = ""
    @State private var merchant = ""
    @State private var note = ""
    @State private var date = Date.now
    @State private var selectedCategoryID: UUID?
    @State private var selectedAccountID: UUID?
    @State private var didLoadInitialState = false
    @State private var isConfirmingDelete = false
    @State private var isShowingDatePicker = false

    // Where the money was spent.
    @State private var place: DetectedPlace?
    @State private var nearbyPlaces: [DetectedPlace] = []
    @State private var isPickingPlace = false
    @State private var isLocating = false
    @State private var userChoseCategory = false

    // Receipt scanning.
    @State private var isScanningReceipt = false
    @State private var receiptPhoto: PhotosPickerItem?
    @State private var receiptPhase: ReceiptPhase = .idle

    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case merchant, note }

    private enum ReceiptPhase: Equatable {
        case idle
        case reading
        case filled(String)
        case failed(String)
    }

    init(draft: ExpenseDraft? = nil) {
        self.editingExpense = nil
        self.initialDraft = draft
    }

    init(editing expense: Expense) {
        self.editingExpense = expense
        self.initialDraft = nil
    }

    private var categories: [SpendingCategory] { allCategories.filter { !$0.isArchived } }
    private var accounts: [PaymentAccount] { allAccounts.filter { !$0.isArchived } }

    private var parsedAmount: Decimal? {
        guard let value = Money.parse(amountText), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 18) {
                        amountDisplay
                        receiptBanner
                        categoryPicker
                        detailsCard
                        placeCard
                        if editingExpense != nil { deleteButton }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                .scrollDismissesKeyboard(.interactively)

                if focusedField == nil {
                    Keypad(
                        onDigit: appendDigit,
                        onSeparator: appendSeparator,
                        onDelete: deleteLast,
                        onLongDelete: { amountText = "" }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                saveButton
            }
            .background(SoldoTheme.groupedBackground)
            .navigationTitle(editingExpense == nil ? "Nuova spesa" : "Modifica spesa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) { receiptMenu }
            }
            .animation(.snappy(duration: 0.22), value: focusedField)
            .animation(.snappy(duration: 0.22), value: receiptPhase)
        }
        .presentationDragIndicator(.visible)
        .onAppear(perform: loadInitialStateIfNeeded)
        .task { await autoDetectPlaceIfNeeded() }
        .fullScreenCover(isPresented: $isScanningReceipt) {
            DocumentScannerView(
                onFinish: { images in
                    isScanningReceipt = false
                    Task { await process(images: images) }
                },
                onCancel: { isScanningReceipt = false }
            )
            .ignoresSafeArea()
        }
        .onChange(of: receiptPhoto) { _, item in
            guard let item else { return }
            Task { await processPickedPhoto(item) }
        }
        .sheet(isPresented: $isPickingPlace) {
            PlacePickerView(
                places: nearbyPlaces,
                selected: place,
                isLoading: isLocating,
                onSelect: { chosen in
                    apply(place: chosen, overwriteMerchant: true)
                    isPickingPlace = false
                },
                onRefresh: { await refreshNearbyPlaces() }
            )
        }
        .confirmationDialog("Eliminare questa spesa?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Elimina", role: .destructive, action: deleteExpense)
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Verrà rimossa anche dal vault Obsidian alla prossima sincronizzazione.")
        }
    }

    // MARK: - Sections

    private var amountDisplay: some View {
        VStack(spacing: 6) {
            Text(displayAmount)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.snappy, value: amountText)
                .foregroundStyle(parsedAmount == nil ? Color.secondary : Color.primary)

            Button {
                isShowingDatePicker.toggle()
            } label: {
                Label(dateLabel, systemImage: "calendar")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            if isShowingDatePicker {
                DatePicker("Data e ora", selection: $date)
                    .datePickerStyle(.graphical)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .soldoCard()
    }

    private var receiptMenu: some View {
        Menu {
            if DocumentScannerView.isAvailable {
                Button {
                    isScanningReceipt = true
                } label: {
                    Label("Inquadra lo scontrino", systemImage: "doc.viewfinder")
                }
            }
            PhotosPicker(selection: $receiptPhoto, matching: .images) {
                Label("Scegli una foto", systemImage: "photo.on.rectangle")
            }
        } label: {
            Image(systemName: receiptPhase == .reading ? "hourglass" : "doc.text.viewfinder")
                .font(.title3)
        }
        .accessibilityLabel("Scansiona scontrino")
    }

    @ViewBuilder
    private var receiptBanner: some View {
        switch receiptPhase {
        case .idle:
            EmptyView()

        case .reading:
            HStack(spacing: 10) {
                ProgressView()
                Text("Sto leggendo lo scontrino…")
                    .font(.subheadline)
                Spacer()
            }
            .soldoCard(padding: 12)

        case .filled(let summary):
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(SoldoTheme.ink)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Compilato dallo scontrino")
                        .font(.subheadline.weight(.medium))
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Button("Chiudi") { receiptPhase = .idle }
                    .font(.caption.weight(.semibold))
            }
            .soldoCard(padding: 12)

        case .failed(let message):
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(SoldoTheme.danger)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Button("Chiudi") { receiptPhase = .idle }
                    .font(.caption.weight(.semibold))
            }
            .soldoCard(padding: 12)
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Categoria")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categories) { category in
                        chip(
                            title: category.name,
                            symbol: category.symbolName,
                            hex: category.colorHex,
                            isSelected: selectedCategoryID == category.id
                        ) {
                            Haptics.tap()
                            userChoseCategory = true
                            selectedCategoryID = selectedCategoryID == category.id ? nil : category.id
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "storefront")
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                TextField("Esercente", text: $merchant)
                    .focused($focusedField, equals: .merchant)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .note }
            }
            .padding(.vertical, 12)

            Divider()

            HStack(spacing: 12) {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                TextField("Nota", text: $note, axis: .vertical)
                    .lineLimit(1...3)
                    .focused($focusedField, equals: .note)
            }
            .padding(.vertical, 12)

            if !accounts.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Pagato con")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(accounts) { account in
                                chip(
                                    title: account.name,
                                    symbol: account.symbolName,
                                    hex: account.colorHex,
                                    isSelected: selectedAccountID == account.id
                                ) {
                                    Haptics.tap()
                                    selectedAccountID = selectedAccountID == account.id ? nil : account.id
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollClipDisabled()
                }
                .padding(.vertical, 12)
            }
        }
        .soldoCard()
    }

    @ViewBuilder
    private var placeCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: place == nil ? "mappin.slash" : "mappin.circle.fill")
                    .foregroundStyle(place == nil ? .secondary : SoldoTheme.ink)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    if let place {
                        Text(place.name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        if !place.subtitle.isEmpty {
                            Text(place.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } else if isLocating {
                        Text("Cerco dove sei…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Nessun luogo")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(locationHint)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 4)

                if isLocating {
                    ProgressView()
                } else if locationService.isAuthorized {
                    Button {
                        Haptics.tap()
                        isPickingPlace = true
                        Task { await refreshNearbyPlaces() }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                } else if locationService.authorizationStatus == .notDetermined {
                    Button("Consenti") {
                        locationService.requestPermission()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 12)

            if place != nil {
                Divider()
                Button(role: .destructive) {
                    place = nil
                } label: {
                    Label("Rimuovi il luogo", systemImage: "xmark.circle")
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 10)
            }
        }
        .soldoCard()
    }

    private var locationHint: String {
        if locationService.isDenied {
            return "Accesso negato. Attivalo in Impostazioni iOS › Soldo › Posizione."
        }
        if !settings.detectLocation {
            return "Rilevamento disattivato in Impostazioni › Posizione."
        }
        return "Tocca Consenti per riconoscere il negozio dove sei."
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            isConfirmingDelete = true
        } label: {
            Label("Elimina spesa", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(SoldoTheme.danger)
    }

    private var saveButton: some View {
        Button(action: save) {
            Text(editingExpense == nil ? "Salva spesa" : "Salva modifiche")
        }
        .buttonStyle(InkButtonStyle())
        .opacity(parsedAmount == nil ? 0.4 : 1)
        .disabled(parsedAmount == nil)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(.bar)
    }

    private func chip(title: String, symbol: String, hex: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let tint = SoldoTheme.tint(hex)
        return Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.caption)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? SoldoTheme.card : tint)
            .background(isSelected ? SoldoTheme.ink : SoldoTheme.badge, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Amount entry

    private var displayAmount: String {
        let symbol = Money.symbol(for: settings.currencyCode)
        let text = amountText.isEmpty ? "0" : amountText
        return "\(text) \(symbol)"
    }

    private var dateLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Oggi, \(date.formatted(date: .omitted, time: .shortened))"
        }
        if calendar.isDateInYesterday(date) {
            return "Ieri, \(date.formatted(date: .omitted, time: .shortened))"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func appendDigit(_ digit: String) {
        Haptics.tap()
        if let separatorIndex = amountText.firstIndex(where: { $0 == "," }) {
            let decimals = amountText.distance(from: separatorIndex, to: amountText.endIndex) - 1
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

    // MARK: - Location

    private func autoDetectPlaceIfNeeded() async {
        guard editingExpense == nil, settings.detectLocation, place == nil else { return }

        if locationService.authorizationStatus == .notDetermined {
            locationService.requestPermission()
            // Give the permission sheet a moment before the first lookup.
            try? await Task.sleep(for: .seconds(1))
        }
        guard locationService.isAuthorized else { return }

        isLocating = true
        let places = await locationService.nearbyPlaces(limit: 12)
        nearbyPlaces = places
        isLocating = false

        if place == nil, let closest = places.first {
            apply(place: closest, overwriteMerchant: false)
        }
    }

    private func refreshNearbyPlaces() async {
        isLocating = true
        nearbyPlaces = await locationService.nearbyPlaces(limit: 15)
        isLocating = false
    }

    /// Applies a place, without stepping on anything the user typed or picked.
    private func apply(place newPlace: DetectedPlace, overwriteMerchant: Bool) {
        place = newPlace

        if overwriteMerchant || merchant.trimmingCharacters(in: .whitespaces).isEmpty {
            merchant = newPlace.name
        }

        guard settings.autoCategoryFromPlace, !userChoseCategory,
              let match = PlaceCategoryMapper.match(newPlace, in: categories)
        else { return }
        selectedCategoryID = match.id
    }

    // MARK: - Receipt

    private func processPickedPhoto(_ item: PhotosPickerItem) async {
        receiptPhase = .reading
        defer { receiptPhoto = nil }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            receiptPhase = .failed("Non riesco a leggere quell'immagine.")
            return
        }
        await process(images: [image])
    }

    private func process(images: [UIImage]) async {
        guard let image = images.first else { return }
        receiptPhase = .reading

        do {
            let lines = try await ReceiptTextRecognizer.recognizeLines(in: image)
            let scan = ReceiptParser.parse(lines: lines)
            guard !scan.isEmpty else {
                receiptPhase = .failed("Non ho riconosciuto importo né negozio. Riprova con più luce.")
                return
            }
            await apply(scan: scan)
        } catch {
            receiptPhase = .failed(error.localizedDescription)
        }
    }

    private func apply(scan: ReceiptScan) async {
        var filled: [String] = []

        if let total = scan.total, total > 0 {
            amountText = Money.machineString(total).replacingOccurrences(of: ".", with: ",")
            filled.append("importo")
        }
        if let scanned = scan.merchant, !scanned.isEmpty {
            merchant = scanned
            filled.append("negozio")
        }
        if let scannedDate = scan.date {
            date = scannedDate
            filled.append("data")
        }

        receiptPhase = .filled(filled.isEmpty ? "Nessun campo riconosciuto" : filled.joined(separator: ", "))
        Haptics.success()

        // Turn the printed name and street into a real place, so the expense gets
        // coordinates and a category just like a GPS-detected one.
        guard let query = scan.placeQuery else { return }
        if let resolved = await locationService.place(matching: query, near: locationService.lastLocation) {
            apply(place: resolved, overwriteMerchant: false)
            receiptPhase = .filled((filled + ["luogo"]).joined(separator: ", "))
        }
    }

    // MARK: - Loading and saving

    private func loadInitialStateIfNeeded() {
        guard !didLoadInitialState else { return }
        didLoadInitialState = true

        if let expense = editingExpense {
            amountText = Money.machineString(expense.amount).replacingOccurrences(of: ".", with: ",")
            merchant = expense.merchant
            note = expense.note
            date = expense.date
            selectedCategoryID = expense.category?.id
            selectedAccountID = expense.account?.id
            userChoseCategory = true
            if let latitude = expense.latitude, let longitude = expense.longitude {
                place = DetectedPlace(
                    name: expense.placeName ?? expense.merchant,
                    categoryIdentifier: expense.placeCategoryIdentifier,
                    latitude: latitude,
                    longitude: longitude
                )
            }
            return
        }

        if let draft = initialDraft {
            amountText = draft.amountText.replacingOccurrences(of: ".", with: ",")
            merchant = draft.merchant
            note = draft.note
            date = draft.date
            selectedCategoryID = draft.categoryID
            selectedAccountID = draft.accountID
        }

        selectedCategoryID = selectedCategoryID ?? settings.defaultCategoryID ?? categories.first?.id
        selectedAccountID = selectedAccountID ?? settings.defaultAccountID
    }

    private func save() {
        guard let amount = parsedAmount else { return }

        let category = categories.first { $0.id == selectedCategoryID }
        let account = accounts.first { $0.id == selectedAccountID }
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if let expense = editingExpense {
            expense.amount = amount
            expense.merchant = trimmedMerchant
            expense.note = trimmedNote
            expense.date = date
            expense.category = category
            expense.account = account
            expense.currencyCode = settings.currencyCode
            expense.apply(place: place)
            expense.touch()
        } else {
            let expense = Expense(
                amount: amount,
                currencyCode: settings.currencyCode,
                date: date,
                merchant: trimmedMerchant,
                note: trimmedNote,
                category: category,
                account: account
            )
            expense.apply(place: place)
            context.insert(expense)
        }

        try? context.save()
        coordinator.dataDidChange(context: context)
        Haptics.success()
        dismiss()
    }

    private func deleteExpense() {
        guard let expense = editingExpense else { return }
        context.deleteExpense(expense)
        coordinator.dataDidChange(context: context)
        Haptics.warning()
        dismiss()
    }
}

/// Lets the user correct the automatic guess by picking another nearby place.
private struct PlacePickerView: View {
    let places: [DetectedPlace]
    let selected: DetectedPlace?
    let isLoading: Bool
    let onSelect: (DetectedPlace) -> Void
    let onRefresh: () async -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if places.isEmpty, !isLoading {
                    EmptyStateView(
                        symbol: "mappin.slash",
                        title: "Nessun luogo qui intorno",
                        message: "Apple Maps non conosce posti in questa zona, oppure il segnale GPS è debole."
                    )
                    .listRowBackground(Color.clear)
                }

                ForEach(places) { candidate in
                    Button {
                        onSelect(candidate)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.name)
                                    .foregroundStyle(.primary)
                                if !candidate.subtitle.isEmpty {
                                    Text(candidate.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if candidate.id == selected?.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(SoldoTheme.ink)
                            }
                        }
                    }
                }
            }
            .overlay {
                if isLoading, places.isEmpty {
                    ProgressView("Cerco qui intorno…")
                }
            }
            .navigationTitle("Dove sei")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await onRefresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Numeric keypad tuned for one-handed use.
private struct Keypad: View {
    let onDigit: (String) -> Void
    let onSeparator: () -> Void
    let onDelete: () -> Void
    let onLongDelete: () -> Void

    private let rows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [",", "0", "\u{232B}"],
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { value in
                        keyButton(value)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func keyButton(_ value: String) -> some View {
        Button {
            switch value {
            case ",": onSeparator()
            case "\u{232B}": onDelete()
            default: onDigit(value)
            }
        } label: {
            Group {
                if value == "\u{232B}" {
                    Image(systemName: "delete.left")
                        .font(.title2)
                } else {
                    Text(value)
                        .font(.system(size: 26, weight: .medium, design: .rounded))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(SoldoTheme.card)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                if value == "\u{232B}" { onLongDelete() }
            }
        )
    }
}
