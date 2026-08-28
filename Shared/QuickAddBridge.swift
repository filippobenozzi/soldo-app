import Foundation

extension Notification.Name {
    /// Posted inside the app when something asks for the add-expense screen.
    static let soldoOpenQuickAdd = Notification.Name("im.filippo.soldo.openQuickAdd")
}

/// A hand-off for "open the add-expense screen", left behind by the Control Center
/// control, the Lock Screen widget or a Shortcut.
///
/// The notification covers the case where the app is already running; the stored
/// request covers a cold launch, where nothing is listening yet when the intent runs.
enum QuickAddInbox {
    private static let key = "quickAdd.pendingRequest"
    private static let maximumAge: TimeInterval = 90

    static func post(amountText: String = "", merchant: String = "") {
        let payload: [String: String] = [
            "amount": amountText,
            "merchant": merchant,
            "at": String(Date.now.timeIntervalSince1970),
        ]
        UserDefaults.standard.set(payload, forKey: key)
        AppGroup.userDefaults?.set(payload, forKey: key)
        NotificationCenter.default.post(name: .soldoOpenQuickAdd, object: nil)
    }

    /// Returns and clears a request that is recent enough to still make sense.
    static func take() -> (amountText: String, merchant: String)? {
        let stores = [UserDefaults.standard, AppGroup.userDefaults].compactMap { $0 }

        var result: (String, String)?
        for store in stores {
            guard result == nil,
                  let payload = store.dictionary(forKey: key) as? [String: String],
                  let timestamp = payload["at"].flatMap(Double.init),
                  Date.now.timeIntervalSince1970 - timestamp < maximumAge
            else { continue }
            result = (payload["amount"] ?? "", payload["merchant"] ?? "")
        }

        guard let result else { return nil }
        for store in stores { store.removeObject(forKey: key) }
        return result
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        AppGroup.userDefaults?.removeObject(forKey: key)
    }
}
