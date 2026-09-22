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
            //
            // Prefer the bundled mark. `NSImage(named:)` resolves MenuBarIconTemplate.png
            // together with its @2x/@3x siblings in Contents/Resources into one 18x18pt
            // image, so it stays sharp on every display. It returns nil for any build whose
            // Resources directory was not assembled by `make bundle` -- a bare SwiftPM
            // binary, say -- so the system globe stays as the fallback rather than leaving
            // the status item blank.
            // No accessibilityDescription here: `refresh()` sets the button's own
            // accessibility label to the live routing target, which is what VoiceOver
            // reads on a status item, and setting it on the image would mutate the
            // process-wide NSImage name cache for no gain.
            let bundled = NSImage(named: "MenuBarIconTemplate")
            if let image = bundled
                ?? NSImage(systemSymbolName: "globe", accessibilityDescription: "ActiveBrowser") {
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

        menu.addItem(submenuItem(title: "Browsers", submenu: browsersMenu()))
        menu.addItem(submenuItem(title: "Fallback Browser", submenu: fallbackMenu()))
        menu.addItem(NSMenuItem.separator())

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

    /// A parent row that only opens a submenu: no action, no target, and deliberately enabled —
    /// with auto-enabling off a disabled parent cannot be opened at all.
    private func submenuItem(title: String, submenu: NSMenu) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        menuItem.target = nil
        menuItem.isEnabled = true
        menuItem.submenu = submenu
        return menuItem
    }

    /// The *Browsers* submenu: every installed handler, checked when it participates in routing.
    ///
    /// Nothing here repairs settings. An included identifier whose browser is not installed right
    /// now (external volume, app moved) is simply not drawn and keeps its place in
    /// `includedBrowsers`, so its checkmark returns when the browser does.
    private func browsersMenu() -> NSMenu {
        let submenu = NSMenu()
        // A freshly created menu auto-enables its items, and that validation pass runs *after* the
        // assignments below: it would re-enable the very row the last-checked guard disables. The
        // property is per-menu, so setting it on the root menu does not cover this one.
        submenu.autoenablesItems = false
        // No delegate here: `menuWillOpen(_:)` is delivered to the opening menu's own delegate, so
        // a submenu delegate would run `rebuild()` — and `menu.removeAllItems()` — while AppKit is
        // displaying this tree. The root's `menuWillOpen` has already rebuilt it.

        let entries = installedUnique()
        guard !entries.isEmpty else {
            // An empty submenu renders as a parent that cannot be opened, i.e. as a broken menu.
            submenu.addItem(infoItem(title: "No browsers found"))
            return submenu
        }

        let included = settings.includedBrowsers
        let visible = includedInstalledIds()
        // With exactly one browser checked, that row is disabled: the set can never become empty,
        // which is the first rung of the "never drop a URL" chain.
        let lockedId = visible.count == 1 ? visible.first : nil

        for entry in entries {
            let menuItem = actionItem(title: entry.name, action: #selector(toggleBrowser(_:)))
            menuItem.representedObject = entry.bundleId  // the identifier itself, never an index
            menuItem.state = included.contains(entry.bundleId) ? .on : .off
            menuItem.isEnabled = entry.bundleId != lockedId
            submenu.addItem(menuItem)
        }
        return submenu
    }

    /// The *Fallback Browser* submenu: the included browsers, one of them checked.
    ///
    /// A radio group by mutual exclusion, not by glyph: every row is recomputed against the one
    /// stored identifier, so two checked rows are structurally impossible. AppKit's checkmark is
    /// the platform convention for a mutually exclusive menu group, so no glyph is written into
    /// the titles and no custom state image is installed. The selected row stays enabled — a
    /// greyed-out selected option reads as "unavailable" — and re-picking it is idempotent.
    ///
    /// A stored fallback outside the included set (only reachable by an external `defaults write`)
    /// shows no checkmark rather than being rewritten behind the user's back; picking any row
    /// fixes it. That is also what makes this safe to build from `menuWillOpen`.
    private func fallbackMenu() -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        let ids = orderedIncluded()
        guard !ids.isEmpty else {
            submenu.addItem(infoItem(title: "No included browsers"))
            return submenu
        }

        let fallback = settings.defaultBrowser
        for id in ids {
            let menuItem = actionItem(title: registry.entry(for: id)?.name ?? id,
                                      action: #selector(chooseFallback(_:)))
            menuItem.representedObject = id
            menuItem.state = id == fallback ? .on : .off
            submenu.addItem(menuItem)
        }
        return submenu
    }

    // MARK: - Derived state

    /// Installed handlers, first occurrence per bundle identifier wins, registry (display-name)
    /// order preserved.
    ///
    /// `BrowserRegistry.refresh()` does not de-duplicate: Launch Services returns one result per
    /// copy on disk, so two installs of the same browser produce two entries with the same bundle
    /// identifier. Drawn straight that lists the browser twice and — worse — makes the
    /// last-checked guard count two for what is one logical browser, which is exactly the path
    /// that lets `includedBrowsers` reach empty. Both submenus and the guard count use this.
    private func installedUnique() -> [BrowserRegistry.Entry] {
        var seen = Set<String>()
        return registry.installed.filter { seen.insert($0.bundleId).inserted }
    }

    /// The checkmarks the user can actually see: installed handlers that are also included, in
    /// menu order. The last-checked guard counts these and not the stored set, because an
    /// identifier stored for a browser that is not installed right now is not drawn and therefore
    /// cannot be unchecked.
    private func includedInstalledIds() -> [String] {
        let included = settings.includedBrowsers
        return installedUnique().map(\.bundleId).filter { included.contains($0) }
    }

    /// Included browsers in menu order: installed ones in registry display-name order first, then
    /// any included-but-not-installed identifiers in bundle-identifier order.
    ///
    /// Deterministic by construction. `Set` iteration order is not: Swift seeds hashing per
    /// process, so `includedBrowsers.first` and iterating the set directly give a different answer
    /// on every launch, and a fallback migration built on that would pick a different browser each
    /// time — a bug no report would ever reproduce. `Set` order must never be used to choose an
    /// ordering in this file; this function is the only ordering source.
    private func orderedIncluded() -> [String] {
        let installed = includedInstalledIds()
        let rest = settings.includedBrowsers.subtracting(installed).sorted()
        return installed + rest
    }

    /// `true` when `id` is this app's own bundle identifier.
    ///
    /// Launch Services compares bundle identifiers case-insensitively, so this mirrors
    /// `URLDispatcher.candidates()` rather than the registry's `!=` filter. A `nil` self
    /// identifier (bare, unbundled binary) matches nothing.
    private func isSelfBundleId(_ id: String) -> Bool {
        guard let me = Bundle.main.bundleIdentifier else { return false }
        return id.caseInsensitiveCompare(me) == .orderedSame
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

    /// Includes or excludes one browser.
    ///
    /// The identifier travels on `representedObject`, so the action reads the state itself and not
    /// an index into `registry.installed` — that array is re-sorted and re-sized by the
    /// `menuWillOpen` rescan, which would make an index refer to the wrong browser. The title is
    /// never read either: display names are localised and are not identifiers.
    @objc private func toggleBrowser(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        // Unreachable — the rows come from the registry, which already drops this app — but
        // `includedBrowsers` is named in the self-filtering guardrail and this is the only place
        // in the codebase where user input writes it.
        guard !isSelfBundleId(id) else { return }

        var included = settings.includedBrowsers
        if included.contains(id) {
            // The same invariant the view enforces by disabling the row, restated where the set is
            // written: a disabled item is still reachable through accessibility and
            // `NSMenu.performActionForItem(at:)`, and the invariant belongs to the writer.
            guard includedInstalledIds().count > 1 else { return }
            included.remove(id)
            settings.includedBrowsers = included          // persist first: every read below is off the stored truth
            stack.prune(keeping: settings.includedBrowsers)  // stops being a routing candidate immediately
            if settings.defaultBrowser == id {
                // Under the guard above the list cannot be empty here; the `??` exists so the key
                // is never written `nil`, which would weaken the never-drop-a-URL chain.
                settings.defaultBrowser = orderedIncluded().first ?? settings.defaultBrowser
            }
        } else {
            // Re-including deliberately touches settings and nothing else: it is not a focus event,
            // so the stack is left alone and the browser rejoins routing on its next activation.
            included.insert(id)
            settings.includedBrowsers = included
        }

        // Never mutate `sender.state` in place: the menu is recomputed from the persisted truth,
        // and the tooltip is refreshed because this click can have changed the routing target.
        rebuild()
        refresh()
    }

    /// Picks the browser a URL goes to when the stack resolves to nothing.
    @objc private func chooseFallback(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        guard !isSelfBundleId(id) else { return }

        settings.defaultBrowser = id
        rebuild()
        refresh()
    }

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
