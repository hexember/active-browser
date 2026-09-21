import Foundation

/// `UserDefaults`-backed user preferences. Storage and retrieval only:
/// first-launch seeding is owned by `AppDelegate`.
@MainActor
final class Settings {
    private enum Keys {
        static let includedBrowsers = "includedBrowsers"
        static let defaultBrowser = "defaultBrowser"
        static let launchAtLoginOptOut = "launchAtLoginOptOut"
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

    /// `true` once the user has switched *Launch at Login* off from the menu bar.
    ///
    /// Written **only** by `MenuBarManager.toggleLaunchAtLogin()` and read **only** by
    /// `AppDelegate.registerLoginItemIfInstalled()`. Nothing seeds it.
    ///
    /// It exists because unregistering the login item leaves its status at
    /// `.notRegistered`/`.notFound`, and the launch gate registers on both — so without a
    /// recorded opt-out a toggle-off would be silently undone at the next launch.
    ///
    /// A missing key means "no opt-out recorded": `UserDefaults.bool(forKey:)` returns `false`
    /// for an absent key, so every existing install keeps the behaviour it had before this key
    /// existed. That is why this is a plain `Bool` and not an `Optional<Bool>` — there is no
    /// third state to represent.
    ///
    /// It never governs the menu's checkmark; that is derived from the live login-item status,
    /// which is the only thing that knows whether macOS will actually launch us.
    var launchAtLoginOptOut: Bool {
        get { defaults.bool(forKey: Keys.launchAtLoginOptOut) }
        set { defaults.set(newValue, forKey: Keys.launchAtLoginOptOut) }
    }
}
