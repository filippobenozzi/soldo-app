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
        .sheet(isPresented: $router.isPresentingAddExpense) {
            AddExpenseView(draft: router.addExpenseDraft)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !settings.hasCompletedOnboarding },
            set: { if !$0 { settings.hasCompletedOnboarding = true } }
        )) {
            OnboardingView()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            coordinator.refreshWidgetSnapshot(context: context)
            if obsidian.configuration.autoSync, vault.isConnected {
                Task { await coordinator.sync(context: context) }
            }
        }
    }
}
