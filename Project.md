Here is the complete architectural blueprint, milestone plan, and implementation strategy for building this macOS utility (named ActiveBrowser).

1. System Architecture & Component Design

The app runs as an agent process (LSUIElement = true) with no Dock icon or main window, consuming minimal system resources.

┌─────────────────────────────────────────────────────────────┐
│                       macOS System                          │
│                                                             │
│  [Any App / Terminal] ──(Clicks Link)──> Launch Services    │
│  [User switches App]  ───────────────> NSWorkspace Events   │
└──────────────┬───────────────────────────────┬──────────────┘
               │                               │
               ▼ (open urls)                   ▼ (didActivateApplication)
┌─────────────────────────────────────────────────────────────┐
│                    ActiveBrowserRouter                      │
│                                                             │
│  ┌─────────────────────────┐   ┌──────────────────────────┐ │
│  │   Browser Discovery     │   │     App Lifecycle &      │ │
│  │  (Launch Services Query)│   │     Event Observer       │ │
│  └────────────┬────────────┘   └─────────────┬────────────┘ │
│               │                              │              │
│               ▼                              ▼              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                   BrowserStack (LRU)                   │ │
│  │         [ Top / Head: Most Recently Focused ]          │ │
│  └────────────────────────────┬───────────────────────────┘ │
│                               │                             │
│                               ▼                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                      URL Dispatcher                    │ │
│  │     (Inspects top running process -> NSWorkspace.open) │ │
│  └────────────────────────────┬───────────────────────────┘ │
└───────────────────────────────┼─────────────────────────────┘
                                │
                                ▼
         Target Browser (Brave / Arc / Safari / Chrome/ any other installed)


Core Components

1. BrowserRegistry: Discovers all installed apps supporting http/https using NSWorkspace.shared.urlsForApplications(toOpen:). Ignores the app's own bundle identifier.
2. BrowserStack: Thread-safe ordered collection implementing LRU touch/promotion logic. Top of the stack (index 0) is always the most recently focused browser.
3. FocusObserver: Listens to NSWorkspace.didActivateApplicationNotification. When an activated app's bundle ID matches the registry, it invokes BrowserStack.touch(bundleId:).
4. URLDispatcher: Handles application(_:open:). Finds the first running browser from the stack (or launches the top browser if none are active) and delegates the URL via NSWorkspace.shared.open(...).
5. StatusBarController (Optional UI): A minimal menu bar item (NSStatusItem) showing the current target browser, a "Set as Default Browser" button, and a Quit button.

2. Technical Stack & Dependencies

⚬ Language: Swift 6.
⚬ UI Framework: AppKit (macOS native, zero Electron or heavy wrapper dependencies).
⚬ Target OS: macOS 13.0 (Ventura) and later.
⚬ Binary Size & Memory: Target < 5MB uncompressed binary; idling at approx 10 - 15MB RAM.
⚬ Dependencies: None (100% native Cocoa/Foundation APIs).

3. Implementation Plan & Milestones

Phase 1: Core Engine & Data Structures

⚬ Implement BrowserStack with atomic mutation locks.
⚬ Implement BrowserRegistry querying Launch Services for installed browser bundle IDs.
⚬ Unit test:
  ⚬ Insertion and promotion of middle/tail items to head.
  ⚬ Handling uninstalled/removed bundle IDs.
  ⚬ Empty stack fallbacks.

Phase 2: System Event Listening & Routing

⚬ Hook up NSWorkspace.didActivateApplicationNotification to update the stack in real time.
⚬ Implement NSApplicationDelegate's application(_:open:) method for handling incoming http/https URLs.
⚬ Filter out self-delegation loops to avoid recursive launch issues.

Phase 3: Manifest Configuration & Launch Services Setup (Day 5)

⚬ Configure Info.plist:
  ⚬ Add CFBundleURLTypes for http and https schemes.
  ⚬ Set LSUIElement = YES to run headless in the background.
⚬ Integrate macOS prompt to set as default: NSWorkspace.shared.setDefaultApplication(...).

Phase 4: Menu Bar UI & Polishing

⚬ Add a simple menu bar icon (NSStatusItem) showing:
  ⚬ Currently detected active browser.
  ⚬ Stack order preview (for debugging/transparency).
  ⚬ Quick links to set default browser and quit.

Phase 5: Build Automation & Packaging

⚬ Add a Makefile or Swift Package Manager (Package.swift) build script.
⚬ Provide ad-hoc / developer ID codesigning and notarization scripts for distribution via GitHub Releases or Homebrew Cask.

4. Complete Project Directory Structure

ActiveBrowserRouter/
├── Package.swift               # Or Xcode project file (.xcodeproj)
├── Makefile                    # CLI build & install tasks
└── Sources/
    └── ActiveBrowserRouter/
        ├── App/
        │   ├── AppDelegate.swift
        │   └── main.swift
        ├── Core/
        │   ├── BrowserRegistry.swift
        │   ├── BrowserStack.swift
        │   └── URLDispatcher.swift
        ├── Observers/
        │   └── FocusObserver.swift
        ├── UI/
        │   └── MenuBarManager.swift
        └── Resources/
            └── Info.plist


5. Implementation Code Skeleton

Info.plist

<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.local.activebrowserrouter</string>
    <key>CFBundleName</key>
    <string>ActiveBrowserRouter</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>Web Link Handler</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>http</string>
                <string>https</string>
            </array>
        </dict>
    </array>
</dict>
</plist>


Sources/ActiveBrowserRouter/Core/BrowserStack.swift

import Cocoa

public final class BrowserStack {
    private var items: [String] = []
    private let queue = DispatchQueue(label: "com.activebrowserrouter.stack", attributes: .concurrent)

    public func touch(bundleId: String) {
        queue.async(flags: .barrier) {
            if let index = self.items.firstIndex(of: bundleId) {
                self.items.remove(at: index)
            }
            self.items.insert(bundleId, at: 0)
        }
    }

    public func prune(validBundleIds: Set<String>) {
        queue.async(flags: .barrier) {
            self.items.removeAll { !validBundleIds.contains($0) }
        }
    }

    public func resolveTarget() -> String? {
        queue.sync {
            // Pick the first browser from top to bottom that is currently running
            let runningTarget = self.items.first { bundleId in
                !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
            }
            return runningTarget ?? self.items.first
        }
    }
}


Sources/ActiveBrowserRouter/App/AppDelegate.swift

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private let stack = BrowserStack()
    private var detectedBrowsers: Set<String> = []

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        refreshBrowserRegistry()

        // Observe application focus changes
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(onAppActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    private func refreshBrowserRegistry() {
        guard let testUrl = URL(string: "https://apple.com") else { return }
        let appUrls = NSWorkspace.shared.urlsForApplications(toOpen: testUrl)
        let myId = Bundle.main.bundleIdentifier

        detectedBrowsers = Set(
            appUrls.compactMap { url in
                guard let bundle = Bundle(url: url),
                      let id = bundle.bundleIdentifier,
                      id != myId else { return nil }
                return id
            }
        )
        stack.prune(validBundleIds: detectedBrowsers)
    }

    @objc private func onAppActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier,
              detectedBrowsers.contains(bundleId) else {
            return
        }
        stack.touch(bundleId: bundleId)
    }

    // Handles incoming URL events when set as system default browser
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let targetBundleId = stack.resolveTarget(),
              let targetUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: targetBundleId) else {
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        for url in urls {
            NSWorkspace.shared.open([url], withApplicationAt: targetUrl, configuration: config)
        }
    }
}
