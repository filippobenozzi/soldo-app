import Foundation
import Observation
import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "Sistema"
        case .light: "Chiaro"
        case .dark: "Scuro"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// App-wide preferences, persisted in the shared defaults suite so the widget can
/// read the currency and the monthly budget without opening the database.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults: UserDefaults

    private enum Key {
        static let currencyCode = "settings.currencyCode"
        static let monthlyBudget = "settings.monthlyBudget"
        static let appearance = "settings.appearance"
        static let hasCompletedOnboarding = "settings.hasCompletedOnboarding"
        static let defaultCategoryID = "settings.defaultCategoryID"
        static let defaultAccountID = "settings.defaultAccountID"
        static let hapticsEnabled = "settings.hapticsEnabled"
        static let quickAddClosesAfterSave = "settings.quickAddClosesAfterSave"
    }

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        self.currencyCode = defaults.string(forKey: Key.currencyCode) ?? Money.defaultCurrencyCode
        self.monthlyBudget = (defaults.string(forKey: Key.monthlyBudget)).flatMap { Decimal(string: $0) }
        self.appearance = AppearanceMode(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system
        self.hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
        self.defaultCategoryID = (defaults.string(forKey: Key.defaultCategoryID)).flatMap(UUID.init(uuidString:))
        self.defaultAccountID = (defaults.string(forKey: Key.defaultAccountID)).flatMap(UUID.init(uuidString:))
        self.hapticsEnabled = defaults.object(forKey: Key.hapticsEnabled) as? Bool ?? true
        self.quickAddClosesAfterSave = defaults.object(forKey: Key.quickAddClosesAfterSave) as? Bool ?? true
    }

    var currencyCode: String {
        didSet { defaults.set(currencyCode, forKey: Key.currencyCode) }
    }

    /// `nil` means "no budget set".
    var monthlyBudget: Decimal? {
        didSet {
            if let monthlyBudget, monthlyBudget > 0 {
                defaults.set("\(monthlyBudget)", forKey: Key.monthlyBudget)
            } else {
                defaults.removeObject(forKey: Key.monthlyBudget)
            }
        }
    }

    var appearance: AppearanceMode {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    var defaultCategoryID: UUID? {
        didSet { defaults.set(defaultCategoryID?.uuidString, forKey: Key.defaultCategoryID) }
    }

    var defaultAccountID: UUID? {
        didSet { defaults.set(defaultAccountID?.uuidString, forKey: Key.defaultAccountID) }
    }

    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Key.hapticsEnabled) }
    }

    var quickAddClosesAfterSave: Bool {
        didSet { defaults.set(quickAddClosesAfterSave, forKey: Key.quickAddClosesAfterSave) }
    }
}
