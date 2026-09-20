import AppKit

/// Resolves which browser a batch of URLs belongs to and opens them there.
///
/// This type is the single choke point for the *never drop a URL* guardrail: every
/// non-empty batch walks an ordered candidate list and stops at the first browser that
/// actually exists on disk.
///
/// **The plain, no-application `NSWorkspace` open form is forbidden anywhere in this
/// codebase.** ActiveBrowser is (or will be) the registered `http`/`https` handler, so
/// handing a URL to the system default would route it straight back into this process:
/// an infinite loop. Every open must go through `open(_:withApplicationAt:configuration:)`
/// with an explicit application URL.
@MainActor
final class URLDispatcher {
    private let registry: BrowserRegistry
    private let settings: Settings
    private let stack: BrowserStack

    init(registry: BrowserRegistry, settings: Settings, stack: BrowserStack) {
        self.registry = registry
        self.settings = settings
        self.stack = stack
    }

    /// Opens every URL in `urls` in the resolved target browser, in a single dispatch.
    func open(_ urls: [URL]) {
        // The only early exit in this function, and it drops nothing.
        guard !urls.isEmpty else { return }

        if let target = resolvedTarget() {
            NSWorkspace.shared.open(
                urls,
                withApplicationAt: target.appURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        } else {
            // The only path on which nothing opens: not one candidate resolved to an
            // application that exists on disk, i.e. this machine has no `https` handler
            // other than ActiveBrowser itself. Falling back to a system-default open here
            // would hand the URL back to us (see the type doc), so we stop and report.
            NSLog("ActiveBrowser: no other installed browser could be resolved; %ld URL(s) not opened.", urls.count)
        }
    }

    /// The bundle identifier `open(_:)` would route to right now, without opening anything.
    ///
    /// Menu surfaces (the *Routing to:* line) must call this rather than re-deriving
    /// resolution, so display and behaviour can never disagree.
    func resolvedTargetId() -> String? {
        resolvedTarget()?.bundleId
    }

    /// First candidate that resolves to an application present on disk.
    private func resolvedTarget() -> (bundleId: String, appURL: URL)? {
        for id in candidates() {
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
                ?? registry.entry(for: id)?.url else { continue }
            guard FileManager.default.fileExists(atPath: appURL.path) else { continue }
            return (id, appURL)
        }
        return nil
    }

    /// Dispatch candidates in priority order, de-duplicated (first occurrence wins) and
    /// with this app's own bundle identifier removed.
    ///
    /// Order: resolved stack target → the rest of the stack in LRU order →
    /// `settings.defaultBrowser` → every registry entry. This is the guardrail's
    /// "stack → default → first registry entry" chain, with the stack expanded so a
    /// single stale head cannot short-circuit it.
    private func candidates() -> [String] {
        var ordered: [String] = []
        if let head = stack.resolveTarget(fallback: nil) { ordered.append(head) }
        ordered.append(contentsOf: stack.items)
        if let fallback = settings.defaultBrowser { ordered.append(fallback) }
        ordered.append(contentsOf: registry.installed.map(\.bundleId))

        // Last line of loop prevention before an actual dispatch. Launch Services treats
        // bundle identifiers case-insensitively, so this is stricter than the registry's
        // `!=` filter. A `nil` self identifier (bare, unbundled binary) matches nothing.
        let me = Bundle.main.bundleIdentifier
        var seen = Set<String>()
        return ordered.filter { id in
            guard seen.insert(id).inserted else { return false }
            if let me, id.caseInsensitiveCompare(me) == .orderedSame { return false }
            return true
        }
    }
}
