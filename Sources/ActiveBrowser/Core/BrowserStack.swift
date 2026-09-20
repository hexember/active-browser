import AppKit

/// Ordered list of browser bundle identifiers, most recently focused first.
///
/// Pure state: it is mutated only by `touch(_:)` (focus events) and
/// `prune(keeping:)` (registry/settings changes). No timers, no polling.
@MainActor
final class BrowserStack {
    /// Bundle identifiers in LRU order; `items.first` is the most recently focused browser.
    /// Never contains duplicates.
    private(set) var items: [String] = []

    /// Promotes `bundleId` to the head of the stack.
    ///
    /// Idempotent: every existing occurrence is removed before the insert, so the
    /// stack can never hold the same identifier twice.
    func touch(_ bundleId: String) {
        items.removeAll { $0 == bundleId }
        items.insert(bundleId, at: 0)
    }

    /// Drops every identifier that is not in `valid`, preserving the order of the survivors.
    func prune(keeping valid: Set<String>) {
        items.removeAll { !valid.contains($0) }
    }

    /// Resolves the browser a URL should be routed to.
    ///
    /// Resolution order, exactly:
    /// 1. the first item in LRU order that is currently running
    ///    (`NSRunningApplication.runningApplications(withBundleIdentifier:)` is non-empty),
    /// 2. otherwise `items.first` (the most recently focused browser, even if it is not running),
    /// 3. otherwise `fallback` (the user-chosen default browser).
    ///
    /// Returns `nil` only when the stack is empty *and* `fallback` is `nil`; a non-nil
    /// `fallback` is never discarded.
    func resolveTarget(fallback: String?) -> String? {
        let running = items.first {
            !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty
        }
        return running ?? items.first ?? fallback
    }
}
