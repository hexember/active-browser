import AppKit

/// Every installed application that can open `https://` URLs, minus this app itself.
///
/// File I/O is limited to reading the `Info.plist` of each candidate returned by
/// Launch Services (via `Bundle.infoDictionary`); no directory is enumerated.
@MainActor
final class BrowserRegistry {
    struct Entry: Sendable {
        let bundleId: String
        let name: String
        let url: URL
    }

    /// Discovered handlers, sorted by display name, case-insensitively ascending.
    private(set) var installed: [Entry] = []

    /// Re-queries Launch Services for the `https` handlers.
    ///
    /// The app's own bundle identifier is dropped so a URL can never be routed back to
    /// ActiveBrowser. Under a bare `swift build` binary `Bundle.main.bundleIdentifier`
    /// is `nil`, in which case nothing is filtered — self-filtering becomes live once
    /// the app runs from its `.app` bundle.
    func refresh() {
        let probe = URL(string: "https://example.com")!
        let me = Bundle.main.bundleIdentifier
        installed = NSWorkspace.shared.urlsForApplications(toOpen: probe).compactMap { url -> Entry? in
            guard let bundle = Bundle(url: url),
                  let id = bundle.bundleIdentifier,
                  id != me else { return nil }
            let info = bundle.infoDictionary ?? [:]
            let name = (info["CFBundleDisplayName"] as? String)
                ?? (info["CFBundleName"] as? String)
                ?? url.deletingPathExtension().lastPathComponent
            return Entry(bundleId: id, name: name, url: url)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func entry(for bundleId: String) -> Entry? {
        installed.first { $0.bundleId == bundleId }
    }
}
