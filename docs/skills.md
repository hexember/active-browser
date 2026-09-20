# Required Skills & Technical Expertise

## 1. Swift 6 & Native macOS APIs
- **Concurrency**: Swift 6 strict concurrency checking and `@MainActor` isolation; understanding why every input to this app arrives on the main thread so no queues or locks are needed.
- **AppKit & Cocoa Frameworks**:
  - `NSWorkspace`: Application lifecycle events (`NSWorkspace.didActivateApplicationNotification`), URL routing (`open(_:withApplicationAt:configuration:)`), and Launch Services app resolution.
  - `NSRunningApplication`: Inspecting active process states, ownership, and bundle identifiers.
  - `NSStatusItem`: Menu bar integration, system tray state reflection, and status item menus.
- **Launch Services & Info.plist Management**:
  - URL scheme binding (`CFBundleURLTypes` for `http` and `https`).
  - Agent background execution flags (`LSUIElement = true`).
  - Default browser assignment triggers and validation.

## 2. Low-Level System Design & Algorithms
- **Least Recently Used (LRU) Caching**: Fast re-indexing, touch/promote semantics, pruning, and fallbacks.
- **Event-Driven Architecture**: Decoupled `NSWorkspace` notification handlers with no polling.
- **Recursion & Loop Prevention**: Detecting and suppressing self-delegation loops where the router attempts to dispatch back to itself.

## 3. Tooling & Packaging
- **Swift Package Manager (SPM)**: Building the executable; knowing SPM cannot produce an `.app` bundle on its own.
- **CLI Automation**: `Makefile` creation for compiling, code signing (`codesign`), packaging (`.app` directory bundle structure), and notarization (`notarytool`).
- **Manual Verification**: Exercising the installed bundle end to end — set as default browser, click links from Terminal/Slack/Mail, switch and quit browsers, confirm routing and fallback.
