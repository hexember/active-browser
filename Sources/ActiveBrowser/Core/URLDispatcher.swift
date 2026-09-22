import AppKit

/// Resolves which browser a batch of URLs belongs to and opens them there.
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

        if let target: (bundleId: String, appURL: URL) = resolvedTarget() {
            NSWorkspace.shared.open(
                urls,
                withApplicationAt: target.appURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        } else {
            NSLog("ActiveBrowser: no other installed browser could be resolved; %ld URL(s) not opened.", urls.count)
        }
    }

    /// The bundle identifier `open(_:)` would route to right now, without opening anything.
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
    private func candidates() -> [String] {
        var ordered: [String] = []
        if let head = stack.resolveTarget(fallback: nil) { ordered.append(head) }
        ordered.append(contentsOf: stack.items)
        if let fallback = settings.defaultBrowser { ordered.append(fallback) }
        ordered.append(contentsOf: registry.installed.map(\.bundleId))

        let me = Bundle.main.bundleIdentifier
        var seen = Set<String>()
        return ordered.filter { id in
            guard seen.insert(id).inserted else { return false }
            if let me, id.caseInsensitiveCompare(me) == .orderedSame { return false }
            return true
        }
    }
}
