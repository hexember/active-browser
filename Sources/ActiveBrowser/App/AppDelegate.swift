import AppKit
import ServiceManagement

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

    /// Registers the app as a login item on launch, but only when it runs from `/Applications/`.
    ///
    /// The path gate exists because registering a `build/` copy would leave a login item pointing
    /// at a path `make clean` deletes — a dangling entry the user can only remove by hand in
    /// System Settings. `/Users/<me>/Applications/...` failing the prefix test is intended.
    ///
    /// The switch registers on `.notRegistered` **and** `.notFound`: measured on macOS 26, the
    /// status is `.notFound(3)` — not `.notRegistered(0)` — when no login item has ever been
    /// created for this bundle, so `Project.md` §5's `status == .notRegistered` never fires and
    /// makes this a no-op. That is a deliberate, measured deviation; do not "restore" §5.
    ///
    /// `.requiresApproval` and any unknown future case deliberately do nothing: switching the item
    /// off in System Settings -> General -> Login Items leaves `.requiresApproval`, so we never
    /// silently re-enable something the user turned off, and an unrecognised case fails closed.
    ///
    /// A failure here is not recoverable in code and must not block launch, so every branch just
    /// names its decision in the single log line below.
    private func registerLoginItemIfInstalled() {
        let message: String
        if !Bundle.main.bundleURL.path.hasPrefix("/Applications/") {
            message = "skipped, bundle is not under /Applications (\(Bundle.main.bundleURL.path))"
        } else {
            let status = SMAppService.mainApp.status
            let shouldRegister: Bool
            switch status {
            case .notRegistered:                // no Background Task Management record yet
                shouldRegister = true
            case .notFound:                     // macOS 26's first-launch value; also "nothing exists yet"
                shouldRegister = true
            case .enabled:                      // already correct; re-registering re-fires the banner
                shouldRegister = false
            case .requiresApproval:             // the user's opt-out from System Settings — respect it
                shouldRegister = false
            default:                            // unknown future case: fail closed
                shouldRegister = false
            }
            if !shouldRegister {
                message = "no action, status=\(label(status))"
            } else {
                do {
                    try SMAppService.mainApp.register()
                    message = "registered (prior status=\(label(status)))"
                } catch {
                    message = "register() failed (prior status=\(label(status))): "
                        + error.localizedDescription
                }
            }
        }
        NSLog("ActiveBrowser: login item: %@", message)
    }

    /// Names a status *and* its raw value, so the log says which case the SDK actually returned.
    private func label(_ status: SMAppService.Status) -> String {
        switch status {
        case .notRegistered: return "notRegistered(\(status.rawValue))"
        case .enabled: return "enabled(\(status.rawValue))"
        case .requiresApproval: return "requiresApproval(\(status.rawValue))"
        case .notFound: return "notFound(\(status.rawValue))"
        default: return "unknown(\(status.rawValue))"
        }
    }
}
