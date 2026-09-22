import Foundation

/// `UserDefaults`-backed user preferences. Storage and retrieval only:
/// first-launch seeding is owned by `AppDelegate`.
@MainActor
final class Settings {
    private enum Keys {
        static let includedBrowsers = "includedBrowsers"
        static let defaultBrowser = "defaultBrowser"
    }

    private let defaults = UserDefaults.standard

    /// Bundle identifiers of the browsers that participate in routing.
    var includedBrowsers: Set<String> {
        get { Set(defaults.stringArray(forKey: Keys.includedBrowsers) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: Keys.includedBrowsers) }
    }

    /// Bundle identifier of the fallback browser used when the stack resolves to nothing.
    var defaultBrowser: String? {
        get { defaults.string(forKey: Keys.defaultBrowser) }
        set { defaults.set(newValue, forKey: Keys.defaultBrowser) }
    }
}
