import Foundation

/// Access to the container shared between the app and the widget extension.
///
/// Every accessor is optional on purpose: when Soldo is sideloaded the App Group
/// entitlement is not always granted, and the app has to keep working without it
/// (only the widget loses its data in that case).
enum AppGroup {
    static let identifier = "group.im.filippo.soldo"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var userDefaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }

    /// Defaults that always resolve: the shared suite when available, the app's own otherwise.
    static var defaults: UserDefaults {
        userDefaults ?? .standard
    }

    static var isAvailable: Bool {
        containerURL != nil
    }
}
