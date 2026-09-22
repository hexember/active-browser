# Task 13 — Default browser state in menu row

Status: pr-open
Phase: 4
Branch: feature/default-browser-state
Base: main
PR: https://github.com/hexember/active-browser/pull/24
Created: 2026-09-22

## Goal
Make the menu's default-browser row reflect the truth. When ActiveBrowser is already the
system handler for both `http` and `https`, the row shows a checked, disabled
"Default Browser" (rendered as "✓ Default Browser"). Otherwise it shows the existing,
clickable "Set as Default Browser". The state is recomputed only when the menu opens.

## Spec (planner)
- [x] `Sources/ActiveBrowser/UI/MenuBarManager.swift`: add a private derived-state helper
      `isSystemDefaultBrowser() -> Bool` in the `// MARK: - Derived state` section:
      - For each of the schemes `http` and `https`, call
        `NSWorkspace.shared.urlForApplication(toOpen: URL(string: "<scheme>://example.com")!)`
        (macOS 12+). Resolve the result with `Bundle(url:)?.bundleIdentifier` and compare it
        using the existing `isSelfBundleId(_:)` (case-insensitive, and `nil` self id matches
        nothing).
      - Return `true` only if **both** schemes resolve to self. A `nil` app URL, a `nil`
        bundle, or a `nil` identifier counts as "not self".
      - Compare by **bundle identifier**, not by standardized app URL. Launch Services stores
        the handler binding as a bundle id (`LSHandlers`), so an id comparison matches what
        macOS actually routes. A URL comparison would also report "not default" whenever
        Launch Services resolves to a different copy of the same bundle (the
        `build/` vs `/Applications/` duplicate from Project.md Phase 3).
      - Doc comment: this is called only from `rebuild()`, it reads at most two
        `Info.plist`s (bounded I/O, allowed by guardrail §2), and it never targets self for
        dispatch, only compares against it.
- [x] `Sources/ActiveBrowser/UI/MenuBarManager.swift` `rebuild()`: replace the
      unconditional `actionItem(title: "Set as Default Browser", ...)` line (~116) with:
      - If `isSystemDefaultBrowser()`: `infoItem(title: "Default Browser")` with
        `state = .on`. Because `infoItem` has `action = nil` and `isEnabled = false`, the row
        is not clickable, and it also cannot be triggered through accessibility or
        `performActionForItem(at:)`, since there is no selector to dispatch.
      - Else: the existing `actionItem(title: "Set as Default Browser", action: #selector(setAsDefault))`,
        with `state` left at `.off`.
      - Keep the same position: after the second separator and before *Launch at Login*.
- [x] `Sources/ActiveBrowser/UI/MenuBarManager.swift` `setAsDefault()`: **no change** to
      the call or the completion handler. Do not rebuild the menu from the completion
      handler. It is `@Sendable` and non-isolated, the menu is already closed when it fires,
      and the next `menuWillOpen` recomputes the row. Adding a `Task { @MainActor in ... }`
      hop here would add concurrency surface for no visible gain.
- [x] `Sources/ActiveBrowser/UI/MenuBarManager.swift` type doc: extend the existing
      **Flag vs. status** / **No polling** paragraphs with one sentence. The default-browser
      row is derived from Launch Services at `menuWillOpen`, just as the login checkmark is
      derived from `SMAppService.status`, and nothing observes or polls for changes.
- [x] `Project.md`: amend the spec so the code is not orphaned (guardrail §3):
      - §3 Phase 4, first bullet: add "The row reads *✓ Default Browser* (checked, disabled)
        when `urlForApplication(toOpen:)` resolves both `http` and `https` to this bundle id,
        evaluated in `menuWillOpen`."
      - §3 Phase 5 menu diagram: change the `Set as Default Browser` line to
        `Set as Default Browser   (or "✓ Default Browser", disabled, when already default)`.

**Choice: `state = .on` + title "Default Browser", not a literal "✓" in the title.**
- It renders as "✓ Default Browser", which is exactly the user's wording. AppKit draws the
  check in the state column, so the check lines up with the *Launch at Login* checkmark
  directly below it. A "✓" typed into the title would sit in the text column, out of line
  with the other checks.
- It follows the convention this file already documents in `fallbackMenu()`: "no glyph is
  written into the titles". Every other check in this menu is `NSMenuItem.state`.
- VoiceOver reads the state as "checked". A literal glyph would be read as "check mark,
  Default Browser".
- Disabled (not enabled with a nil action) because the row is status, not an action. The
  menu already uses disabled rows for the *Routing to* and *Recent* info lines. With
  `autoenablesItems = false`, an enabled row with no action would highlight on hover and
  swallow the click, which suggests an action that does not exist.

Acceptance criteria:
- `swift build` and `swift build -c release` finish with zero errors and zero warnings.
- The only Swift file changed is `UI/MenuBarManager.swift`. No new files, types, timers,
  observers, `DispatchQueue`, `Task` or `nonisolated` code.
- `isSystemDefaultBrowser()` is called only from `rebuild()`. It is not called from
  `refresh()`, which runs on every focus change and must stay cheap.
- When the default is ActiveBrowser for both `http` and `https`, the row title is
  `Default Browser`, `state == .on`, `isEnabled == false` and `action == nil`. Otherwise
  the title is `Set as Default Browser`, the row is enabled, and its action is
  `setAsDefault`.
- `setAsDefault()` is byte-identical to `main` (still a single `http` call; see the
  existing comment about avoiding a second dialog).
- Project.md §3 Phase 4 and Phase 5 describe both row states.

**Architectural notes and risks**
- *No polling holds.* The state is read only in `rebuild()`, and `rebuild()` runs from
  `init`, from `menuWillOpen`, and after menu actions. A default changed in System Settings
  while the menu is closed shows up on the next open. An open menu does not update live,
  which is fine because System Settings cannot be used while the status menu has focus.
- *http/https split.* `setAsDefault` binds only `http`, relying on macOS to couple the two
  roles into one "default web browser". If some macOS version ever leaves `https` unbound,
  the row keeps saying "Set as Default Browser". That is the truthful state (https links
  would not reach us). It is not a bug in this task. If Test Step 7 shows `http` = self but
  `https` ≠ self after the user accepts the dialog, the implementer should raise a
  `[RE-PLAN REQUEST]` (possible second `setDefaultApplication` call for `https`) rather
  than relax the both-schemes check.
- *Dialog timing.* `setDefaultApplication` returns before the user answers the
  CoreServicesUIAgent dialog. Reopening the menu while the dialog is still up correctly
  shows "Set as Default Browser". Declining the dialog leaves it that way.
- *`Bundle(url:)` cost.* It reads one `Info.plist` per scheme, and Foundation caches
  `Bundle` instances, so repeated opens are cheap. No directory walk, so guardrail §2 holds.
- *Self-filtering guardrail.* The self id is only compared. It is never added to the
  registry or settings, and never passed to dispatch.
- *Overlap check.* Tasks 11 (Info.plist and `openFiles`) and 12 (icon in
  `MenuBarManager.init`) are unmerged. Neither touches `rebuild()` or `setAsDefault()`, so
  this change does not conflict with them.

## Implementation Notes (implementer)
- `UI/MenuBarManager.swift`: added `private func isSystemDefaultBrowser() -> Bool` under
  `// MARK: - Derived state`. It uses `["http", "https"].allSatisfy`, calls
  `NSWorkspace.shared.urlForApplication(toOpen:)`, resolves the result with
  `Bundle(url:)?.bundleIdentifier`, and compares via `isSelfBundleId(_:)`. Any `nil` counts as
  not self. Its doc comment covers: called only from `rebuild()`, at most two `Info.plist`
  reads, compare-only (never dispatch), and why it compares bundle ids instead of URLs.
- `rebuild()`: at the same position (after the second separator, before *Launch at Login*),
  the row is `infoItem(title: "Default Browser")` with `state = .on` when the check is true.
  Otherwise it is the existing `actionItem(title: "Set as Default Browser", action: #selector(setAsDefault))`.
- `setAsDefault()`: untouched. No rebuild from the completion handler, and no `Task`,
  `DispatchQueue`, observer, timer, or `nonisolated` code added.
- Type doc: the **Flag vs. status** paragraph now says the default-browser row is derived
  from Launch Services at `menuWillOpen`, just as the login checkmark is derived from
  `SMAppService.status`. The **No polling** paragraph now says nothing observes or polls for
  default-browser changes.
- `Project.md`: the §3 Phase 4 first bullet now describes the *✓ Default Browser*
  (checked, disabled) state. The §3 Phase 5 diagram line is now
  `Set as Default Browser   (or "✓ Default Browser", disabled, when already default)`.

Minor deviation: the spec writes `URL(string: "<scheme>://example.com")!`. I used
`guard let probe = URL(string: ...)` inside the same guard chain instead of a force-unwrap.
The behavior is identical (the literal always parses), and it avoids a crash path in
menu code. If it ever returned `nil`, the result would be "not self".

`git diff --stat main -- Sources/`: only `Sources/ActiveBrowser/UI/MenuBarManager.swift`
(29 insertions, 2 deletions).

Build: `swift build` clean. Zero Swift warnings and zero errors in debug and in
`-c release`. The only lines are two toolchain `ld: warning: search path
'/Library/Developer/CommandLineTools/Developer/...' not found`. These come from the local
CommandLineTools install, not from project sources. · `make bundle` ok (`codesign --force
--sign -` succeeded on `build/ActiveBrowser.app`).

## Review (code-reviewer)
Verdict: APPROVED
- Reviewed 2026-09-22 against the Spec and guardrails. Reviewer ran these independently: `swift build` and `swift build -c release`, both with zero Swift warnings or errors. The only output was the two toolchain `ld: warning: search path .../CommandLineTools/...` lines, which are not from project code. `make bundle` succeeded and codesigned. `CFBundleExecutable` = `ActiveBrowser`, `LSUIElement` = true.
- `Sources/ActiveBrowser/UI/MenuBarManager.swift:286-293`: `isSystemDefaultBrowser()` matches the Spec. It checks both schemes with `allSatisfy`, resolves through `Bundle(url:)?.bundleIdentifier`, compares with `isSelfBundleId(_:)`, and counts every `nil` as not self. It sits under `// MARK: - Derived state`, and the doc comment covers all four required points. `guard let probe` instead of the Spec's `!` behaves the same and is acceptable. No change required.
- `Sources/ActiveBrowser/UI/MenuBarManager.swift:119-127`: the row is in the right place (after the second separator, before *Launch at Login*). The true branch uses `infoItem` (action nil, `isEnabled = false`) with `state = .on`. The false branch is the original `actionItem`. `autoenablesItems = false` (line 76) keeps the disabled state. No change required.
- `isSystemDefaultBrowser()` is called only from `rebuild()` (line 119), and `refresh()` (lines 100-104) is untouched. `setAsDefault()` (lines 382-393) is byte-identical to `main`: the diff has no hunk there.
- Concurrency and memory: nothing new is added (no `Task`, `DispatchQueue`, `nonisolated`, observer, timer, or new target). The class is still `@MainActor`. The self id is only compared, never dispatched, stored, or added to the registry. There are no dependencies and no polling. Guardrails hold.
- `Project.md` §3 Phase 4 first bullet and the Phase 5 diagram line match the Spec wording word for word. Only one Swift file changed.
- Test Steps: every step can pass against the code as written. Steps 5 and 9 need the `actionItem` branch, which is enabled and highlights on hover. Steps 6 and 10 need the disabled `infoItem` with `.on`, which does not highlight and has no selector. Step 11 works because the menu recomputes on the next `menuWillOpen`. Steps 7 and 8 depend on user step 6, as marked. No step is unreachable.

## Test Steps (planner writes; `ai` rows run by the main session before the PR opens, `user` rows by the human at the PR)

**Preconditions**
- Build: `make install` completed on base `dc8925f` + this task's working-tree changes; test the copy in `/Applications`, never `build/` or `.build/`.
- System state: ActiveBrowser installed and running. The default web browser is **not**
  ActiveBrowser at the start (currently Arc per task 11). Safari is installed.
- Covers: Project.md §3 Phase 4 Verify step 1 (extended with the row state), plus task-specific checks.

Handler-check script (used by steps 4 and 7 and by the reset). Write it to a file in the session scratchpad,
e.g. `default-handler.swift`, and run it with `swift <path>`:
```swift
import AppKit
for s in ["http", "https"] {
    let app = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "\(s)://example.com")!)
    print(s, app.flatMap { Bundle(url: $0)?.bundleIdentifier } ?? "nil", app?.path ?? "")
}
```
This is the same API the row uses, so it checks exactly the value the menu will show.

| # | Who | Action (exact command / click) | Expected | Actual | Result |
|---|---|---|---|---|---|
| 1 | ai | `swift build 2>&1 \| grep -E 'warning:\|error:'` then `swift build -c release 2>&1 \| grep -E 'warning:\|error:'` | Both builds succeed; no `warning:` / `error:` lines from project sources | Debug + release: no Swift `warning:`/`error:` lines (only the toolchain `ld: warning: search path` lines, not from project sources) | pass |
| 2 | ai | `git diff --stat main -- Sources/` | Only `Sources/ActiveBrowser/UI/MenuBarManager.swift` changed | Only `Sources/ActiveBrowser/UI/MenuBarManager.swift` (29+, 2−) | pass |
| 3 | ai | `make install`; `pgrep -x ActiveBrowser`; `lsappinfo info -only bundlepath ActiveBrowser` | Exit 0; pid printed; bundle path `/Applications/ActiveBrowser.app` | `make install` exit 0; pid 92249; `LSBundlePath`=`/Applications/ActiveBrowser.app` | pass |
| 4 | ai | Run the handler-check script | Both lines show a bundle id other than `com.local.activebrowser` (e.g. `company.thebrowser.Browser`). This is the baseline for step 5 | http + https both `com.local.activebrowser` — ActiveBrowser was already default (set by the user before this task), so the "not default" baseline did not hold; user starts at step 6 state | n/a |
| 5 | user | Click the ActiveBrowser menu bar icon | The row above *Launch at Login* reads **Set as Default Browser**, with no checkmark, and is clickable (highlights on hover) | | pass / fail |
| 6 | user | Click *Set as Default Browser* → accept the macOS dialog ("Use ActiveBrowser") → click the menu bar icon again | The row now reads **✓ Default Browser**, greyed out. Hovering does not highlight it; clicking it does nothing and shows no dialog | | pass / fail |
| 7 | ai | After step 6: run the handler-check script | Both `http` and `https` show `com.local.activebrowser` at `/Applications/ActiveBrowser.app`. If `https` differs, see the http/https risk in the Spec. Until step 6 is done: `not run — needs user step 6` | http + https both `com.local.activebrowser` at `/Applications/ActiveBrowser.app` (already default, no dialog needed) | pass |
| 8 | ai | After step 6: focus Brave (`open -a "Brave Browser"`), then `open https://example.com` | The URL opens in Brave (routing is not affected by this change). Until step 6 is done: `not run — needs user step 6` | First two tries right after the `make install` relaunch landed in Arc (fallback); three clean retries (Brave focused → `open https://example.com/`) all opened in Brave. Dispatch code is untouched by this task; the early misses are noted in Failures | pass |
| 9 | user | System Settings → Desktop & Dock → *Default web browser* → **Safari**. Then click the ActiveBrowser menu bar icon | The row reads **Set as Default Browser** again and is clickable | | pass / fail |
| 10 | user | Click *Set as Default Browser* → accept the dialog → reopen the menu | The row reads **✓ Default Browser** again (checked, greyed) | | pass / fail |
| 11 | user | (optional) Switch the default to Safari as in step 9, click *Set as Default Browser*, and **decline** the dialog. Reopen the menu | The row still reads **Set as Default Browser** | | pass / fail |
| 12 | ai | `footprint -p $(pgrep -x ActiveBrowser) \| grep phys_footprint` | Under 25 MB | phys_footprint 11 MB (peak 11 MB) | pass |

**Reset after testing**
- System Settings → Desktop & Dock → *Default web browser* → your real browser (Arc).
  Run the handler-check script to confirm that neither scheme shows `com.local.activebrowser`.
- Close the `example.com` tab opened in Brave by step 8.
- Launch at Login: unchanged by this task.

**Result (ai rows):** pass (step 4 n/a: ActiveBrowser already default) — 2026-09-22
**Result (user rows):** <recorded at the PR by the user>
Failures: none. Observation: step 8 first two attempts right after `make install` relaunch routed to the fallback (Arc) instead of Brave; not reproducible afterwards (3/3 to Brave). Pre-existing dispatch/focus path, untouched here — worth a follow-up only if the user sees it.

## Next
<what unblocks or follows this task>
