# ActiveBrowser — Architecture & Implementation Plan

A macOS menu-bar agent that registers itself as the system default browser and forwards every clicked link to the browser the user most recently had in focus. If no browser has been focused yet, it falls back to a browser the user chose.

## 1. System Architecture

The app runs as an agent process (`LSUIElement = true`): no Dock icon, no main window, launched at login.

```
┌─────────────────────────────────────────────────────────────┐
│                       macOS System                          │
│                                                             │
│  [Any App / Terminal] ──(Clicks Link)──> Launch Services    │
│  [User switches App]  ───────────────> NSWorkspace Events   │
│  [Login]              ───────────────> SMAppService         │
└──────────────┬───────────────────────────────┬──────────────┘
               │                               │
               ▼ (open urls)                   ▼ (didActivateApplication)
┌─────────────────────────────────────────────────────────────┐
│                       ActiveBrowser                         │
│                                                             │
│  ┌─────────────────────────┐   ┌──────────────────────────┐ │
│  │    BrowserRegistry      │   │      FocusObserver       │ │
│  │ (all installed http     │   │ (touch stack when an     │ │
│  │  handlers, minus self)  │   │  included browser gets   │ │
│  └────────────┬────────────┘   │  focus)                  │ │
│               │                └─────────────┬────────────┘ │
│               ▼                              ▼              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Settings (UserDefaults)                               │ │
│  │   • includedBrowsers: Set<bundleId>  (user picks)      │ │
│  │   • defaultBrowser:   bundleId       (user picks)      │ │
│  └────────────────────────────┬───────────────────────────┘ │
│                               ▼                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  BrowserStack (LRU, @MainActor)                        │ │
│  │   head = most recently focused *included* browser      │ │
│  └────────────────────────────┬───────────────────────────┘ │
│                               ▼                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  URLDispatcher                                         │ │
│  │   first running browser in stack                       │ │
│  │   → else head of stack                                 │ │
│  │   → else settings.defaultBrowser                       │ │
│  │   → NSWorkspace.open(urls, withApplicationAt:)         │ │
│  └────────────────────────────┬───────────────────────────┘ │
└───────────────────────────────┼─────────────────────────────┘
                                ▼
              Target Browser (Brave / Arc / Safari / Chrome / …)
```

### Core Components

| Component | Responsibility |
|---|---|
| **BrowserRegistry** | Discovers every installed app that can open `https://` via `NSWorkspace.shared.urlsForApplications(toOpen:)`. Excludes `Bundle.main.bundleIdentifier`. Exposes `(bundleId, displayName, appURL)`. |
| **Settings** | `UserDefaults`-backed. `includedBrowsers` (which registry entries participate in routing) and `defaultBrowser` (fallback). First launch: include everything, default = first entry. |
| **BrowserStack** | `@MainActor` ordered list. `touch(id)` promotes to head; `prune(keeping:)` drops excluded/uninstalled ids. `resolveTarget(fallback:)` returns first *running* browser in the stack, else head, else fallback. |
| **FocusObserver** | `NSWorkspace.didActivateApplicationNotification` → if bundle id ∈ `includedBrowsers` → `stack.touch(id)`. |
| **URLDispatcher** | `application(_:open:)` → `resolveTarget` → `NSWorkspace.shared.open(urls, withApplicationAt:configuration:)`. |
| **MenuBarManager** | `NSStatusItem` showing current target; submenus to include/exclude browsers and pick the fallback; "Set as Default Browser", "Launch at Login", Quit. |

### Runtime rules

- **Every handler runs on the main thread.** Both inputs (`didActivateApplication` notification and `application(_:open:)`) are delivered on main; all state is `@MainActor`. No locks, no GCD queues.
- **Never route to self.** Registry and settings both exclude the app's own bundle id.
- **Never drop a URL.** `resolveTarget` always ends at `settings.defaultBrowser`; if even that is missing, open with the first registry entry.
- **No polling.** State changes only from system notifications and menu actions.
- **Login item.** `SMAppService.mainApp.register()` on first launch so the app is alive to observe focus before the first link is clicked.

## 2. Technical Stack

- Swift 6, strict concurrency, AppKit + ServiceManagement only. Zero third-party dependencies.
- macOS 13.0+ (needed for `SMAppService`; `urlsForApplications(toOpen:)` and `setDefaultApplication` are macOS 12+).
- Built with SwiftPM; the `.app` bundle is assembled by `make`.
- Targets: < 5 MB binary, ~10–15 MB idle RAM.

## 3. Implementation Plan

### Phase 1 — Core (`Core/`)
- `BrowserStack` (`@MainActor`, array-backed LRU).
- `BrowserRegistry` (Launch Services query, self-exclusion, display names).
- `Settings` (UserDefaults keys `includedBrowsers`, `defaultBrowser`).

### Phase 2 — Events & Routing (`App/`)
- `FocusObserver`: subscribe to `NSWorkspace.shared.notificationCenter`, filter on `includedBrowsers`, touch stack.
- `application(_:open:)`: resolve target, open URLs. Fallback chain as above.
- On launch: `registry.refresh()`, seed settings if empty, `stack.prune(keeping: includedBrowsers)`.

### Phase 3 — App Bundle & Makefile (before anything Launch Services related)
- `Support/Info.plist`: `CFBundleIdentifier`, `LSUIElement = YES`, `CFBundleURLTypes` for `http`/`https`.
- `Makefile`:
  - `make build` → `swift build -c release`
  - `make bundle` → `build/ActiveBrowser.app/Contents/{MacOS/ActiveBrowser, Info.plist}` + ad-hoc `codesign -s -`
  - `make install` → copy to `/Applications`, `lsregister -f` to register URL schemes
  - `make run`, `make clean`
- Verify: `Bundle.main.bundleIdentifier` is non-nil when launched from the bundle (self-filter depends on it).
- Why SPM alone is not enough: `swift build` emits a bare Mach-O; macOS only reads `Contents/Info.plist` from a `.app`, so `LSUIElement`, `CFBundleURLTypes`, the bundle id, and the default-browser list all depend on the `make bundle` step.
- Duplicate-registration gotcha: `make run` (opens `build/…app`) and `make install` (opens `/Applications/…app`) both register the same bundle id with Launch Services, and `setDefaultApplication` may bind to either copy. Test default-browser behaviour only from the installed copy; `make install` should `lsregister -u build/ActiveBrowser.app` first, and `make clean` should do the same before deleting it.

### Phase 4 — Launch Services Integration
- "Set as Default Browser" → `NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: "http")` (macOS shows its own confirmation).
- "Launch at Login" → `SMAppService.mainApp.register()` / `.unregister()`; reflect `.status` in the menu.
- Manual test on machine: set default, click links from Terminal/Slack/Mail, switch browsers, confirm routing.

### Phase 5 — Menu Bar UI (`UI/MenuBarManager.swift`)
```
[Icon: current target name]
  Routing to: Brave                (disabled)
  Recent: Brave › Chrome › Safari  (disabled)
  ──────────
  Browsers            ▸  ☑ Brave  ☑ Chrome  ☑ Safari  ☐ Zoom …   (toggle inclusion)
  Fallback Browser    ▸  ● Brave  ○ Chrome  ○ Safari           (radio, included only)
  ──────────
  Set as Default Browser
  ☑ Launch at Login
  ──────────
  Quit
```
- Toggling a browser off removes it from `includedBrowsers` and prunes the stack. If it was the fallback, fallback moves to the first remaining included browser.
- Registry re-scans when the menu opens (`NSMenuDelegate.menuWillOpen`) so newly installed browsers appear.

### Phase 6 — Distribution
- `make sign` (Developer ID) and `make notarize` (`notarytool`) targets.
- GitHub Release zip; optional Homebrew Cask.

Testing is manual on the developer's machine; no XCTest target.

## 4. Directory Structure

```
ActiveBrowser/
├── Package.swift
├── Makefile
├── Support/
│   └── Info.plist
└── Sources/
    └── ActiveBrowser/
        ├── App/
        │   ├── AppDelegate.swift        # @main, no main.swift
        │   └── FocusObserver.swift
        ├── Core/
        │   ├── BrowserRegistry.swift
        │   ├── BrowserStack.swift
        │   ├── Settings.swift
        │   └── URLDispatcher.swift
        └── UI/
            └── MenuBarManager.swift
```

## 5. Code Skeleton

### Support/Info.plist
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>        <string>com.local.activebrowser</string>
    <key>CFBundleName</key>              <string>ActiveBrowser</string>
    <key>CFBundleExecutable</key>        <string>ActiveBrowser</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key>           <string>1</string>
    <key>LSMinimumSystemVersion</key>    <string>13.0</string>
    <key>LSUIElement</key>               <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>    <string>Web Link Handler</string>
            <key>CFBundleURLSchemes</key> <array><string>http</string><string>https</string></array>
        </dict>
    </array>
</dict>
</plist>
```

### Package.swift
```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ActiveBrowser",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "ActiveBrowser", path: "Sources/ActiveBrowser")
    ]
)
```

### Core/BrowserStack.swift
```swift
import AppKit

@MainActor
final class BrowserStack {
    private(set) var items: [String] = []

    func touch(_ bundleId: String) {
        items.removeAll { $0 == bundleId }
        items.insert(bundleId, at: 0)
    }

    func prune(keeping valid: Set<String>) {
        items.removeAll { !valid.contains($0) }
    }

    /// First running browser in LRU order → head of stack → user fallback.
    func resolveTarget(fallback: String?) -> String? {
        let running = items.first {
            !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty
        }
        return running ?? items.first ?? fallback
    }
}
```

### Core/Settings.swift
```swift
import Foundation

@MainActor
final class Settings {
    private let defaults = UserDefaults.standard

    var includedBrowsers: Set<String> {
        get { Set(defaults.stringArray(forKey: "includedBrowsers") ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: "includedBrowsers") }
    }

    var defaultBrowser: String? {
        get { defaults.string(forKey: "defaultBrowser") }
        set { defaults.set(newValue, forKey: "defaultBrowser") }
    }
}
```

### Core/BrowserRegistry.swift
```swift
import AppKit

@MainActor
final class BrowserRegistry {
    struct Entry { let bundleId: String; let name: String; let url: URL }

    private(set) var installed: [Entry] = []

    func refresh() {
        let probe = URL(string: "https://example.com")!
        let me = Bundle.main.bundleIdentifier
        installed = NSWorkspace.shared.urlsForApplications(toOpen: probe).compactMap { url in
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
```

### App/AppDelegate.swift
```swift
import AppKit
import ServiceManagement

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let registry = BrowserRegistry()
    private let settings = Settings()
    private let stack = BrowserStack()
    private var menuBar: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registry.refresh()

        // First launch: include every detected browser, fallback = first one.
        if settings.includedBrowsers.isEmpty {
            settings.includedBrowsers = Set(registry.installed.map(\.bundleId))
        }
        if settings.defaultBrowser == nil {
            settings.defaultBrowser = registry.installed.first?.bundleId
        }
        stack.prune(keeping: settings.includedBrowsers)

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        menuBar = MenuBarManager(registry: registry, settings: settings, stack: stack)

        if SMAppService.mainApp.status == .notRegistered {
            try? SMAppService.mainApp.register()
        }
    }

    @objc private func appActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let id = app.bundleIdentifier,
              settings.includedBrowsers.contains(id) else { return }
        stack.touch(id)
        menuBar?.refresh()
    }

    // Called by Launch Services when we are the default browser.
    func application(_ application: NSApplication, open urls: [URL]) {
        let target = stack.resolveTarget(fallback: settings.defaultBrowser)
            ?? registry.installed.first?.bundleId
        guard let target,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target) else { return }
        NSWorkspace.shared.open(urls, withApplicationAt: appURL,
                                configuration: NSWorkspace.OpenConfiguration())
    }
}
```

### UI/MenuBarManager.swift (outline)
```swift
import AppKit
import ServiceManagement

@MainActor
final class MenuBarManager: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let registry: BrowserRegistry
    private let settings: Settings
    private let stack: BrowserStack

    init(registry: BrowserRegistry, settings: Settings, stack: BrowserStack) { … build menu; menu.delegate = self }

    func menuWillOpen(_ menu: NSMenu) { registry.refresh(); rebuild() }
    func refresh() { item.button?.title = currentTargetName }

    // Actions
    @objc func toggleBrowser(_ sender: NSMenuItem)     // flip includedBrowsers, prune stack, fix fallback
    @objc func chooseFallback(_ sender: NSMenuItem)    // settings.defaultBrowser = sender.representedObject
    @objc func setAsDefault()                          // NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: "http")
    @objc func toggleLaunchAtLogin()                   // SMAppService.mainApp.register()/unregister()
    @objc func quit()                                  // NSApp.terminate(nil)
}
```

### Makefile (targets)
```make
APP     = ActiveBrowser
BUILD   = .build/release/$(APP)
BUNDLE  = build/$(APP).app

build:
	swift build -c release

bundle: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	cp $(BUILD) $(BUNDLE)/Contents/MacOS/$(APP)
	cp Support/Info.plist $(BUNDLE)/Contents/Info.plist
	codesign --force --sign - $(BUNDLE)

install: bundle
	rm -rf /Applications/$(APP).app
	cp -R $(BUNDLE) /Applications/
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/$(APP).app

run: bundle
	open $(BUNDLE)

clean:
	rm -rf .build build
```
