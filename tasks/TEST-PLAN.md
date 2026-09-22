# Consolidated Manual Test Plan

Append-only, in merge order. Each entry is the `user` rows from that task's Test Steps. Run top to bottom after merging the corresponding PRs; reset steps at the end of each block.

<!-- entries added by the main session when each PR opens -->

---

## PR #3 — Task 01: Core model (`feature/core-model`, base `main`)

No `user` steps. Phase 1 is build-and-inspection only; all 8 test steps were `ai` and ran green before the PR opened. Nothing for you to run here.

---

## PR #4 — Task 02: Events & routing (`feature/events-routing`, base `feature/core-model`)

No `user` steps. Phase 2 is still build-and-inspection only — there is no `.app` bundle until task 03, so nothing is clickable. All 12 test steps were `ai` and ran green before the PR opened.

Worth knowing when you review this PR: review round 1 caught a blocking runtime defect — `@main` on an `NSApplicationDelegate` compiles but never installs the delegate, so `application(_:open:)` would never have fired and every URL would have been dropped. Fixed with an explicit `static func main()`; verified by disassembling the binary and by launching a throwaway probe bundle.

---

## PR #5 — Task 03: App bundle & Makefile (`feature/bundle-makefile`, base `feature/events-routing`)

First PR with a runnable `.app`. All 15 `ai` steps ran green before the PR opened, including the first live proof of self-filtering (`includedBrowsers` seeded with Safari/Brave/cmux/Arc and **not** ActiveBrowser). One `user` step:

| # | Action | Expected |
|---|---|---|
| 1 | From the repo root run `make run`, wait ~3 s, then look at (a) the Dock, (b) ⌘Tab, (c) the menu bar. | (a) **No** ActiveBrowser icon in the Dock. (b) **No** ActiveBrowser entry in ⌘Tab. (c) **No** menu bar item — *this absence is correct for this PR;* the status item arrives in task 07. If a Dock icon or a window appears, `LSUIElement` is wrong and this PR should be rejected. |

**Reset after this block**
- `pkill -x ActiveBrowser` — mandatory. The app has no Quit and no Dock/⌘Tab presence until task 07, so this is the only way to stop it. Verify with `pgrep -x ActiveBrowser` printing nothing.
- `make clean` — unregisters the build copy from Launch Services, then removes `.build/` and `build/`.
- `defaults delete com.local.activebrowser` — so later tasks still see a genuine first launch.
- **Default browser: nothing to restore.** This task never changes it. Do not open System Settings for this PR.
