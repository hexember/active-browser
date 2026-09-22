import AppKit

/// Owns the single `NSWorkspace.didActivateApplication` subscription and keeps the
/// LRU stack in sync with application focus.
///
/// **Observer lifetime — the observer is registered once and never removed, deliberately:**
/// 1. `NotificationCenter` does not retain a selector-based observer, so there is no retain cycle.
/// 2. Since macOS 10.11 observers registered with the selector-based variant are held
///    zeroing-weakly, so a dangling pointer is impossible.
/// 3. `FocusObserver` is owned non-optionally by `AppDelegate`, and the delegate itself is held
///    for the whole process lifetime by the entry point's `withExtendedLifetime(delegate) { app.run() }`
///    (`app.run()` never returns) — `NSApplication.delegate` is a weak reference and retains nothing.
///    So this object is never deallocated before exit.
///
/// Therefore there is no `deinit`, no `removeObserver` and no termination teardown. A `deinit`
/// would be `nonisolated` under Swift 6 and could not touch this type's `@MainActor` state.
@MainActor
final class FocusObserver: NSObject {
    private let settings: Settings
    private let stack: BrowserStack

    /// Guards against a second registration if `start()` is reached twice
    /// (cold-start link click can drive bootstrap from two entry points).
    private var isObserving = false

    /// Called after the stack has been updated by a focus change, i.e. only for an *included*
    /// browser that actually moved to the head of the stack.
    ///
    /// It runs on the main actor, synchronously, as part of handling the focus notification —
    /// which is exactly why menu surfaces use it instead of adding a second observer for the
    /// same notification: observer invocation order is unspecified, so a second observer could
    /// read the stack before this one has touched it.
    ///
    /// Owners must capture `self` **weakly** here: this object is owned non-optionally by
    /// `AppDelegate`, so a strong capture of the delegate closes a retain cycle.
    var onFocusChange: (() -> Void)?

    init(settings: Settings, stack: BrowserStack) {
        self.settings = settings
        self.stack = stack
        super.init()
    }

    /// Registers the one and only focus observer. Idempotent.
    func start() {
        guard !isObserving else { return }
        isObserving = true

        // Must be `NSWorkspace.shared.notificationCenter`: workspace notifications are never
        // posted to the process-wide default center, and using that one instead would
        // silently produce an app whose stack never updates.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func appActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let id = app.bundleIdentifier,
              settings.includedBrowsers.contains(id) else { return }
        stack.touch(id)
        onFocusChange?()
    }
}
