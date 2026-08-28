import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppSettings.self) private var settings
    @Environment(SyncCoordinator.self) private var coordinator
    @Environment(ObsidianSettingsStore.self) private var obsidian
    @Environment(ObsidianVaultLink.self) private var vault
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var router = router
        @Bindable var settings = settings

        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem { Label("Oggi", systemImage: "house.fill") }
                .tag(AppRouter.Tab.home)

            HistoryView()
                .tabItem { Label("Storico", systemImage: "list.bullet") }
                .tag(AppRouter.Tab.history)

            InsightsView()
                .tabItem { Label("Analisi", systemImage: "chart.pie.fill") }
                .tag(AppRouter.Tab.insights)

            SettingsView()
                .tabItem { Label("Impostazioni", systemImage: "gearshape.fill") }
                .tag(AppRouter.Tab.settings)
        }
        .sheet(item: $router.presentation) { presentation in
            switch presentation.kind {
            case .addExpense:
                AddExpenseView(draft: presentation.draft)
            case .quickEntry:
                QuickEntrySheet(draft: presentation.draft)
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !settings.hasCompletedOnboarding },
            set: { if !$0 { settings.hasCompletedOnboarding = true } }
        )) {
            OnboardingView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .scheiOpenQuickAdd)) { _ in
            consumeQuickAddRequest()
        }
        .task { consumeQuickAddRequest() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            consumeQuickAddRequest()
            coordinator.refreshWidgetSnapshot(context: context)
            if obsidian.configuration.autoSync, vault.isConnected {
                Task { await coordinator.sync(context: context) }
            }
        }
    }

    /// Picks up a request left by the Control Centre control, a Lock Screen widget
    /// or a Shortcut — including one made while the app was not running.
    private func consumeQuickAddRequest() {
        guard let request = QuickAddInbox.take() else { return }
        var draft = ExpenseDraft()
        draft.amountText = request.amountText
        draft.merchant = request.merchant

        switch request.mode {
        case .quick: router.presentQuickEntry(draft: draft)
        case .full: router.presentAddExpense(draft: draft)
        }
    }
}
