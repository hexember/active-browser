import AppKit

/// Every installed application that can open `https://` URLs, minus this app itself.
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
    func refresh() {
        /// urlsForApplications(toOpen:) is a pure Launch Services database query. 
        /// It only reads the URL's scheme (https) to look up registered handlers; 
        /// No network call in done in production env; therefore keeping static url is safe
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
