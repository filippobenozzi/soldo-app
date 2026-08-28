import Foundation
import Observation

enum ObsidianError: LocalizedError {
    case noVaultSelected
    case bookmarkUnreadable
    case accessDenied(String)
    case writeFailed(String, underlying: String)

    var errorDescription: String? {
        switch self {
        case .noVaultSelected:
            "Nessun vault selezionato. Aprilo da Impostazioni › Obsidian."
        case .bookmarkUnreadable:
            "Non riesco più a raggiungere il vault. Riselezionalo da Impostazioni › Obsidian."
        case .accessDenied(let name):
            "iOS ha negato l'accesso a «\(name)». Riselezionalo da Impostazioni › Obsidian."
        case .writeFailed(let path, let underlying):
            "Scrittura fallita su «\(path)»: \(underlying)"
        }
    }
}

/// Holds the security-scoped bookmark of the Obsidian vault folder the user picked.
///
/// The vault is an ordinary folder — in iCloud Drive, in the Obsidian app's own
/// storage, or anywhere else the Files app can reach — so a folder bookmark is all
/// that is needed to read and write notes in it.
@Observable
final class ObsidianVaultLink {
    static let shared = ObsidianVaultLink()

    private let defaults: UserDefaults
    private enum Key {
        static let bookmark = "obsidian.vaultBookmark"
        static let displayName = "obsidian.vaultName"
        static let path = "obsidian.vaultPath"
    }

    private(set) var displayName: String?
    private(set) var lastKnownPath: String?

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        self.displayName = defaults.string(forKey: Key.displayName)
        self.lastKnownPath = defaults.string(forKey: Key.path)
    }

    var isConnected: Bool {
        defaults.data(forKey: Key.bookmark) != nil
    }

    // MARK: - Connecting

    /// Stores a bookmark for the folder the user picked in the document picker.
    func connect(to url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            // `.withSecurityScope` is macOS-only; on iOS a plain bookmark of a
            // picked URL already carries the sandbox extension.
            let bookmark = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(bookmark, forKey: Key.bookmark)
            defaults.set(url.lastPathComponent, forKey: Key.displayName)
            defaults.set(url.path(percentEncoded: false), forKey: Key.path)
            displayName = url.lastPathComponent
            lastKnownPath = url.path(percentEncoded: false)
        } catch {
            throw ObsidianError.accessDenied(url.lastPathComponent)
        }
    }

    func disconnect() {
        defaults.removeObject(forKey: Key.bookmark)
        defaults.removeObject(forKey: Key.displayName)
        defaults.removeObject(forKey: Key.path)
        displayName = nil
        lastKnownPath = nil
    }

    // MARK: - Using the vault

    /// Resolves the bookmark, opens security-scoped access and hands the folder URL
    /// to `body`. Access is always released, and a stale bookmark is refreshed.
    @discardableResult
    func withVault<T>(_ body: (URL) throws -> T) throws -> T {
        guard let bookmark = defaults.data(forKey: Key.bookmark) else {
            throw ObsidianError.noVaultSelected
        }

        var isStale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw ObsidianError.bookmarkUnreadable
        }

        guard url.startAccessingSecurityScopedResource() else {
            throw ObsidianError.accessDenied(url.lastPathComponent)
        }
        defer { url.stopAccessingSecurityScopedResource() }

        if isStale, let refreshed = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            defaults.set(refreshed, forKey: Key.bookmark)
        }

        return try body(url)
    }

    /// Cheap reachability probe used by Settings to show a green/red status dot.
    func verifyAccess() -> Result<Void, Error> {
        do {
            try withVault { url in
                _ = try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
            }
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Best-effort guess of the Obsidian vault name, used to build `obsidian://` links.
    var obsidianVaultName: String? {
        displayName
    }
}
