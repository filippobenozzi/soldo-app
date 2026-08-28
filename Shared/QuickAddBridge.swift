import Foundation

extension Notification.Name {
    /// Posted inside the app when something asks for an expense screen.
    static let scheiOpenQuickAdd = Notification.Name("im.filippo.soldo.openQuickAdd")
}

/// Which screen the request wants.
enum QuickAddMode: String {
    /// The compact amount-first sheet.
    case quick
    /// The full insert screen, with category, note and everything else.
    case full
}

/// A hand-off for "open an expense screen", left behind by the Control Centre
/// control, a Lock Screen widget or a Shortcut.
///
/// The notification covers the case where the app is already running; the stored
/// request covers a cold launch, where nothing is listening yet when the intent runs.
enum QuickAddInbox {
    private static let key = "quickAdd.pendingRequest"
    private static let maximumAge: TimeInterval = 90

    static func post(mode: QuickAddMode = .quick, amountText: String = "", merchant: String = "") {
        let payload: [String: String] = [
            "mode": mode.rawValue,
            "amount": amountText,
            "merchant": merchant,
            "at": String(Date.now.timeIntervalSince1970),
        ]
        UserDefaults.standard.set(payload, forKey: key)
        AppGroup.userDefaults?.set(payload, forKey: key)
        NotificationCenter.default.post(name: .scheiOpenQuickAdd, object: nil)
    }

    struct Request {
        var mode: QuickAddMode
        var amountText: String
        var merchant: String
    }

    /// Returns and clears a request that is recent enough to still make sense.
    static func take() -> Request? {
        let stores = [UserDefaults.standard, AppGroup.userDefaults].compactMap { $0 }

        var result: Request?
        for store in stores {
            guard result == nil,
                  let payload = store.dictionary(forKey: key) as? [String: String],
                  let timestamp = payload["at"].flatMap(Double.init),
                  Date.now.timeIntervalSince1970 - timestamp < maximumAge
            else { continue }
            result = Request(
                mode: QuickAddMode(rawValue: payload["mode"] ?? "") ?? .quick,
                amountText: payload["amount"] ?? "",
                merchant: payload["merchant"] ?? ""
            )
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
