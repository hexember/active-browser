import AppKit

/// Process entry point and owner of every piece of app state.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
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
    }

    /// Called by Launch Services when ActiveBrowser is the default handler for the scheme.
    func application(_ application: NSApplication, open urls: [URL]) {
        bootstrapIfNeeded()
        dispatcher.open(urls)
    }

    /// Suppresses the macOS 14+ console warning about restorable state. We have no windows.
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    /// One-time startup work, safe to call from either entry point in either order.s
    private func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true

        registry.refresh()

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
