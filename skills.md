# Required Skills & Technical Expertise

## 1. Swift 6 & Native macOS APIs
- **Concurrency & Thread Safety**: Strict concurrency checking, `@MainActor`, GCD barrier flags, and modern Swift actors.
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
- **Event-Driven Architecture**: Decoupled notification handlers, avoiding deadlocks between synchronous UI events and background queues.
- **Recursion & Loop Prevention**: Detecting and suppressing self-delegation loops where the router attempts to dispatch back to itself.

## 3. Tooling & Packaging
- **Swift Package Manager (SPM)**: Building native command-line/agent executables, managing configurations.
- **CLI Automation**: `Makefile` creation for compiling, code signing (`codesign`), packaging (`.app` directory bundle structure), and notarization (`notarytool`).
- **Testing**: `XCTest` unit test suites covering edge cases (missing browsers, rapid app switching, empty registry).
