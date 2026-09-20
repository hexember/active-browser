# Operational & Architectural Guardrails

## 1. Architectural & Platform Boundaries
- **Zero Third-Party Dependencies**: All implementations must strictly use native Swift standard libraries and Apple frameworks (`AppKit`, `Foundation`). No SPM or CocoaPods third-party packages.
- **Loop Prevention & Self-Filtering**: The application bundle identifier (`com.local.activebrowserrouter` or dynamic `Bundle.main.bundleIdentifier`) must never be added to the internal browser registry or targeted during URL dispatch.
- **Memory & Resource Caps**:
  - Idle footprint must not exceed 25 MB RAM.
  - Must run purely as a background agent (`LSUIElement = true`); no standard dock item or empty window frames may appear.
  - Polling mechanisms are forbidden. State must update strictly through event-driven system notifications (`NSWorkspace.didActivateApplicationNotification`).

## 2. Threading & Concurrency Rules
- **Non-Blocking UI/Notification Handlers**: The main thread must never perform synchronous file I/O or unbounded bundle scanning.
- **State Synchronization**: `BrowserStack` mutations and reads must use atomic synchronization (serial dispatch queue, concurrent queue with barrier write, or Swift actors). Data races under Thread Sanitizer (`swift test --sanitize=thread`) will fail review automatically.

## 3. Workflow & Code Integrity Rules
- **No Orphan Implementations**: The Code Implementer may not write code without an active specification approved by the Planning Agent.
- **Green Suite Requirement**: No commit or PR creation is allowed by the Git Agent if `swift build` or `swift test` produces errors or unhandled warnings.
- **Re-Plan Trigger Protocol**: If the Implementer encounters any of the following, it must stop and trigger an escalation back to the Planning Agent:
  - An API is deprecated or unavailable in target macOS 13.0+.
  - Expected system permissions (e.g., Apple Events or Automation) cause silent routing failures.
  - Changes are required outside the predefined directory structure.
