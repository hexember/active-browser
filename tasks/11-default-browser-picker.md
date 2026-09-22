# Task 11 — List ActiveBrowser in the System Settings default-browser picker

Status: in-review
Phase: 4
Branch: fix/default-browser-listing
Base: main
PR: https://github.com/hexember/active-browser/pull/19 (reopened)
Created: 2026-09-22

## Goal
Make ActiveBrowser appear in System Settings → Desktop & Dock → *Default web browser*. It
was absent because the bundle never claimed an HTML content type, so Launch Services never
granted it the per-bundle `web-browser` flag that the picker filters on.

## Spec (planner)
- [x] `Support/Info.plist` — declare `CFBundleDocumentTypes` for `public.html` and
      `public.xhtml`, role `Viewer`, **`LSHandlerRank: Alternate`** (one UTI per dict,
      matching Arc and Brave).
- [x] `Sources/ActiveBrowser/App/AppDelegate.swift` — implement
      `application(_:openFiles:)` forwarding through the existing `URLDispatcher`, so an
      HTML file opened with ActiveBrowser is not a silent no-op.

Acceptance criteria:
- `lsregister -dump` shows `more flags: web-browser` on the installed bundle.
- `-[LSApplicationRecord isEligibleWebBrowser]` is `YES` for `com.local.activebrowser`.
- The default handler for `public.html` is **unchanged** (must not be hijacked).
- URL routing and the 25 MB footprint guardrail still hold.

## Implementation Notes (implementer)

Revives PR #19, which had the correct diagnosis but shipped `LSHandlerRank: None`.
`None` means "never opens this type" and fails the very check it was trying to satisfy —
the registration predicate tests the HTML claim against `kLSOpenRoleMask`, and
`kLSRolesNone` is excluded from it. `Alternate` is the lowest rank that still counts and
keeps ActiveBrowser below every real browser for actual `.html` files.

Root cause established by disassembly of LaunchServices on macOS 26.6.2:

- `-[LSApplicationRecord isEligibleWebBrowser]` →
  `BindingEvaluator::IsBundleWithFlagsEligibleToBindAsBrowser`, which is
  `and w0, w1, #0x1` — one bit of `LSBundleMoreFlags`. `bundleFlags` and
  `profileValidationState` are passed and discarded. **No signature check.**
- That bit is set at registration by `BundleIsWebBrowserCandidate`, a three-way AND over
  `_LSCanBundleHandleNodeOrSchemeOrUTI`: scheme, scheme, and `kUTTypeHTML`.

The earlier "notarized Developer ID is required" conclusion is refuted: VLC and cmux are
both notarized Developer ID apps that claim `http`+`https`, and both are excluded because
neither claims HTML. ActiveBrowser now qualifies while still **ad-hoc signed**.

Dropped from PR #19 as disproven-irrelevant: `NSUserActivityTypes`, `NSPrincipalClass`,
`CFBundleInfoDictionaryVersion`, `CFBundleDevelopmentRegion`, `CFBundleSupportedPlatforms`.
None appear in the predicate; keeping them would add unexplained surface.

Build: `swift build -c release` clean, no project warnings · `make bundle` ok

## Review (code-reviewer)
Verdict: pending

## Test Steps

**Preconditions**
- `make install` completed on this branch; testing the `/Applications` copy.
- System state: Arc and Brave running, Safari not; default browser Arc; ad-hoc signature.

| # | Who | Action | Expected | Actual | Result |
|---|---|---|---|---|---|
| 1 | ai | `swift build -c release` | clean, no project warnings | Build complete, 0 errors, 0 project warnings | **PASS** |
| 2 | ai | `plutil -lint Support/Info.plist` | OK | `OK` | **PASS** |
| 3 | ai | `make install` | exit 0, app running from `/Applications` | exit 0, pid 66307, `LSBundlePath=/Applications/ActiveBrowser.app`, `ApplicationType=UIElement` | **PASS** |
| 4 | ai | `lsregister -dump`, find our record | `more flags: web-browser` present | `more flags: web-browser`; `claimed UTIs: public.html, public.xhtml, com.apple.default-app.web-browser`; `claimed schemes: http:, https:` | **PASS** |
| 5 | ai | `-[LSApplicationRecord isEligibleWebBrowser]` for our bundle id | `YES` | `com.local.activebrowser isWebBrowser=YES isEligibleWebBrowser=YES` — while ad-hoc signed, `spctl: rejected` | **PASS** |
| 6 | ai | Count `com.local.activebrowser` LS records | exactly 1 | `1` | **PASS** |
| 7 | ai | `LSCopyDefaultRoleHandlerForContentType("public.html")` | unchanged (Arc) | `company.thebrowser.Browser` — `Alternate` did not hijack the HTML default | **PASS** |
| 8 | ai | Default `https` handler unchanged | Arc | `Arc.app` | **PASS** |
| 9 | ai | Focus Brave, `open -b com.local.activebrowser https://example.com/...` | URL opens in Brave | Brave tab count 11 → 12, URL present | **PASS** |
| 10 | ai | Focus Brave, `open -b com.local.activebrowser <file>.html` | file opens in Brave via `openFiles` | `file:///.../routing-test.html` present in Brave; log shows `CFURLResolveBookmarkData` → `LAUNCH: Asking CSUI to launch 1 items` | **PASS** |
| 11 | ai | `footprint -p $(pgrep -x ActiveBrowser)` | < 25 MB | `phys_footprint: 11 MB` | **PASS** |
| 12 | user | System Settings → Desktop & Dock → *Default web browser* → open the dropdown | **ActiveBrowser is listed.** Current default stays Arc unless you pick it | | pass / fail |
| 13 | user | Select ActiveBrowser in that dropdown, accept the macOS confirmation | ActiveBrowser becomes default; links route to your last-focused browser | | pass / fail |

Step 12 could not be run by the main session: `osascript` has no Accessibility grant
(`osascript is not allowed assistive access`) and `screencapture` has no Screen Recording
grant, so neither the AX tree nor a screenshot of the dropdown is obtainable here. Step 5
is the exact predicate System Settings filters on, but it is a *programmatic* reading, not
the UI itself — the distinction that this whole issue turned on, so step 12 stays `user`.

**Reset after testing**
- If step 13 was run: System Settings → Desktop & Dock → *Default web browser* → **Arc**.
- Test tabs were opened in Brave (`example.com/...`, one `file://` tab) — close at will.

**Result (ai rows):** 11 of 11 pass — 2026-09-22
**Result (user rows):** recorded at the PR
Failures: none

## Next
If step 12 passes, `tasks/TEST-PLAN.md` and `README.md` need the *opposite* correction to
the one in PR #21 — the System Settings route works after all. PR #21 must not merge as
written; it documents notarization as the cause and recommends a $99/year membership that
would not have fixed this.
