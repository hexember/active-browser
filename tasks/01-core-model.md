# Task 01 — Core model: BrowserStack, BrowserRegistry, Settings, Package.swift

Status: pr-open
Phase: 1
Branch: feature/core-model
Base: main
PR: https://github.com/hexember/active-browser/pull/3
Created: 2026-09-20

## Goal
Stand up the SwiftPM package and the three pure-state `Core/` types — `BrowserStack` (LRU + target resolution), `BrowserRegistry` (Launch Services discovery with self-exclusion) and `Settings` (UserDefaults-backed inclusion list + fallback) — so every later phase has a compiling, `@MainActor`-isolated model layer to build on.

## Spec (planner)

### Entry-point decision (read first)
An `.executableTarget` cannot link without an entry point, and `AppDelegate.swift` (`@main`) does not arrive until task 02. `Project.md` §4 explicitly forbids a `main.swift` ("`AppDelegate.swift  # @main, no main.swift`"), so a throwaway `main.swift` placeholder is **not** allowed — it would also be a file outside the §4 structure.

**Decision: declare the target as a plain `.target` (library) in this task.** A library target needs no entry point, links cleanly, and costs zero throwaway Swift code.

**Hand-off contract for task 02:** task 02 must (a) change the single line `.target(name: "ActiveBrowser", path: "Sources/ActiveBrowser")` to `.executableTarget(name: "ActiveBrowser", path: "Sources/ActiveBrowser")` in `Package.swift`, and (b) add `Sources/ActiveBrowser/App/AppDelegate.swift` carrying `@main`. `Package.swift` is the only file this task creates that task 02 is expected to edit. Do **not** pre-declare `.executableTarget` here and do **not** add `products:` — an executable product with no entry point fails to link.

### Checklist
- [x] **`Package.swift`** (repo root, new) — `// swift-tools-version:6.0`, `import PackageDescription`, `name: "ActiveBrowser"`, `platforms: [.macOS(.v13)]`, single `.target(name: "ActiveBrowser", path: "Sources/ActiveBrowser")`. No `dependencies:`, no `products:`, no test target, no `swiftSettings` unsafe flags. Swift 6 language mode is the tools-version default — do not opt out of it.
- [x] **`Sources/ActiveBrowser/Core/BrowserStack.swift`** (new) — `@MainActor final class BrowserStack` per `Project.md` §5:
      - `private(set) var items: [String] = []` (bundle ids, head = most recently focused).
      - `touch(_ bundleId: String)` — remove all existing occurrences, insert at index 0 (idempotent; no duplicates ever).
      - `prune(keeping valid: Set<String>)` — `items.removeAll { !valid.contains($0) }`, order of survivors preserved.
      - `resolveTarget(fallback: String?) -> String?` — resolution order **exactly**: (1) first item in LRU order with a non-empty `NSRunningApplication.runningApplications(withBundleIdentifier:)`, (2) `items.first`, (3) `fallback`. Add a doc comment naming that order (Phase 1 Verify step 2 is an inspection of this).
      - `import AppKit`. No polling, no timers, no GCD.
- [x] **`Sources/ActiveBrowser/Core/BrowserRegistry.swift`** (new) — `@MainActor final class BrowserRegistry` per `Project.md` §5:
      - `struct Entry { let bundleId: String; let name: String; let url: URL }`; declare it `Sendable` only if it compiles warning-free without extra work (all stored properties already are).
      - `private(set) var installed: [Entry] = []`.
      - `refresh()` — `NSWorkspace.shared.urlsForApplications(toOpen: URL(string: "https://example.com")!)` (macOS 12+, current API — do **not** use the deprecated `LSCopyAllHandlersForURLScheme`), `compactMap` each result through `Bundle(url:)`, skip entries whose `bundleIdentifier` is nil or equals `Bundle.main.bundleIdentifier`, resolve the display name as `CFBundleDisplayName` → `CFBundleName` → `url.deletingPathExtension().lastPathComponent`, then sort by `localizedCaseInsensitiveCompare` ascending.
      - `entry(for bundleId: String) -> Entry?`.
      - File I/O is limited to each candidate's `Info.plist` via `Bundle.infoDictionary` (guardrail §2) — no directory walking, no `FileManager` enumeration.
- [x] **`Sources/ActiveBrowser/Core/Settings.swift`** (new) — `@MainActor final class Settings` per `Project.md` §5:
      - `private let defaults = UserDefaults.standard`.
      - `var includedBrowsers: Set<String>` — get `Set(defaults.stringArray(forKey:) ?? [])`, set `defaults.set(Array(newValue).sorted(), forKey:)`.
      - `var defaultBrowser: String?` — get `defaults.string(forKey:)`, set `defaults.set(newValue, forKey:)`.
      - Key strings must be exactly `"includedBrowsers"` and `"defaultBrowser"`; put them in a `private enum Keys` (or equivalent constants) so getter and setter cannot drift.
      - Seeding on first launch is **not** done here — `AppDelegate` owns it (task 02). This class stores and reads only.
- [x] Verify nothing else is created: no `App/`, no `UI/`, no `Support/`, no `Makefile`, no `Core/URLDispatcher.swift` (task 02), no XCTest target, no `Tests/` directory.

### Acceptance criteria
- `swift build` and `swift build -c release` both succeed from the repo root with **zero** warnings and zero errors (guardrail §3).
- `git status --porcelain` after the change lists exactly: `Package.swift`, the three `Sources/ActiveBrowser/Core/*.swift` files, and this task file. Nothing else.
- All three classes are `@MainActor final class`; the source tree contains no `DispatchQueue`, no `NSLock`, no `actor`, no `Timer`, no `@main`, and no `main.swift`.
- `BrowserRegistry.refresh()` contains an explicit comparison against `Bundle.main.bundleIdentifier` that drops the self entry (guardrail §1, loop prevention).
- `BrowserStack.resolveTarget(fallback:)` returns `nil` only when the stack is empty *and* `fallback` is `nil` — i.e. it never discards a non-nil fallback (guardrail §1, never drop a URL; the last-resort "first registry entry" link is added by task 02).
- `Package.swift` declares no external dependencies (guardrail §1).

### Architectural notes and risks
- **Library-target window.** Between this PR and task 02 the package builds no executable. This is intentional and time-boxed to one task; the reviewer should confirm the `.target` → `.executableTarget` hand-off note above is reproduced in the Implementation Notes so task 02 cannot miss it.
- **`Bundle.main.bundleIdentifier` is `nil` under bare `swift build`.** Self-filtering is therefore inert until the `.app` bundle exists (task 03) — this matches guardrail §1's "Bundle Required" note. Write the comparison so a `nil` self-id simply filters nothing (`id != me` with `me: String?`); do not force-unwrap and do not `precondition` on it.
- **`UserDefaults.standard` domain differs between the bare binary and the bundled app.** Values written while testing a non-bundled build will not appear in the installed app. Harmless now; relevant when Phase 5 persistence is tested.
- **`urlsForApplications(toOpen:)` returns every `https` handler**, which on many machines includes non-browsers (Zoom, Slack, script editors). That is expected — `Project.md` §5 Phase 5 lets the user untick them. Do not add a heuristic "is it a browser" filter in this task.
- **Sorting.** `localizedCaseInsensitiveCompare` is locale-dependent, so registry order (and therefore the task-02 seeded fallback) can differ between machines. Acceptable for v1; do not switch to raw `<`.
- **Out of scope but worth flagging to the main session:** the repo has no `.gitignore`, so `swift build` leaves an untracked `.build/` directory. Committing it would be a large accidental payload. This task's scope is fixed at four files, so either the git-agent excludes `.build/` at commit time or a `.gitignore` is added as its own trivial task — do not silently widen this PR to cover it.

## Implementation Notes (implementer)

**What was built** — four files, nothing else:
- `Package.swift` — `// swift-tools-version:6.0`, `name: "ActiveBrowser"`, `platforms: [.macOS(.v13)]`, a single `.target(name: "ActiveBrowser", path: "Sources/ActiveBrowser")`. No `dependencies:`, no `products:`, no test target, no `swiftSettings`. Swift 6 language mode is left at the tools-version default.
- `Sources/ActiveBrowser/Core/BrowserStack.swift` — `@MainActor final class BrowserStack` with `private(set) var items: [String]`, `touch(_:)` (removeAll-then-insert-at-0, so it is idempotent and never duplicates), `prune(keeping:)` (order of survivors preserved) and `resolveTarget(fallback:)` with a doc comment spelling out the resolution order for the Phase 1 Verify step 2 inspection.
- `Sources/ActiveBrowser/Core/BrowserRegistry.swift` — `@MainActor final class BrowserRegistry`, nested `struct Entry: Sendable { bundleId, name, url }`, `private(set) var installed: [Entry]`, `refresh()` over `NSWorkspace.shared.urlsForApplications(toOpen:)` and `entry(for:)`.
- `Sources/ActiveBrowser/Core/Settings.swift` — `@MainActor final class Settings`, `private enum Keys` holding the two literals, computed `includedBrowsers: Set<String>` and `defaultBrowser: String?`. No seeding logic.

**Hand-off contract for task 02 (reproduced verbatim from the Spec, so it cannot be missed):** task 02 must (a) change the single line `.target(name: "ActiveBrowser", path: "Sources/ActiveBrowser")` to `.executableTarget(name: "ActiveBrowser", path: "Sources/ActiveBrowser")` in `Package.swift`, and (b) add `Sources/ActiveBrowser/App/AppDelegate.swift` carrying `@main`. `Package.swift` is the only file this task creates that task 02 is expected to edit. A plain `.target` is used here because an `.executableTarget` cannot link without an entry point and `Project.md` §4 forbids a `main.swift`. Until task 02 lands, the package builds a library and produces no runnable binary — intentional and time-boxed to this one task.

**Decisions**
- `Entry` is declared `Sendable`. It compiled warning-free with no extra work (all stored properties are `String`/`URL`), so the Spec's conditional applies.
- Self-filtering is written as `id != me` with `let me: String? = Bundle.main.bundleIdentifier`. Under a bare `swift build` binary `me` is `nil`, so nothing is filtered — no force-unwrap, no `precondition`, per the Spec's risk note. A comment in `refresh()` records this.
- `refresh()`'s `compactMap` closure carries an explicit `-> Entry?` return type; without it Swift 6 cannot infer the closure result from the `guard ... else { return nil }` shape.
- `resolveTarget(fallback:)` is `running ?? items.first ?? fallback`, so it returns `nil` only when `items` is empty **and** `fallback` is `nil` — a non-nil fallback is never discarded.

**Deviations from the Spec:** none in code. One deviation in the build result, below.

**Build environment finding (affects the zero-warning acceptance criterion).** This machine has no Xcode — `xcode-select -p` is `/Library/Developer/CommandLineTools`, and `/Library/Developer/CommandLineTools/Developer` does not exist. The toolchain injects a framework search path pointing inside it, so **every** link step on this machine emits exactly one linker warning:

```
Package.swift: ActiveBrowser: ld: warning: search path '/Library/Developer/CommandLineTools/Developer/Library/Frameworks' not found
```

This is not produced by project code. I reproduced it with a throwaway package containing a single `public let x = 1` and an otherwise identical `Package.swift` (built in the scratch dir, then deleted) — same warning, same wording. It is emitted for the auto-synthesised library product's link step and will be emitted identically once the target becomes an `.executableTarget` in task 02. Removing it would require installing Xcode or `sudo`-creating a directory under `/Library/Developer`, i.e. changes outside the repo; unsafe `swiftSettings` flags are forbidden by the Spec. **Zero warnings are emitted by the Swift compiler for the three source files** (`grep "warning:" … | grep -v "search path"` matches nothing in both configurations). Flagging for the main session: Test Steps 1 and 2 expect `grep -c "warning:"` to print `0`; on this machine they print `1` for the toolchain warning above. A `grep -c "warning:" … ` that excludes `search path` prints `0`.

**Verification run**
- `swift build` → `Build complete! (21.23 secs)`, 0 errors, 1 toolchain linker warning (above), 0 source warnings.
- `swift build -c release` → `Build complete! (17.81 secs)`, 0 errors, 1 toolchain linker warning (above), 0 source warnings.
- `grep -rnE "DispatchQueue|NSLock|^actor |Timer|@main" Sources/ Package.swift` → no matches (exit 1). No `main.swift`, no `App/`, no `UI/`, no `Support/`, no `Makefile`, no `Tests/`.
- `find Sources -type f` → exactly `Core/BrowserRegistry.swift`, `Core/BrowserStack.swift`, `Core/Settings.swift`.
- `git status --porcelain` → `Package.swift`, `Sources/`, `tasks/01-core-model.md`, plus the untracked `.build/` the Spec already flags as out of scope (repo has no `.gitignore`; git-agent must exclude it at commit time).

Build: `swift build` clean (0 errors; 0 source warnings; 1 pre-existing toolchain linker warning `ld: warning: search path '/Library/Developer/CommandLineTools/Developer/Library/Frameworks' not found`, reproducible on an empty package, not fixable from the repo) · `make bundle` n/a — no Makefile exists until task 03 (Phase 3).

## Review (code-reviewer)
Verdict: APPROVED

Reviewed 2026-09-20 against the Spec above, `Project.md` §5 and `.claude/rules/guardrails.md`. All four files read in full; both builds run by me from a cleaned `.build/`, plus a runtime probe of the three types compiled with `swiftc -swift-version 6` in the scratch dir (copies, not repo files).

**Verification performed (not taken from the Implementation Notes)**
- `rm -rf .build && swift build` → `Build complete! (19.14 secs)`; `swift build -c release` → `Build complete! (17.07 secs)`. Both: 1 warning total, 0 after excluding the environmental `ld: warning: search path '/Library/Developer/CommandLineTools/Developer/Library/Frameworks' not found`. Zero warnings attributable to project sources in either configuration.
- `swift build --verbose` shows `-swift-version 6` on every compile job, so Swift 6 language mode (full strict concurrency) is genuinely in effect — the `@MainActor` isolation is enforced, not advisory.
- `grep -rnE "DispatchQueue|NSLock|^actor |Timer|@main|@unchecked|main.swift" Sources/ Package.swift` → no matches. No GCD, no locks, no timers, no `@unchecked Sendable` escape, no polling.
- `find Sources -type f` → exactly the three `Core/*.swift` files. No `App/`, `UI/`, `Support/`, `Makefile`, `Tests/`.
- Runtime probe: `Settings.defaultBrowser = nil` correctly clears the key (the `Any?` overload receives `Optional<String>.none`, not a boxed optional, so no property-list crash); `includedBrowsers` round-trips as a sorted array; `BrowserRegistry.refresh()` returned 4 entries in case-insensitive order (`Arc`, `Brave Browser`, `cmux`, `Safari` — the lowercase `cmux` sorting between `Brave` and `Safari` proves the comparator); `BrowserStack.touch` de-duplicates and promotes, `prune` preserves survivor order, `resolveTarget(fallback:)` returns `"fb"` on an empty stack and `nil` only when both stack and fallback are empty.

**Findings**
- None blocking. No memory finding applies: this task registers no `NSWorkspace` observer and no menu target, so there is no retain-cycle surface yet (`AppDelegate`'s observer lands in task 02 and will need its own check).
- Guardrails: `Sources/ActiveBrowser/Core/BrowserRegistry.swift:26,30` carries the explicit `let me = Bundle.main.bundleIdentifier` / `id != me` self-drop with `me` left optional, so a `nil` self id filters nothing rather than crashing — matches guardrail §1 and the Spec's risk note. `Sources/ActiveBrowser/Core/BrowserStack.swift:41` (`running ?? items.first ?? fallback`) never discards a non-nil fallback. `Package.swift` declares no dependencies and no products. File I/O in `refresh()` is bounded to `Bundle(url:)`/`infoDictionary` of Launch Services results; no enumeration.
- Launch Services / `Info.plist` / `make bundle` checks are not applicable to this task — `Support/` and the `Makefile` arrive in task 03 (confirmed absent, as the Spec requires).
- Spec conformance: every checklist item is implemented exactly, and nothing beyond it. `Entry: Sendable` is justified (all stored properties are `String`/`URL`); I additionally confirmed the nested `Entry` is constructible from a `nonisolated` context under `-swift-version 6`, so declaring it `Sendable` creates no isolation trap for task 02's dispatcher.
- Non-blocking forward note (do **not** widen this PR): `refresh()` does not de-duplicate by bundle id, so if Launch Services ever returns two copies of the same app (e.g. after task 03's `make run` + `make install` both register a bundle), `installed` can hold two entries with the same id. Harmless here — ActiveBrowser's own copies are removed by the self-filter — but task 07/08 should decide whether the *Browsers* submenu tolerates duplicates.

**Test Steps executability** — steps 3–7 are executable and pass against the code as written. Three steps cannot pass as literally worded; none is a code defect, so they need a recorded interpretation rather than an implementation change:
- **Step 1 and Step 2** expect `grep -c "warning:"` to print `0`. On this machine both print `1`, because every link step emits the toolchain's `search path ... /Library/Developer/CommandLineTools/Developer/Library/Frameworks not found` warning (no Xcode installed; reproducible on an empty package, outside the repo's control). The substantive criterion — zero warnings from project sources — holds: `grep "warning:" <log> | grep -v "search path" | wc -l` prints `0` in both configurations. Record these as pass with that exclusion noted, or have the planner amend the command to `grep -c "warning:" <log> | grep -v "search path"` in a later task.
- **Step 8** expects `git status --porcelain` to list only the four files. It actually also lists `?? .build/`, and because the files are untracked it collapses `Sources/` to one directory entry (`git status --porcelain -uall` instead floods with hundreds of `.build/` paths). The Spec itself flags the missing `.gitignore` as out of scope, so the step is satisfiable only as "the four files are the only things *staged/committed*" — the git-agent must add only `Package.swift Sources/ActiveBrowser/Core Package.swift tasks/01-core-model.md` explicitly and never `git add -A`. Recommend recording step 8 against `git status --porcelain -uall -- Package.swift Sources tasks` (which lists exactly the four files) and raising the `.gitignore` as its own trivial task.
- **Step 6** nit: the command in the table is markdown-escaped (`"DispatchQueue\|NSLock\|..."`). Run literally under `grep -E`, `\|` matches a literal pipe character and the check passes vacuously. Unescape the pipes before running; I ran the unescaped form and it matched nothing.
- The hand-off contract for task 02 (`.target` → `.executableTarget` + `App/AppDelegate.swift` with `@main`) is reproduced verbatim in the Implementation Notes, as the Spec's architectural note required.

## Test Steps (planner writes; `ai` rows run by the main session before the PR opens, `user` rows by the human at the PR)

**Preconditions**
- Build: no `.app` bundle exists at this phase — there is nothing to install or run. All steps are build + source inspection, run from the repo root `/Users/suneel/Documents/project-101/active-browser`.
- System state: none required. This task changes no system state (no Launch Services registration, no default browser, no login item).
- Covers: Project.md §3 Phase 1 Verify steps 1–2, plus task-specific scope and guardrail checks. No `user` rows for this task.

| # | Who | Action (exact command / click) | Expected | Actual | Result |
|---|---|---|---|---|---|
| 1 | ai | `swift build 2>&1 \| tee /tmp/ab-build-debug.log; grep -c "warning:" /tmp/ab-build-debug.log` | `Build complete!` and the grep prints `0` (zero warnings, zero errors) | `Build complete! (19.19 secs)`. Total `warning:` lines = 1, all of it the environmental `ld: warning: search path '/Library/Developer/CommandLineTools/Developer/Library/Frameworks' not found` (no Xcode on this machine; reproducible on an empty package). Warnings attributable to project sources = **0**. | pass |
| 2 | ai | `swift build -c release 2>&1 \| tee /tmp/ab-build-release.log; grep -c "warning:" /tmp/ab-build-release.log` | `Build complete!` and the grep prints `0` — Project.md Phase 1 Verify step 1 | `Build complete! (17.32 secs)`. Same single environmental linker warning; project-source warnings = **0**. | pass |
| 3 | ai | Read `Sources/ActiveBrowser/Core/BrowserStack.swift` | `resolveTarget(fallback:)` returns, in this order: first running item → `items.first` → `fallback`; `touch` inserts at index 0 after removing duplicates | Confirmed. `resolveTarget` body is `running ?? items.first ?? fallback` where `running = items.first { !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty }`; doc comment names all three steps. `touch` does `removeAll`-then-`insert(at: 0)`. | pass |
| 4 | ai | Read `Sources/ActiveBrowser/Core/BrowserRegistry.swift` | `refresh()` uses `urlsForApplications(toOpen:)` and drops the entry equal to `Bundle.main.bundleIdentifier`; name falls back display→name→filename; sorted case-insensitively | Confirmed. `let me = Bundle.main.bundleIdentifier` + `guard … id != me else { return nil }`; name chain `CFBundleDisplayName` ?? `CFBundleName` ?? `lastPathComponent`; `.sorted { localizedCaseInsensitiveCompare == .orderedAscending }`. | pass |
| 5 | ai | Read `Sources/ActiveBrowser/Core/Settings.swift` | Keys are exactly `includedBrowsers` and `defaultBrowser`, shared by getter and setter via constants; no first-launch seeding | Confirmed. `private enum Keys` holds both literals; both accessors reference `Keys.*`. No seeding logic in the file. | pass |
| 6 | ai | `grep -rnE "DispatchQueue\|NSLock\|^actor \|Timer\|@main\|@unchecked" Sources/ Package.swift; find Sources -type f` (pipes unescaped when run) | grep prints nothing; `Sources/ActiveBrowser` contains only `Core/` with the three files; no `main.swift`, `App/`, `UI/`, `Tests/` | grep: no matches (exit 1). `find` returned exactly `Core/BrowserRegistry.swift`, `Core/BrowserStack.swift`, `Core/Settings.swift`. `Tests/` absent, `main.swift` count 0. | pass |
| 7 | ai | `cat Package.swift` | tools-version 6.0, `.macOS(.v13)`, exactly one `.target(name: "ActiveBrowser", path: "Sources/ActiveBrowser")`, no `dependencies:`, no `products:`, no test target | Matches exactly; 10 lines, no `dependencies:`, no `products:`, no test target. | pass |
| 8 | ai | `git status --porcelain -uall -- Package.swift Sources tasks` | Lists only `Package.swift`, the three `Core/*.swift` files and `tasks/01-core-model.md`; `.build/` not staged | Exactly those five paths, all `??`. Unscoped `git status --porcelain` additionally shows `?? .build/` (repo has no `.gitignore`); git-agent instructed to stage the five paths explicitly, never `git add -A`. | pass |

**Reset after testing**
- No system state is changed by this task, so nothing needs restoring. Optional cleanup of build artefacts: `cd /Users/suneel/Documents/project-101/active-browser && rm -rf .build /tmp/ab-build-debug.log /tmp/ab-build-release.log`.
- Do **not** run `lsregister`, `make install` or `make clean` for this task — neither a bundle nor a Makefile exists yet.

**Result (ai rows):** pass — all 8 `ai` steps pass — 2026-09-20
**Result (user rows):** n/a — this task has no `user` steps, so nothing is appended to `tasks/TEST-PLAN.md`.
Failures: none. Recorded interpretations: steps 1–2 count 1 environmental toolchain linker warning that is not produced by project code (no Xcode installed on this machine, reproducible on an empty package); step 8 is scoped with `-uall -- Package.swift Sources tasks` because the repo has no `.gitignore` and `.build/` would otherwise appear.

## Next
Task 02 (Phase 2): flip `Package.swift`'s `.target` to `.executableTarget` and add `Sources/ActiveBrowser/App/AppDelegate.swift` with `@main` — the focus observer and `application(_:open:)` dispatch, seeding `Settings` from `BrowserRegistry` on first launch and calling `stack.prune(keeping:)`.
