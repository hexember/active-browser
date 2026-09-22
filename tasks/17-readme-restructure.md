# Task 17 — Restructure README for users; move contributor material to CONTRIBUTING

Status: pr-open
Phase: 6
Branch: chore/readme-restructure
Base: main
PR: https://github.com/hexember/active-browser/pull/29
Created: 2026-09-23

## Goal
Make `README.md` the single user-facing landing doc (why, install, use, privacy, limits, uninstall), with every claim checked against the current code. Move contributor-only material into `CONTRIBUTING.md` without duplicating anything and without losing any fact. Docs only: no Swift, `install.sh`, Makefile or workflow changes.

## Spec (planner)

Scope: `.md` files only: `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `CHANGELOG.md`, `assets/README.md`. These root docs already exist, so editing them does not trigger the guardrail §3 "outside §4" re-plan rule. `Project.md` needs **no** change, because §4 does not reference README sections (checked: its only README mention is `assets/README.md`, line 224).

### Fact-check results (planner verified these against the code on `main`; implementer applies them)
| # | README today | Code says | Source |
|---|---|---|---|
| F1 | "Click the globe icon" | The status item shows the bundled ActiveBrowser mark (browser window with a pointer, template image). The globe SF Symbol is only a fallback when `Contents/Resources` is missing (unbundled build). | `MenuBarManager.swift:61-65` |
| F2 | Menu mock-up: `Set as Default Browser` always shown; submenus drawn as `☑` / `● ○` | The row is **either** `Set as Default Browser` (clickable) **or** a checked, disabled `✓ Default Browser` when Launch Services resolves both `http` and `https` to ActiveBrowser. Both submenus use AppKit checkmarks (`✓`), with no radio glyphs. `Quit ActiveBrowser` has ⌘Q. Row order is otherwise correct. `Recent:` shows at most 3 names then ` › …`, and reads `Recent: none yet` when empty. `Routing to: none` when nothing resolves. | `MenuBarManager.swift:108-135, 199-229, 306-315` |
| F3 | "Untick the browser currently set as fallback and it moves to the next one" | It moves to the **first remaining ticked browser in menu order** (installed browsers by name, A→Z). | `MenuBarManager.swift:351-355, 263-267` |
| F4 | Unticked browser: "links will never go there" | This is not strictly true. The last-resort routing step is every installed handler by name, and it does **not** filter on `includedBrowsers`. An unticked browser can receive a link only when the focus history is empty **and** the fallback browser is gone from disk. | `URLDispatcher.swift:50-56` |
| F5 | Routing step 4 "the first browser it can find" | Precisely: the first installed `https` handler by display name, even an unticked one. Every candidate must exist on disk, and ActiveBrowser's own bundle id is dropped from every step (case-insensitive). | `URLDispatcher.swift:38-64` |
| F6 | "The last remaining ticked browser can't be unticked" | Correct. The row is disabled (greyed out), and the action re-checks the rule. Keep it. | `MenuBarManager.swift:185-194, 347` |
| F7 | (missing) *Browsers* contents | It lists every app registered to open `https` links, which can include non-browsers. Each app appears once. | `BrowserRegistry.swift`, `MenuBarManager.swift:241-244` |
| F8 | (missing) first-launch defaults | First launch ticks every detected browser and sets the fallback to the first one by name. | `AppDelegate.swift:88-93` |
| F9 | (missing) Launch at Login behaviour | The app registers itself as a login item on launch, but only when run from `/Applications/` and only if the user hasn't opted out. Unticking in the menu is remembered. A mixed (`–`) state means it was switched off in System Settings, and clicking the row then opens System Settings → Login Items. | `AppDelegate.swift:123-157`, `MenuBarManager.swift:319-325, 400-428` |
| F10 | (missing) focus history persistence | The *Recent* order lives only in memory. After relaunch or login it is empty, so links go to the Fallback Browser until a browser is focused. | `BrowserStack.swift` (no persistence) |
| F11 | "`http`/`https` only" | Schemes: correct. The app also declares itself a **low-priority** (`Alternate`) viewer for `.html`/`.xhtml` files, which macOS requires before it will list it as a browser. So it can appear in Finder's *Open With*, and any file it receives is routed the same way. | `Support/Info.plist:27-72`, `AppDelegate.swift:69-74` |
| F12 | Privacy (new) | No networking API anywhere in `Sources/`: no `URLSession`, `NWConnection`, `Network` or `CFNetwork`. `https://example.com` in the code is only a Launch Services lookup key and is never fetched (`BrowserRegistry.swift:17-20`, `MenuBarManager.swift:288`). No URL is ever logged. The only dispatch log line records a **count** (`URLDispatcher.swift:28`), and every other `NSLog` covers login-item or set-default errors. `UserDefaults` domain `com.local.activebrowser` holds exactly `includedBrowsers`, `defaultBrowser`, `launchAtLoginOptOut` (`Settings.swift:7-11`). | — |
| F13 | Installer network contact | The one-liner itself fetches `raw.githubusercontent.com`. The script calls `api.github.com` (latest tag, skipped when `ACTIVEBROWSER_VERSION` is set) and `github.com/hexember/active-browser/releases/…`, which redirects to GitHub's release-asset CDN. **Do not name the CDN host.** With `ACTIVEBROWSER_ZIP` it makes no network access at all. It never touches user defaults, login items or the default-browser binding, and never uses `sudo`. | `install.sh:5-8, 18-19, 129-155` |
| F14 | "`Project.md` ... departs from it in three places" | There are more than three. The code also differs from `Project.md` §5 in the status item (icon plus tooltip, not the target name as title), the `URLDispatcher` type the menu reads, and `Info.plist`'s HTML document types. The three named ones are still the ones most likely to be "restored" by mistake, so reword to "several places, notably these three"; where they disagree, the code is correct. | `Project.md` §5 vs `Sources/`, `Support/Info.plist` |
| F15 | Repository layout omits `assets/` and `.github/` | Both are real and shipped: `make bundle` copies `assets/AppIcon.icns` and `assets/menubar/*.png`, and the CI and release workflows live in `.github/workflows/`. | `Makefile:29-32` |
| F16 | `assets/README.md` "Not yet wired into the bundle" | Stale since task 12: the Makefile copies the icons, `Info.plist` sets `CFBundleIconFile`, and `MenuBarManager` loads the glyph. | `Makefile:26-33`, `Info.plist:13-14` |

Verified accurate and kept as written: the pitch, the install one-liner, the checksum and bundle validation, re-run as the upgrade path (the script `pkill`s first), macOS 13+, arm64 release builds with a clear refusal on Intel (`install.sh:193-198`), the Gatekeeper/quarantine explanation, the uninstall commands and `defaults` domain, the re-scan on menu open, settings persistence, and the never-dropped / logged / self-filtered claim.

### Checklist
- [x] **`README.md`**: rewrite into exactly this heading outline (fenced code excluded). Existing headings keep their exact text so their anchors survive:
  ```
  # ActiveBrowser
  ## Why this exists
  ## Install
  ### Build from source
  ## Using it
  ### How a URL is routed
  ## Privacy
  ## Known limitations
  ## Uninstall
  ## Contributing
  ## Changelog
  ## License
  ```
  - **Title block**: keep all four badges unchanged (the platform badge still links `#install`), plus the bold one-liner, the pitch paragraph, the Arc/Slack example block and the "never becomes the thing that displays a page" paragraph.
  - **Why this exists**: keep the comparison table unchanged. Tighten the two "when … is the better choice" paragraphs into two short bullets and keep the closing *where does this URL belong? / where am I working?* sentence. Every tool name and every claim in the table stays.
  - **Install**:
    - the one-liner;
    - the *Set as Default Browser* step, noting the row then reads *✓ Default Browser* (F2);
    - one paragraph on what the script does: checks, SHA-256, bundle validation before replacing anything, safe re-run as upgrade, no `sudo`, and no changes to settings, login items or default browser (F13);
    - one sentence that on first launch from `/Applications` the app adds itself as a login item so it is running before your first link click, with a pointer to *Using it* (F9);
    - the **Requirements** line (unchanged facts);
    - the Gatekeeper paragraph (unchanged facts) with a link to `SECURITY.md#what-youre-trusting-when-you-install-this`.
  - **Build from source**: the clone + `make install` block (these three command lines may also appear in CONTRIBUTING), a note that it needs a Swift 6 toolchain and works on Intel, and a link to `CONTRIBUTING.md#build-and-run`. Remove the `<details>` block, the local-zip install and the `ACTIVEBROWSER_*` variables (moved; see CONTRIBUTING item).
  - **Using it**:
    - "Click the ActiveBrowser icon in the menu bar", with no mention of a globe (F1). The tooltip shows `Routing to: …`.
    - A mock-up matching F2 exactly, in code order: `Routing to:` / `Recent:` / sep / `Browsers ▸` / `Fallback Browser ▸` / sep / `Set as Default Browser` (with an annotation that it becomes `✓ Default Browser`) / `Launch at Login` / sep / `Quit ActiveBrowser ⌘Q`. Submenu hints use `✓` only.
    - **Browsers** paragraph with the F4, F6 and F7 corrections.
    - **Fallback Browser** paragraph with the F3 correction.
    - A new **Launch at Login** paragraph (F9).
    - First-launch defaults (F8).
    - One line: "Runs as a background agent: no Dock icon, no windows, about 12 MB of memory idle." This is the only place README states the figure.
    - Keep "persist across restarts" and "re-scans each time you open it".
  - **How a URL is routed**: the four steps with the F5 wording on step 4. Keep the never-dropped / logged / self-filtered paragraph. Add F10 (history is empty after relaunch) and F11 (`.html` files) as one sentence each.
  - **Privacy** (new): short bullets with only F12/F13 facts. What it sees: every URL it is handed, plus which app is frontmost. What it does not do: no network requests of any kind, no telemetry, never writes URLs to disk or logs them. What it stores: the three keys, named, in `com.local.activebrowser`, all local. The focus order is kept in memory only. The installer's network contacts go in one sentence. **Must not** name a CDN host or claim anything not in F12/F13.
  - **Known limitations** (moved up, one line each, deduplicated):
    - Intel: released builds are arm64 only; build from source (link `#build-from-source`).
    - Not notarized: install with the one-liner or from source, because a browser-downloaded zip is quarantined (link `#install`, no re-explanation).
    - Routing ignores the URL: keep the link to `#why-this-exists`.
    - `http`/`https` only (plus the F11 `.html` note, if not already stated in routing; state it once).
    - Links go to the Fallback Browser until you focus a browser after launch (F10; state it once, either here or in routing).
  - **Uninstall** (promoted from `###` to `##`; anchor `#uninstall` unchanged). Same commands and facts, reordered so the default-browser reset comes **first**. That way a link clicked mid-uninstall cannot relaunch the app via Launch Services. After the reset: `pkill`, `rm -rf`, optional `defaults delete`, then Login Items removal. Keep the "order matters" sentence.
  - **Contributing**: one paragraph pointing to `CONTRIBUTING.md` for building, the macOS gotchas, architecture, design constraints, testing and releasing. Keep the Code of Conduct and SECURITY links.
  - **Changelog** and **License**: unchanged.
  - **Delete from README** (each item lands in CONTRIBUTING; see next item): the `## Development` section (dependency sentence, make block, bundle gotcha, `make run` gotcha, logging snippet), `### Architecture`, the design-constraints list, `### Testing`, `### Releasing`, `## Repository layout` including the history paragraph and the three deviations.
- [x] **`CONTRIBUTING.md`**: merge README's contributor material in with no duplicated text. Target outline:
  ```
  # Contributing
  ## Build and run
  ## Three things that will cost you an hour if nobody tells you
  ## Architecture
  ## Repository layout
  ## Project history
  ## Testing
  ## Design constraints
  ## Pull requests
  ## Releasing (maintainers)
  ### Testing a release locally
  ```
  - Keep the existing headings' exact text, because their anchors are linked from README.
  - *Build and run*: add "Swift plus Apple frameworks only (`AppKit`, `Foundation`, `ServiceManagement`)". Keep the existing make table as the only copy in the repo.
  - Gotcha 3: add that `make clean` **unregisters** and removes the build copy, and add this exact phrase: "`make install` and `make release` both delete `build/ActiveBrowser.app`".
  - *Architecture*: README's tree verbatim, with its per-file one-liners.
  - *Repository layout*: README's block plus `assets/` (icon artwork, see `assets/README.md`) and `.github/workflows/` (CI and release) (F15).
  - *Project history*: README's "history, not instructions" paragraph verbatim, except the deviation sentence reworded per F14. Keep the three named deviations (`@main` entry point, `install:` target ordering, `SMAppService` status gate) and "Don't 'restore' it to match the document". Mention that `tasks/TEST-PLAN.md` is the historical manual checklist (README's Testing section named it).
  - *Testing*: unchanged. README's Testing text is already covered here.
  - *Design constraints*: add the "~12 MB" idle figure to the background-agent bullet, e.g. "idle footprint ~12 MB; keep it under 25 MB".
  - *Releasing*: add that the workflow runs on `macos-latest` and verifies the artefacts before publishing. Keep the `v0.1.1` example and the asset-name contract.
  - *Testing a release locally*: `make release`, then `ACTIVEBROWSER_ZIP=build/ActiveBrowser.app.zip sh install.sh`. Explain that `ACTIVEBROWSER_SUMS` defaults to the `SHA256SUMS` next to the zip, that `ACTIVEBROWSER_ZIP` means no network access, and that `ACTIVEBROWSER_VERSION` pins a tag.
- [x] **`SECURITY.md`**: README *Privacy* becomes the single source for what the app sees and stores. Keep the `## What the app can see` heading so its anchor survives, and replace its body with a one-sentence pointer to `README.md#privacy`. First confirm every fact in the old body (3 bullets + stored-state sentence) is in README *Privacy*. The other SECURITY sections stay unchanged.
- [x] **`CHANGELOG.md`**: under `## [Unreleased]` → `### Changed`, add: "README reorganized for users, with a new Privacy section; contributor material (architecture, repository layout, releasing, local release testing) moved to `CONTRIBUTING.md`." Nothing else changes.
- [x] **`assets/README.md`**: replace the stale `## Not yet wired into the bundle` section with a short `## How the bundle uses these` section (F16). Say that `make bundle` copies `AppIcon.icns` and the three `MenuBarIconTemplate` PNGs into `Contents/Resources` before `codesign`, that `Info.plist` names `AppIcon`, and that `MenuBarManager` loads the glyph with a `globe` SF Symbol fallback. Keep the `isTemplate = true` sentence. Add "run from `assets/`" above the regeneration commands, because the paths are relative.

### Deliberately dropped (not carried anywhere)
- README Releasing example tag `v0.1.0`. It was an example value only, and CONTRIBUTING's `v0.1.1` example stays.
- The "Install from a local zip" framing as a user install route. The mechanism moves to CONTRIBUTING, because it exists for testing a release (`install.sh:26-28`).
- The `☑` / `●○` glyphs in the mock-up. They were wrong (F2).

Nothing else may be dropped. Anything the implementer wants to remove beyond this list goes into Implementation Notes with a reason.

Acceptance criteria:
- README and CONTRIBUTING heading outlines match the two outlines above exactly.
- Every fact in F1–F16 appears in the target file, and no stale claim remains (no "globe" in README, no "three places" without "notably", no "Not yet wired" in `assets/README.md`).
- The make targets table, the `make run` duplicate-registration gotcha, the logging snippet (`/tmp/ab.log`), the architecture tree, the history paragraph and the `ACTIVEBROWSER_*` variables each appear **only** in CONTRIBUTING.
- The privacy facts appear only in README (`SECURITY.md` points to them).
- Every relative link and `#anchor` in the five edited files resolves. README still links `#install` (badge) and `#why-this-exists`.
- The diff touches only `.md` files. `swift build` has no errors or warnings.

### Architectural notes and risks
- **Push-back 1 (SECURITY duplication):** the main session asked for a new README Privacy section but did not mention `SECURITY.md`, which already has the same facts under *What the app can see*. Two copies will drift, so README becomes canonical and SECURITY gets a pointer. If the user prefers SECURITY as canonical, reverse the pointer. Either way, keep only one copy.
- **Push-back 2 (~12 MB):** the idle memory figure matters to users, so it stays in README once (*Using it*). CONTRIBUTING gets it as a design constraint (under 25 MB, today ~12 MB). This is the one deliberate repeat of a number.
- **Push-back 3 (routing claim):** "links will never go there" is false in one edge case (F4). The docs are corrected here. Whether the last-resort step *should* respect `includedBrowsers` is a code question for a separate task, not this PR. The guardrail "never drop a URL" argues it is correct as is.
- **Push-back 4 (Project.md deviations):** "three places" is stale (F14), so it is reworded rather than moved verbatim.
- Removed README anchors (`#development`, `#architecture`, `#testing`, `#releasing`, `#repository-layout`) have no in-repo linkers (grepped). External deep links to them will land at the top of README. This is accepted.
- The System Settings default-browser picker route (task 11, `public.html` claim) is **not** documented in Install, because task 11's UI confirmation (its user step 12) is still unrecorded. The menu route stays the only documented one. The uninstall text already points to Desktop & Dock for resetting.
- Out-of-scope finding for a follow-up task: `Support/Info.plist` `CFBundleShortVersionString` is `1.0.0` while releases are tagged `v0.1.x`, so `install.sh` prints "Installing ActiveBrowser 1.0.0". This is not fixed here (not `.md`).
- Out of scope: `Project.md` §4 lists only `release.yml` (not `ci.yml`) and no root docs. It is history per README, so it is left alone.

## Implementation Notes (implementer)
Built (only `.md` files changed: `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `CHANGELOG.md`, `assets/README.md`):
- **README**: rewritten to the exact 12-heading outline. Title block, badges and comparison table are unchanged. The two "better choice" paragraphs are now two bullets that keep every tool and claim. Install covers the one-liner, the Set as Default Browser → `✓ Default Browser` step, the script paragraph (F13), the login-item sentence (F9), Requirements, and Gatekeeper with a SECURITY anchor link. Build from source has the clone/`make install` block, a Swift 6 + Intel note, and a CONTRIBUTING link. Using it has the icon (no globe), the tooltip, the F2 mock-up, and the Browsers (F4/F6/F7), Fallback (F3), Launch at Login (F9), first-launch (F8) and ~12 MB paragraphs. Routing has step 4 per F5, the on-disk rule, and F10 + F11 once each. Privacy uses only F12/F13 and names no CDN host. Known limitations has 5 one-liners. Uninstall is `##` with the default-browser reset first. Contributing, Changelog and License follow.
- **CONTRIBUTING**: target outline exactly. Added the frameworks sentence, the gotcha-3 `make clean` unregister wording and the exact "both delete" phrase, the Architecture tree verbatim, the Repository layout with `assets/` and `.github/workflows/`, Project history (verbatim apart from the F14 rewording "several places, notably three…; where the two disagree, the code is correct", plus a `tasks/TEST-PLAN.md` mention), the ~12 MB / 25 MB constraint, `macos-latest` + verify-before-publish in Releasing, and *Testing a release locally* with all three `ACTIVEBROWSER_*` variables (checked against `install.sh:16-24`).
- **SECURITY**: `## What the app can see` kept, body replaced with a pointer to `README.md#privacy`. Every old fact is in README Privacy first: sees every URL, observes focus, no network requests, no URLs written to disk or logged, no URL-content matching, and the three stored keys.
- **CHANGELOG**: one bullet added under `[Unreleased]` → `### Changed` (text as specified, wrapped to the file's width).
- **assets/README**: `Not yet wired` section replaced by `## How the bundle uses these` (F16). Kept the `isTemplate = true` sentence and added "Run these from `assets/`" above the regeneration block.

Decisions / small deviations:
- The old mock-up annotation for Fallback Browser ("used when nothing is running") was wrong. When nothing is running, step 2 picks the most recently focused browser (`BrowserStack.swift:38`). It now reads "used before you've focused a browser". This is not on the dropped list; it is a correction.
- Mock-up names use the registry display names (`Brave Browser`, not `Brave`), matching what `recentLine()` and the submenus render. Unchecked fallback rows show no glyph, the same as AppKit.
- CONTRIBUTING Design constraints: shortened the "No third-party dependencies" bullet to the bold phrase alone, because the "Swift plus Apple frameworks only" text now lives in *Build and run*. Keeping both would repeat the same text.
- CONTRIBUTING make table: the `make release` row now says `build/ActiveBrowser.app.zip`, carrying over the path from README's removed make block (`Makefile:61-63`).
- Gotcha 3 was rewrapped so "two ActiveBrowser rows" sits on one line (Test Step 3 greps for it).
- README Install says the script "quits the running app first", from `install.sh:236` (`pkill`), which is the fact behind "safe to run with the app open".
- F13's local-zip no-network fact appears in README as "Installing from a local zip makes no network access at all", without naming the variable (Test Step 2 requires `ACTIVEBROWSER_*` = 0 in README).
- No fact was dropped beyond the Spec's list. Self-check of Test Step 10 found none.

Self-check of `ai` steps 1-10 (the main session still records the official Actual/Result): 1 both outlines match the Spec exactly · 2 CONTRIBUTING ≥1 and README 0 for every string (README has "about 12 MB") · 3 README 0 / CONTRIBUTING ≥1 for all 7 · 4 network requests README 1 / SECURITY 0, key and domain present, pointer at SECURITY.md:35, CDN count 0 · 5 every menu label ≥1, globe 0, glyphs 0, Not yet wired 0, no "three places" line · 6 `broken: 0`, `(#install)` 2, `(#why-this-exists)` 1 · 7 count 1, no removed lines in CHANGELOG · 8 only the five `.md` files plus the untracked task file.

Build: `swift build` clean (no warnings or errors; `Build complete!`) · `make bundle` n/a (docs-only change; not run so that no `build/` copy gets registered with Launch Services, per the task's "System state: unchanged" precondition)

## Review (code-reviewer)
Verdict: APPROVED
- Scope: `git status` shows only the five `.md` files plus this task file. `swift build` ran clean (no warnings or errors, `Build complete!`). I did not run `make bundle`: no source, `Support/` or Makefile input changed, so the bundle is identical to `main`'s, and building it would leave a `build/` copy that Launch Services registers, which breaks the "System state: unchanged" precondition. This is a deliberate skip.
- Fact-check against the code (all pass). Icon and globe fallback (`MenuBarManager.swift:61-65`). Tooltip text (`:101-103`). Menu rows, order, ⌘Q, and the disabled `✓ Default Browser` row (`:111-134`). `Recent:` cap, ` › …` and `none yet` (`:306-315`). `Routing to: none` (`:302`). Last ticked browser row disabled, and the action re-checks it (`:185-193, 347`). Unticking prunes the stack (`:350`). Fallback moves to the first ticked browser in menu order (`:351-355, 263-267`). Launch-at-Login states, including `.mixed` → dash → opens System Settings (`:319-325, 417-421`). Opt-out remembered (`AppDelegate.swift:127`). `/Applications` gate (`:125`). First-launch seeding (`:88-93`). The routing chain and last-resort registry step (`URLDispatcher.swift:38-64`). On-disk check (`:41-42`). Case-insensitive self-filter (`:58-60`). Only NSLog on dispatch logs a count (`:28`). No networking API in `Sources/` (grepped). The three keys and the domain (`Settings.swift:7-11`, `Info.plist:6`). `.html`/`.xhtml` declared as `Alternate` viewer (`Info.plist:46-72`). Files are routed through the same dispatcher (`AppDelegate.swift:69-74`). Installer facts: `install.sh:72, 81-84, 136, 142-153, 164-198, 236, 252`, no `sudo`, and the `latest/download` fallback is still under `github.com/hexember/active-browser/releases`. No CDN host is named.
- Content preservation: every removed README line is present in CONTRIBUTING, README-elsewhere, or on the dropped list. The only losses are the `v0.1.0` example and the local-zip framing, both on the dropped list. I checked the old SECURITY body (4 facts) against README *Privacy*: all four are there.
- Duplication: the `make run` gotcha, `/tmp/ab.log`, `log show`, `git tag`, `No polling`, the architecture tree and `ACTIVEBROWSER_*` each appear only in CONTRIBUTING (grepped: README 0). The `/tmp/ab.log` count of 2 comes from one snippet. The overlaps that remain are allowed by the Spec: the clone block, the ~12 MB figure, and README's Gatekeeper paragraph linking to SECURITY's longer version.
- Links: LINKCHECK `broken: 0`. Both outlines match the Spec exactly. The only inbound README anchor in the repo is `SECURITY.md:35` → `#privacy`, and it resolves. `#install` (badge + limitations), `#why-this-exists`, `#build-from-source` and `#using-it` resolve.
- Implementer deviations: all four are accepted. (1) The mock-up annotation "used before you've focused a browser" is correct, and the old "when nothing is running" was wrong per `BrowserStack.swift:38`. (2) `Brave Browser` matches the registry display names. (3) Shortening the CONTRIBUTING dependency bullet avoids repeating the new *Build and run* sentence. (4) The `build/ActiveBrowser.app.zip` path in the make table matches `Makefile:61`.
- Non-blocking nit: `README.md` (Browsers paragraph), the F4 exception says "if your focus history is empty". Precisely, the exception applies when no browser in the history *and* not the Fallback Browser is still on disk. The stack is not pruned when an app is deleted (`BrowserStack.prune` runs only on untick/bootstrap). This is harmless because the Spec's F4 uses the same simplification. Optional wording: "if none of your recent browsers nor your Fallback Browser is still installed".
- Non-blocking nit: `README.md` (Install), the script paragraph says it "never touches … your login items". The very next paragraph says the app adds a login item on its first launch, and the script performs that launch (`install.sh:252`). Both statements are literally true and adjacent, so a reader is unlikely to be misled. Optional: "the script itself never touches …".
- Non-blocking nit: `README.md` (How a URL is routed), "A URL is never dropped … it's logged rather than silently discarded" reads as self-contradictory to a first-time user. The Spec keeps this sentence verbatim, so leave it for now.
- Test Steps: all `ai` steps 1-10 can be run against the files as written. I ran 1, 3, 6, 8 and 9 (outline, dedup and scope greps, LINKCHECK, build) and all passed. User steps 11-12 can be satisfied: the badge → `#install`, the in-page links resolve, the mock-up matches the code's menu, and SECURITY's pointer lands on README *Privacy*.

## Test Steps (planner writes; `ai` rows run by the main session before the PR opens, `user` rows by the human at the PR)

**Preconditions**
- Build: none needed. This is a docs-only change and nothing is installed. All commands run from the repo root on branch `chore/readme-restructure`.
- System state: unchanged.
- Covers: task-specific (no `Project.md` §3 Verify block applies to documentation).
- `OUTLINE` below means: `awk '/^```/{f=!f;next} !f && /^#/' <file>` (headings outside fenced code).
- `LINKCHECK` below means: save this script as `<scratchpad>/linkcheck.py` and run `python3 <scratchpad>/linkcheck.py`:
  ```python
  import re, os, sys
  FILES = ["README.md", "CONTRIBUTING.md", "SECURITY.md", "CHANGELOG.md", "assets/README.md"]
  def slugs(path):
      out, seen, fence = set(), {}, False
      for line in open(path, encoding="utf-8"):
          if line.startswith("```"): fence = not fence; continue
          m = None if fence else re.match(r"^#{1,6}\s+(.*?)\s*#*\s*$", line)
          if m:
              s = re.sub(r"[^\w\- ]", "", m.group(1).strip().lower()).replace(" ", "-")
              n = seen.get(s, 0); seen[s] = n + 1
              out.add(s if n == 0 else f"{s}-{n}")
      return out
  bad = 0
  for f in FILES:
      text = re.sub(r"```.*?```", "", open(f, encoding="utf-8").read(), flags=re.S)
      for t in re.findall(r"\]\(([^)\s]+)\)", text):
          if re.match(r"(https?|mailto):", t): continue
          path, _, anchor = t.partition("#")
          target = os.path.normpath(os.path.join(os.path.dirname(f), path)) if path else f
          if not os.path.exists(target): print(f"{f}: missing file -> {t}"); bad += 1; continue
          if anchor and target.endswith(".md") and anchor not in slugs(target):
              print(f"{f}: missing anchor -> {t}"); bad += 1
  print("broken:", bad); sys.exit(1 if bad else 0)
  ```

| # | Who | Action (exact command / click) | Expected | Actual | Result |
|---|---|---|---|---|---|
| 1 | ai | `git show main:README.md > <scratchpad>/README.before.md; git show main:CONTRIBUTING.md > <scratchpad>/CONTRIBUTING.before.md`, then `diff <(OUTLINE on before) <(OUTLINE README.md)` and the same for CONTRIBUTING | After-outlines equal the two outlines in the Spec exactly. The diff shows only the planned additions/removals: README loses `Development`, `Architecture`, `Testing`, `Releasing`, `Repository layout` and the `<details>` other-ways block; `Uninstall` goes from `###` to `##`; `Privacy` and `### Build from source` are added. | outlines match Spec exactly; diff shows only the planned changes | pass |
| 2 | ai | Moved-fact presence. For each string, `grep -cF '<s>' CONTRIBUTING.md` and `grep -cF '<s>' README.md`: `AppDelegate.swift`, `FocusObserver.swift`, `BrowserRegistry.swift`, `BrowserStack.swift`, `Settings.swift`, `URLDispatcher.swift`, `MenuBarManager.swift`, `history, not instructions`, `` `@main` entry point ``, `` `install:` target ordering ``, `` `SMAppService` status gate ``, `tasks/TEST-PLAN.md`, `ACTIVEBROWSER_ZIP`, `ACTIVEBROWSER_SUMS`, `ACTIVEBROWSER_VERSION`, `macos-latest`, `` `make install` and `make release` both delete `build/ActiveBrowser.app` ``, `ServiceManagement`, `~12 MB`, `Support/`, `assets/`, `docs/`, `.github/workflows` | CONTRIBUTING ≥ 1 for every string. README = 0 for every string except `~12 MB`/`12 MB` (README ≥ 1 by design, push-back 2). | CONTRIBUTING ≥1 for all 23; README 0 for all except the idle figure, written as "about 12 MB" (README:97) | pass |
| 3 | ai | Zero-duplication. `grep -c` in README.md and CONTRIBUTING.md for: `` | `make run` ``, `/tmp/ab.log`, `two ActiveBrowser rows`, `log show`, `is \`nil\` outside a bundle`, `git tag`, `No polling` | README = 0 and CONTRIBUTING ≥ 1 for each. | README 0 / CONTRIBUTING ≥1 for all 7 | pass |
| 4 | ai | Privacy single-sourced: `grep -c 'network requests' README.md SECURITY.md`; `grep -c 'launchAtLoginOptOut' README.md`; `grep -c 'com.local.activebrowser' README.md`; `grep -n 'README.md#privacy' SECURITY.md`; `grep -Ec 'objects\.githubusercontent|release-assets' README.md` | README ≥ 1 and SECURITY = 0 for "network requests". Key and domain present in README. SECURITY has the pointer. No CDN host named (last count 0). | README 1 / SECURITY 0; key 1; domain 2; pointer at SECURITY:35; CDN 0 | pass |
| 5 | ai | Fact-check. For each of `Routing to:`, `Recent:`, `Browsers`, `Fallback Browser`, `Set as Default Browser`, `Default Browser`, `Launch at Login`, `Quit ActiveBrowser`, run `grep -cF` in README.md. Also run `grep -ci globe README.md`, `grep -c '☑\|●\|○' README.md`, `grep -c 'Not yet wired' assets/README.md`, `grep -n 'three places' CONTRIBUTING.md` | Each menu label ≥ 1 (labels match `MenuBarManager.swift` titles). `globe` = 0. Glyph count = 0. `Not yet wired` = 0. Any "three places" line also says "notably". | all labels ≥1; globe 0; glyphs 0; Not yet wired 0; no "three places" line | pass |
| 6 | ai | `python3 <scratchpad>/linkcheck.py` (LINKCHECK), then `grep -c '(#install)' README.md` and `grep -c '(#why-this-exists)' README.md` | `broken: 0`, exit 0. Both anchor counts ≥ 1. | `broken: 0`, exit 0; #install 2; #why-this-exists 1 | pass |
| 7 | ai | `awk '/^## \[Unreleased\]/,/^## \[0.1.0\]/' CHANGELOG.md \| grep -c 'README reorganized'` | `1`. `git diff main -- CHANGELOG.md` shows only added lines. | `1`; no removed lines | pass |
| 8 | ai | `git diff --name-only main` plus `git status --porcelain` | Only `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `CHANGELOG.md`, `assets/README.md`, `tasks/17-readme-restructure.md` (and `tasks/TEST-PLAN.md` if updated). All end in `.md`. `install.sh`, `Sources/`, `Makefile`, `.github/`, `Project.md` untouched. | only the 5 .md files + untracked task file | pass |
| 9 | ai | `swift build 2>&1 \| grep -E 'warning:\|error:'; swift build 2>&1 \| tail -1` | First command prints nothing. Last line is `Build complete!` | only the 2 CommandLineTools `ld` search-path lines (known noise); `Build complete!` | pass |
| 10 | ai | Spec "Deliberately dropped" audit: open `git diff main -- README.md`, and for every removed line containing a fact, confirm it is in CONTRIBUTING/SECURITY/README-elsewhere or on the dropped list | No unlisted fact lost. List any exception in Implementation Notes. | reviewer's line-by-line audit + steps 2–4 greps: no unlisted fact lost | pass |
| 11 | user | On the GitHub PR, open *Files changed* → `README.md` → *Display the rendered blob*. Read top to bottom, click the platform badge and the *Why this exists* / *Build from source* / *Install* links. | The page reads as a user landing doc. The badge jumps to *Install*. All in-page links land on the right heading. The menu mock-up matches what you see when you click the menu bar icon (with the `✓ Default Browser` row if ActiveBrowser is your default). No developer-only sections remain. | | pass / fail |
| 12 | user | Same for `CONTRIBUTING.md` and `SECURITY.md` (rendered) | CONTRIBUTING reads in order: build → gotchas → architecture → layout → history → testing → constraints → PRs → releasing. Nothing is said twice. SECURITY's *What the app can see* link opens README *Privacy*. | | pass / fail |

**Reset after testing**
- none (docs only; scratchpad files are disposable)

**Result (ai rows):** pass — 2026-09-23 (steps 1–10, run by main session after the post-review wording fixes)
**Result (user rows):** <recorded at the PR by the user>
Failures: <step # — what happened — link to follow-up task, or "none">

## Next
Follow-up candidates found while planning (separate tasks, not this PR): align `CFBundleShortVersionString` (`1.0.0`) with release tags (`v0.1.x`); decide whether routing's last-resort step should skip unticked browsers (F4); once task 11's picker step is confirmed, document the System Settings route in README *Install*.

_2026-09-23 (main session, after APPROVED):_ I applied the reviewer's three wording nits in `README.md`. Install now says "The script itself never uses `sudo`…". The Browsers exception now reads "none of the browsers in your focus history is still installed". The first sentence of the routing section is reworded so "never dropped" doesn't contradict "logged". No facts changed. I re-ran the ai steps after the edits.

_2026-09-23 (main session, follow-up commit on PR #29 at the user's request):_ Added a one-line **Contents** nav under the pitch, linking Why, Install, Using it, Privacy, Limitations, Uninstall, Contributing and Source on GitHub. Also added a "Source code, issues and releases" repo link under Contributing. README is also rendered on GitHub Pages, and the Pages site has neither GitHub's outline button nor a way back to the repo. The two `LICENSE` links (badge and License section) are now absolute GitHub URLs, because Jekyll's relative-link rewriting only handles `.md` files and `LICENSE` would not resolve on the site. Link check: `broken: 0`. Outline unchanged, so step 1 still passes.
