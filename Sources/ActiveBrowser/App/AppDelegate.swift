import AppKit

/// Process entry point and owner of every piece of app state.
///
/// Agent behaviour (no Dock icon, no windows) comes from `LSUIElement` in the bundle's
/// `Info.plist`, never from a programmatic activation-policy change — a programmatic
/// change would mask a broken plist.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Explicit entry point. AppKit's `NSApplicationDelegate.main()` protocol-extension default
    /// only calls `NSApplicationMain`, which neither instantiates this type nor assigns
    /// `NSApp.delegate` — with no nib to wire it up the delegate would never exist and every
    /// URL would be dropped. So the delegate is created and installed here instead.
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate            // NSApplication.delegate is a weak reference
        withExtendedLifetime(delegate) { app.run() }
    }

    private let registry: BrowserRegistry
    private let settings: Settings
    private let stack: BrowserStack
    private let focusObserver: FocusObserver
    private let dispatcher: URLDispatcher

    private var didBootstrap = false

    // All five are built here so `focusObserver` and `dispatcher` can share the exact same
    // state objects; a stored-property default cannot reference a sibling property.
    override init() {
        let registry = BrowserRegistry()
        let settings = Settings()
        let stack = BrowserStack()
        self.registry = registry
        self.settings = settings
        self.stack = stack
        self.focusObserver = FocusObserver(settings: settings, stack: stack)
        self.dispatcher = URLDispatcher(registry: registry, settings: settings, stack: stack)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        bootstrapIfNeeded()
        // Later phases append here, in this order: menu bar status item, then the
        // `/Applications`-gated login-item registration. Neither edits the line above.
    }

    /// Called by Launch Services when ActiveBrowser is the default handler for the scheme.
    ///
    /// On a cold start caused by clicking a link, AppKit can deliver the open-URLs Apple Event
    /// *before* `applicationDidFinishLaunching`. Bootstrapping here is therefore required,
    /// not defensive padding: an unseeded registry/settings would drop that very first URL.
    func application(_ application: NSApplication, open urls: [URL]) {
        bootstrapIfNeeded()
        dispatcher.open(urls)
    }

    /// Suppresses the macOS 14+ console warning about restorable state. We have no windows.
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    /// One-time startup work, safe to call from either entry point in either order.
    ///
    /// The flag is set *before* the work, so a re-entrant call can neither re-seed settings
    /// nor register the focus observer twice.
    private func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true

        registry.refresh()

        // First launch: include every detected browser, fallback = first one. Both values come
        // from the registry, which already excludes this app, so neither can ever name us.
        // A `defaultBrowser` that is currently not installed is deliberately left alone —
        // repairing it here would clobber a user choice because a volume happens to be
        // unmounted; the dispatcher's candidate walk handles that case instead.
        if settings.includedBrowsers.isEmpty {
            settings.includedBrowsers = Set(registry.installed.map(\.bundleId))
        }
        if settings.defaultBrowser == nil {
            settings.defaultBrowser = registry.installed.first?.bundleId
        }

        stack.prune(keeping: settings.includedBrowsers)
        focusObserver.start()
    }
}
