import SwiftData
import SwiftUI

@main
struct ScheiApp: App {
    @State private var settings = AppSettings.shared
    @State private var vault = ObsidianVaultLink.shared
    @State private var obsidianSettings = ObsidianSettingsStore.shared
    @State private var coordinator = SyncCoordinator.shared
    @State private var router = AppRouter.shared
    @State private var locationService = LocationService.shared

    private let container = ScheiModelContainer.shared

    init() {
        // Quick-add can run in this process when iOS launches the app in the
        // background for the intent. When it does, finish the job properly:
        // write the vault and refresh the widget.
        QuickAddHooks.didSaveExpense = { _ in
            let context = ScheiModelContainer.shared.mainContext
            await SyncCoordinator.shared.sync(context: context)
            SyncCoordinator.shared.refreshWidgetSnapshot(context: context)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(vault)
                .environment(obsidianSettings)
                .environment(coordinator)
                .environment(router)
                .environment(locationService)
                .preferredColorScheme(settings.appearance.colorScheme)
                .tint(ScheiTheme.ink)
                .task {
                    let context = container.mainContext
                    ScheiModelContainer.seedIfNeeded(context)
                    coordinator.refreshWidgetSnapshot(context: context)
                    if obsidianSettings.configuration.autoSync, vault.isConnected {
                        await coordinator.sync(context: context)
                    }
                }
                .onOpenURL { url in
                    router.handle(url: url, context: container.mainContext)
                }
        }
        .modelContainer(container)
    }
}

/// Cross-screen navigation state, also driven by `soldo://` links coming from the
/// widget, the Control Center control and Shortcuts.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    enum Tab: Hashable { case home, history, insights, settings }

    /// Which screen is on top. A single binding, because two `.sheet` modifiers on
    /// the same view do not both work.
    struct Presentation: Identifiable {
        enum Kind { case addExpense, quickEntry }

        let id = UUID()
        var kind: Kind
        /// Prefilled values handed over by a widget tap or a Shortcuts action.
        var draft: ExpenseDraft?
    }

    var selectedTab: Tab = .home
    var presentation: Presentation?

    func presentAddExpense(draft: ExpenseDraft? = nil) {
        presentation = Presentation(kind: .addExpense, draft: draft)
    }

    /// The compact keypad sheet, opened by the Control Centre button.
    func presentQuickEntry(draft: ExpenseDraft? = nil) {
        presentation = Presentation(kind: .quickEntry, draft: draft)
    }

    func handle(url: URL, context: ModelContext) {
        // `soldo` stays accepted: widgets placed before the rename still use it.
        guard ["schei", "soldo"].contains(url.scheme?.lowercased() ?? "") else { return }

        switch url.host()?.lowercased() {
        case "quick":
            presentQuickEntry()
        case "add", "new", "quickadd":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            var draft = ExpenseDraft()
            if let amount = components?.queryItems?.first(where: { $0.name == "amount" })?.value {
                draft.amountText = amount
            }
            if let merchant = components?.queryItems?.first(where: { $0.name == "merchant" })?.value {
                draft.merchant = merchant
            }
            presentAddExpense(draft: draft)
        case "sync":
            Task { await SyncCoordinator.shared.sync(context: context) }
        case "insights", "stats":
            selectedTab = .insights
        case "history":
            selectedTab = .history
        case "settings":
            selectedTab = .settings
        default:
            selectedTab = .home
        }
    }
}

/// Values used to prefill the add-expense sheet.
struct ExpenseDraft: Equatable {
    var amountText: String = ""
    var merchant: String = ""
    var note: String = ""
    var date: Date = .now
    var categoryID: UUID?
    var accountID: UUID?
}
