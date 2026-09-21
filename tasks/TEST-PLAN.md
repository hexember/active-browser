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

---

## PR #6 — Task 04: make install (`feature/make-install`, base `feature/bundle-makefile`)

All 15 `ai` steps pass. A duplicate-Launch-Services-registration defect was found and **fixed** in this PR (two earlier attempts failed; see `tasks/04-make-install.md` Failures for the measurements). ActiveBrowser now appears exactly **once** in the *Default web browser* list.

| # | Action | Expected |
|---|---|---|
| 1 | Open System Settings → Desktop & Dock → scroll to *Default web browser* and open the dropdown. **Look only — do NOT select ActiveBrowser.** Selecting it is task 05. | **ActiveBrowser is listed exactly once**, and your current default is still **Arc**. Phase 3 Verify step 4. Two ActiveBrowser rows would mean this PR's fix regressed. Close the dropdown with Esc. |

**Reset after this block**
- **Do NOT run the teardown between tasks.** Tasks 05-08 all need the installed copy in `/Applications`. Run the teardown once, at the very end of the whole stack (last block in this file).
- **Default browser: nothing to restore.** This task never changes it; steps 1 and 14 assert Arc before and after.
- Note: `make install` now deletes `build/ActiveBrowser.app` as part of the fix. `make bundle` recreates it if you want it back.

---

## PR #<04> — Task 04: make install (`feature/make-install`, base `feature/bundle-makefile`)

14 of 15 `ai` steps pass. **Step 11 fails — a known limitation this PR ships with**: after `make install`, macOS re-registers the rebuilt `build/ActiveBrowser.app` about 1–3 s later, so Launch Services holds two records for `com.local.activebrowser` and the *Default web browser* dropdown lists **ActiveBrowser twice**. The handler role is bound by explicit URL (`Bundle.main.bundleURL` of the running `/Applications` copy), so this cannot silently point your default browser at the disposable `build/` copy — the harm is the duplicated row. Full analysis and the verified remedy are in `tasks/04-make-install.md` under Failures.

| # | Action | Expected |
|---|---|---|
| 1 | Open System Settings → Desktop & Dock → scroll to *Default web browser* and open the dropdown. **Look only — do NOT select ActiveBrowser.** Selecting it is task 05. | **ActiveBrowser is listed exactly once**, and your current default is still **Arc**. Phase 3 Verify step 4. Two ActiveBrowser rows would mean this PR's fix regressed. Close the dropdown with Esc. |

**Reset after this block**
- **Do NOT run the teardown between tasks.** Tasks 05-08 all need the installed copy in `/Applications`. Run the teardown once, at the very end of the whole stack (last block in this file).
- **Default browser: nothing to restore.** This task never changes it; steps 1 and 14 assert Arc before and after.
- Note: `make install` now deletes `build/ActiveBrowser.app` as part of the fix. `make bundle` recreates it if you want it back.

---

## PR #<04> — Task 04: make install (`feature/make-install`, base `feature/bundle-makefile`)

14 of 15 `ai` steps pass. **Step 11 fails — a known limitation this PR ships with**: after `make install`, macOS re-registers the rebuilt `build/ActiveBrowser.app` about 1–3 s later, so Launch Services holds two records for `com.local.activebrowser` and the *Default web browser* dropdown lists **ActiveBrowser twice**. The handler role is bound by explicit URL (`Bundle.main.bundleURL` of the running `/Applications` copy), so this cannot silently point your default browser at the disposable `build/` copy — the harm is the duplicated row. Full analysis and the verified remedy are in `tasks/04-make-install.md` under Failures.

| # | Action | Expected |
|---|---|---|
| 1 | Open System Settings → Desktop & Dock → scroll to *Default web browser* and open the dropdown. **Look only — do NOT select ActiveBrowser.** Selecting it is task 05. | **ActiveBrowser is listed exactly once**, and your current default is still **Arc**. Phase 3 Verify step 4. Two ActiveBrowser rows would mean this PR's fix regressed. Close the dropdown with Esc. |

**Reset after this block**
- **Do NOT run the teardown between tasks.** Tasks 05-08 all need the installed copy in `/Applications`. Run the teardown once, at the very end of the whole stack (last block in this file).
- **Default browser: nothing to restore.** This task never changes it; steps 1 and 14 assert Arc before and after.
- Note: `make install` now deletes `build/ActiveBrowser.app` as part of the fix. `make bundle` recreates it if you want it back.

---

## PR #<05> — Task 05: Set as Default Browser + routing (`feature/set-default-routing`, base `feature/make-install`)

**This is the one block that needs you before anything else can be verified.** Zero production code changed — the routing was shipped by tasks 02/04; this PR proves it.

Steps 1 and 3–8 already ran green (routing, LRU promotion, running-first-beats-LRU, relaunch-from-all-quit, empty-stack fallback, self-filtering, 7.6 MB footprint), exercised via `open -a ActiveBrowser <url>` which reaches the identical `application(_:open:)` entry point. Steps 9–15 are the same proofs through the real Launch Services handler and are recorded **not run — needs user step 2**.

| # | Action | Expected |
|---|---|---|
| 1 | **System Settings → Desktop & Dock → *Default web browser* → select `ActiveBrowser`.** macOS shows a confirmation dialog — accept it. | ActiveBrowser becomes the default. No Dock icon, no window appears. |
| 2 | Focus Brave, then switch to Terminal, then run `open https://example.com/u2` | Opens in **Brave**. |
| 3 | Focus Arc, then Terminal, `open https://example.com/u3` | Opens in **Arc**. |
| 4 | With Arc most recent, quit Arc, then `open https://example.com/u4` | Opens in **Brave** — the next most recently focused *running* browser. |
| 5 | Quit every browser, then `open https://example.com/u5` | A browser launches and opens the page — nothing is dropped. |
| 6 | Click a link inside a non-browser app (Slack, Mail, Notes) | Same routing as above. |
| 7 | Quit ActiveBrowser (`pkill -x ActiveBrowser`), then `open https://example.com/u7` | macOS relaunches ActiveBrowser and the link still opens — nothing dropped on cold start. |

**Reset after this block**
- **Restore your default browser: System Settings → Desktop & Dock → *Default web browser* → `Arc`.** Accept the dialog. This is mandatory.
- Relaunch any browser the steps quit (they restore their tabs) and close the `example.com/*` tabs the run created.
- **Leave `/Applications/ActiveBrowser.app` installed and running** — tasks 06–08 test against it. Do not run `make clean` or delete the defaults domain; the full teardown is the last block in this file.

---

## PR #<06> — Task 06: Launch at Login (`feature/launch-at-login`, base `feature/set-default-routing`)

All 7 `ai` steps pass. **This PR fixed a silent no-op**: `Project.md` §5's gate (`status != .notRegistered`) never fires on macOS 26, because `SMAppService` reports `.notFound(3)` when no login item has ever existed — so the app never registered itself. Verified after the fix: status moved `notFound(3)` → `enabled(1)`, and a `build/` copy correctly logs `skipped, bundle is not under /Applications`.

| # | Action | Expected |
|---|---|---|
| 1 | Open **System Settings → General → Login Items & Extensions** and look at the *Open at Login* list. | **ActiveBrowser** is listed, switch on. It may show as from an unidentified developer — expected for an ad-hoc-signed build, not a failure. Leave it as-is for now. |

**Reset after this block — read the ordering, it is not obvious**

This is the first task that creates state surviving a reboot. `make clean` does **not** remove a login item, and neither does quitting the app or deleting it from `/Applications`.

- **While you are still testing tasks 07–08** (which need the installed copy): switch the item **off** rather than removing it with `−`. An off switch leaves the status at `requiresApproval(2)`, which the gate deliberately never re-enables, so it stays off. A `−` removal resets the status to `notRegistered`/`notFound`, and the **next launch re-adds it**.
- **At the final teardown**, do it in this order: `pkill -x ActiveBrowser` → `rm -rf /Applications/ActiveBrowser.app` → *then* remove the entry with `−`. Removing it while the app is still installed is what lets it come back.
