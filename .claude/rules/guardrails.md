# Operational & Architectural Guardrails

## 1. Architectural & Platform Boundaries
- **Zero Third-Party Dependencies**: Native Swift + Apple frameworks only (`AppKit`, `Foundation`, `ServiceManagement`). No SPM or CocoaPods third-party packages.
- **Loop Prevention & Self-Filtering**: `Bundle.main.bundleIdentifier` must never appear in the registry, `includedBrowsers`, `defaultBrowser`, or be targeted during URL dispatch.
- **Never Drop a URL**: `application(_:open:)` must always resolve to some browser — stack → `settings.defaultBrowser` → first registry entry.
- **Resource Caps**:
  - Idle footprint must not exceed 25 MB RAM.
  - Background agent only (`LSUIElement = true`); no Dock item, no windows.
  - Polling is forbidden. State updates only through `NSWorkspace` notifications and user menu actions.
- **Bundle Required**: The app must be run from the `.app` bundle assembled by `make bundle`. Launch Services registration, `LSUIElement`, and self-filtering do not work from a bare SwiftPM executable.

## 2. Concurrency Rules
- All app state (`BrowserStack`, `BrowserRegistry`, `Settings`, `MenuBarManager`) is `@MainActor`. No GCD queues, no locks, no actors beyond `MainActor`.
- The main thread must never perform unbounded file I/O. Registry refresh reads only `Info.plist` of Launch Services results.

## 3. Workflow & Code Integrity Rules
- **No Orphan Implementations**: Code is written only against an approved specification in `Project.md`.
- **Green Build Requirement**: No commit or PR if `swift build` produces errors or warnings.
- **Testing**: Manual, on the developer's machine, per the checklist in `Project.md` Phase 4. No XCTest target.
- **Re-Plan Trigger Protocol**: Stop and escalate to planning if:
  - An API is deprecated or unavailable on macOS 13.0+.
  - System permissions cause silent routing failures.
  - Changes are required outside the directory structure defined in `Project.md` §4.
