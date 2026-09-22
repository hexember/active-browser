import AppKit
import ServiceManagement

/// The menu bar surface: a status item whose menu states the live routing target and the
/// LRU order, and carries the app's three actions.
///
/// **The owner must retain this object for the process lifetime.** `NSMenuItem.target` and
/// `NSMenu.delegate` are both weak references, so if this manager were created as a local and
/// dropped, the status item would still appear and the menu would still drop down (the status
/// bar retains the item, the item retains the menu) while `menuWillOpen` never fired and every
/// click silently did nothing. `AppDelegate` therefore holds it in a stored property.
///
/// **Flag vs. status.** The *Launch at Login* checkmark is derived from
/// `SMAppService.mainApp.status` and never from `Settings.launchAtLoginOptOut`. If
/// `unregister()` throws, the opt-out flag is already persisted but macOS still launches us;
/// a checkmark driven by the flag would claim "off" while the login item exists. The status is
/// the truth about macOS; the flag only governs *our* auto-registration at launch.
///
/// **No polling.** The menu's contents are computed at exactly two event-driven moments:
/// `menuWillOpen(_:)` (a user action) and `refresh()` (called from the focus notification).
@MainActor
final class MenuBarManager: NSObject, NSMenuDelegate {
    /// Retained for the lifetime of the app: releasing the status item removes it from the
    /// menu bar. `NSStatusBar.system.removeStatusItem(_:)` is never called.
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()

    private let registry: BrowserRegistry
    private let settings: Settings
    private let stack: BrowserStack
    private let dispatcher: URLDispatcher

    /// How many browsers the *Recent:* line names before it elides the remainder.
    private static let recentDisplayLimit = 3

    init(registry: BrowserRegistry, settings: Settings, stack: BrowserStack, dispatcher: URLDispatcher) {
        self.registry = registry
        self.settings = settings
        self.stack = stack
        self.dispatcher = dispatcher
        super.init()

        if let button = item.button {
            // A template image inverts correctly in dark mode and while the menu is highlighted.
            // A fixed-width icon also keeps the rest of the menu bar from shifting on every
            // focus change; the live target name lives in the tooltip and on the first menu line.
            if let image = NSImage(systemSymbolName: "globe", accessibilityDescription: "ActiveBrowser") {
                image.isTemplate = true
                button.image = image
            } else {
                // A status button with neither image nor title is zero-width and unclickable,
                // i.e. an app the user cannot quit. Never leave both empty.
                button.title = "AB"
            }
        }

        menu.delegate = self
        // With auto-enabling on, AppKit recomputes `isEnabled` from the responder chain and
        // overrides the disabled info items below.
        menu.autoenablesItems = false
        item.menu = menu

        rebuild()
        refresh()
    }

    // MARK: - NSMenuDelegate

    /// Re-scans Launch Services on every menu open, so a newly installed browser appears.
    /// AppKit calls this once per open, on the main thread; no re-entrancy guard is needed.
    func menuWillOpen(_ menu: NSMenu) {
        registry.refresh()
        rebuild()
    }

    // MARK: - Refresh

    /// Updates the status item's tooltip and accessibility label to the current routing target.
    ///
    /// Called from `FocusObserver.onFocusChange`, so it deliberately does **not** call
    /// `registry.refresh()` — the Launch Services scan is reserved for menu opens — and it does
    /// not rebuild the menu: an open status menu takes key focus, so no browser can activate
    /// underneath it.
    func refresh() {
        let text = "Routing to: \(currentTargetName())"
        item.button?.toolTip = text
        item.button?.setAccessibilityLabel(text)
    }

    // MARK: - Menu construction

    private func rebuild() {
        menu.removeAllItems()

        menu.addItem(infoItem(title: "Routing to: \(currentTargetName())"))
        menu.addItem(infoItem(title: recentLine()))
        menu.addItem(NSMenuItem.separator())

        // TASK 08 INSERTS THE *Browsers* AND *Fallback Browser* SUBMENUS HERE, FOLLOWED BY ANOTHER SEPARATOR.

        menu.addItem(actionItem(title: "Set as Default Browser", action: #selector(setAsDefault)))

        let launchItem = actionItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin))
        launchItem.state = launchAtLoginState()
        menu.addItem(launchItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem(title: "Quit ActiveBrowser", action: #selector(quit), keyEquivalent: "q"))
    }

    private func infoItem(title: String) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        menuItem.isEnabled = false
        return menuItem
    }

    private func actionItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        // `NSMenuItem.target` is weak; this object is retained by `AppDelegate` (see type doc).
        menuItem.target = self
        menuItem.isEnabled = true
        return menuItem
    }

    /// The display name of the browser a URL would be routed to right now.
    ///
    /// The dispatcher is the single source of this value: the call below is the same resolution
    /// dispatch itself performs, so the menu and the behaviour can never disagree. This type must
    /// never re-derive it — no candidate walk of its own, no resolving against the stack, and no
    /// reading of `settings.defaultBrowser` as a display fallback.
    private func currentTargetName() -> String {
        guard let id = dispatcher.resolvedTargetId() else { return "none" }
        return registry.entry(for: id)?.name ?? id
    }

    /// `Recent: A › B › C › …`, capped at the first three entries.
    private func recentLine() -> String {
        let items = stack.items
        guard !items.isEmpty else { return "Recent: none yet" }
        let shown = items.prefix(Self.recentDisplayLimit)
            .map { registry.entry(for: $0)?.name ?? $0 }
            .joined(separator: " › ")
        let ellipsis = items.count > Self.recentDisplayLimit ? " › …" : ""
        return "Recent: \(shown)\(ellipsis)"
    }

    /// The checkmark state, derived from macOS's view of the login item — never from the
    /// `launchAtLoginOptOut` flag (see the type doc).
    private func launchAtLoginState() -> NSControl.StateValue {
        switch SMAppService.mainApp.status {
        case .enabled: return .on
        case .requiresApproval: return .mixed      // only the user can resolve this, in System Settings
        default: return .off
        }
    }

    // MARK: - Actions

    /// macOS treats `http` and `https` as one "default web browser" role and presents its own
    /// confirmation dialog, so a single call for `http` is issued; a second call for `https`
    /// risks a second dialog for one user intent.
    @objc private func setAsDefault() {
        // The completion handler is `@Sendable` and non-isolated: it captures nothing —
        // not `self`, not a menu item — and only logs.
        NSWorkspace.shared.setDefaultApplication(
            at: Bundle.main.bundleURL,
            toOpenURLsWithScheme: "http"
        ) { error in
            if let error {
                NSLog("ActiveBrowser: setDefaultApplication(http) failed: %@", error.localizedDescription)
            }
        }
    }

    /// Flips the login item, recording an explicit opt-out so the next launch does not undo it.
    ///
    /// The flag is written *before* the `SMAppService` call on both paths: if the call throws,
    /// the user's stated intent is still persisted, and the menu keeps telling the truth because
    /// the checkmark reads `status`.
    @objc private func toggleLaunchAtLogin() {
        let status = SMAppService.mainApp.status
        switch status {
        case .enabled:
            settings.launchAtLoginOptOut = true
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                NSLog("ActiveBrowser: login item: unregister() failed: %@", error.localizedDescription)
            }
        case .notRegistered, .notFound:
            settings.launchAtLoginOptOut = false
            do {
                try SMAppService.mainApp.register()
            } catch {
                NSLog("ActiveBrowser: login item: register() failed: %@", error.localizedDescription)
            }
        case .requiresApproval:
            // In this state only the user can change the switch, in System Settings. Calling
            // register()/unregister() here would produce a menu item that appears to do nothing,
            // and writing the flag would record an intent the user has not expressed.
            SMAppService.openSystemSettingsLoginItems()
        default:
            // Unknown future case: fail closed, same rule as the launch-time gate.
            NSLog("ActiveBrowser: login item: no action, unknown status=%ld", status.rawValue)
        }
        // Reflect the new status in the checkmark immediately.
        rebuild()
    }

    /// Quitting does not remove the login item and does not undo the default-browser binding.
    /// Once ActiveBrowser is the default handler, macOS relaunches it on the next link click —
    /// correct agent behaviour, not a bug to fix.
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
