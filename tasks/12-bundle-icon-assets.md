# Task 12 — Wire the icon assets into the app bundle

Status: in-review
Phase: 3 (amends the Phase 3 bundle spec)
Branch: feature/bundle-icon-assets
Base: main (#19 and #20 both merged 2026-09-22 while this task was in review)
PR: (filled by git-agent)
Created: 2026-09-22

## Goal
Make the ActiveBrowser icon and menu bar glyph actually visible to users. PR #20 added the
artwork but deliberately wired none of it: `Support/Info.plist` had no `CFBundleIconFile`,
`make bundle` created no `Contents/Resources/`, and `MenuBarManager` drew the system
`globe` SF Symbol. This task connects all three.

## Spec (planner)
- [x] `Support/Info.plist` — `CFBundleIconFile` = `AppIcon`.
- [x] `Makefile` — `bundle:` creates `Contents/Resources/`, copies `AppIcon.icns` and the
      three `MenuBarIconTemplate` PNGs **before** `codesign`.
- [x] `Sources/ActiveBrowser/UI/MenuBarManager.swift` — prefer the bundled template image,
      fall back to the `globe` SF Symbol when `Contents/Resources` is absent.
- [x] `Project.md` — amend the Phase 3 spec, the §4 tree, the §5 `Info.plist` block and the
      §5 Makefile skeleton, which all previously mandated **no** icon and **no** `Resources/`.

Acceptance criteria:
- `find build/ActiveBrowser.app -type f` lists the four new resources.
- `codesign --verify --strict` exits 0, and the resources are sealed in `CodeResources`.
- `NSWorkspace.icon(forFile:)` on the bundle differs from the generic application icon.
- The bundled glyph resolves at 18×18pt with 18/36/54px representations.

## Implementation Notes (implementer)

**Ordering is the load-bearing detail.** The ad-hoc signature seals `Contents/Resources`
into `_CodeSignature/CodeResources`, so every resource must be copied *before* `codesign`.
A resource added afterwards leaves `codesign --verify --strict` failing and macOS refusing
to launch the bundle — verified here by a deliberate tamper test, below.

`CFBundleIconFile` is set to `AppIcon`, without the extension: it is a resource *name* and
Launch Services appends `.icns` itself.

The menu bar glyph is loaded with `NSImage(named: "MenuBarIconTemplate")`, which resolves
the `@2x`/`@3x` siblings into one 18×18pt multi-representation image. The `globe` fallback
is kept deliberately — `NSImage(named:)` returns nil for any build whose `Resources` was not
assembled by `make bundle`, and a status item with neither image nor title is zero-width and
unclickable, i.e. an app the user cannot quit.

`isTemplate` is set explicitly even though AppKit already infers it from the `Template`
filename suffix; the explicit line survives a rename.

**Spec change.** `Project.md` previously specified the bundle as exactly `MacOS/` +
`Info.plist`, with the Makefile skeleton carrying no `Resources/` step. Guardrail §3 (*No
Orphan Implementations*) requires the spec to move first, so all four places were amended
in this commit rather than left to drift.

Build: `swift build -c release` clean, no project warnings · `make bundle` ok

## Review (code-reviewer)
Verdict: **APPROVED** — 2026-09-22

Reviewer rebuilt, re-bundled and independently reproduced steps 1, 3, 4, 7, 8, 9, and
additionally verified: template artwork is pure black with shape carried by alpha
(`maxRGB=0.00`, `nonBlackVisible=0`), so it tints correctly in dark mode and under
highlight; `make release` → extract → all three `install.sh` gates pass
(`com.local.activebrowser`, `arm64`, strict codesign) with `SHA256SUMS` verifying; XML
comments in `Info.plist` do not break `plutil -extract`; `release.yml` needs no change
because it calls `make release`. No concurrency or lifetime issue — the new lines sit in
`init` of a `@MainActor final class` with no closure, capture or stored state.

Four non-blocking findings; two applied in this branch:
- `MenuBarManager.swift:54` — `bundled?.accessibilityDescription` mutated the process-wide
  `NSImage` name cache and was superseded at runtime by `refresh()`'s
  `setAccessibilityLabel`. **Applied:** line removed, rationale left as a comment.
- `Project.md` §4 — the `assets/` node listed only the files consumed by `make bundle`,
  omitting the SVG sources, README and `tools/render.swift` that PR #20 also tracks. §4 is
  what guardrail §1's Re-Plan Trigger keys on. **Applied:** node completed.
- `Makefile:29-32` — the `cp`s are unguarded, so `make bundle` fails hard if the artwork is
  missing. Correct failure mode, but it makes merge order load-bearing: **this PR must not
  be retargeted to `main` before #20 merges.** No code change.
- `assets/menubar/MenuBarIconTemplate.png` (1x) — only 30 of 324 pixels are fully opaque;
  the 18px strokes are largely antialiasing. Irrelevant on Retina (the `@2x` rep is used),
  but the mark may read faint on a 1x external display. Folded into user step 10.

## Test Steps

**Preconditions**
- Branch `feature/bundle-icon-assets`, rebased onto `main` after #19 and #20 merged.
- `make install` run; steps 13–16 test the `/Applications` copy.

| # | Who | Action | Expected | Actual | Result |
|---|---|---|---|---|---|
| 1 | ai | `swift build -c release` | clean, no project warnings | `Build complete!`, 0 errors, 0 project warnings | **PASS** |
| 2 | ai | `plutil -lint Support/Info.plist` | OK | `OK`; `CFBundleIconFile` → `AppIcon` | **PASS** |
| 3 | ai | `make bundle`, then `find build/ActiveBrowser.app -type f` | 7 files: binary, Info.plist, CodeResources, 4 resources | exactly those 7 | **PASS** |
| 4 | ai | `codesign --verify --strict build/ActiveBrowser.app` | exit 0 | `valid on disk`, `satisfies its Designated Requirement`, exit 0 | **PASS** |
| 5 | ai | Resource names present in `CodeResources` | all 4 sealed | `Resources/AppIcon.icns`, `MenuBarIconTemplate{,@2x,@3x}.png` | **PASS** |
| 6 | ai | **Tamper test** — append a byte to a sealed PNG, re-verify, restore | verify fails while tampered, passes after restore | `a sealed resource is missing or invalid`; clean after restore | **PASS** |
| 7 | ai | `NSWorkspace.icon(forFile:)` on the bundle | custom icon, not the generic one | reps 16→2048; `differs from generic app icon: true` | **PASS** |
| 8 | ai | Resolve `MenuBarIconTemplate` from the built bundle | 18×18pt, 3 reps, template | `18x18` pt, reps `18, 36, 54` px, `isTemplate: true` | **PASS** |
| 9 | ai | `assets/AppIcon.icns` completeness (`iconutil -c iconset`) | 16→512@2x present | all 10 variants (16,32,128,256,512 @1x+@2x) | **PASS** |
| 10 | user | After this and #19/#20 merge, reinstall and look at the **menu bar** | The ActiveBrowser mark, not a globe. Tints correctly in light/dark and when the menu is open. *If you have a non-Retina external display, check there too — the 1x PNG is mostly antialiasing and may read faint* | | pass / fail |
| 11 | user | Finder → `/Applications`, look at ActiveBrowser | The custom app icon, not a generic one | | pass / fail |
| 12 | user | System Settings → Desktop & Dock → *Default web browser*, and General → Login Items | ActiveBrowser shows its icon in both lists | | pass / fail |

Steps 1–9 ran against `build/ActiveBrowser.app` before #19/#20 merged, to avoid replacing
the working `/Applications` copy with one that would have dropped out of the
default-browser picker. Once both merged, the branch was rebased onto `main` — the two
`Info.plist` edits sit in different regions and the rebase was conflict-free — and steps
13–16 re-ran the same checks against the real installed copy, which now carries **both**
#19's `CFBundleDocumentTypes` and this task's `CFBundleIconFile`.

| # | Who | Action | Expected | Actual | Result |
|---|---|---|---|---|---|
| 13 | ai | `make install`, then `find /Applications/ActiveBrowser.app -type f` | 7 files incl. the 4 resources | exactly those 7 | **PASS** |
| 14 | ai | `codesign --verify --strict` on the installed copy | exit 0 | `strict OK` | **PASS** |
| 15 | ai | Picker eligibility + LS hygiene after the icon change | `isEligibleWebBrowser=YES`, exactly 1 record | `isWebBrowser=YES isEligibleWebBrowser=YES`; record count `1`; `more flags: web-browser` on `/Applications/ActiveBrowser.app` | **PASS** |
| 16 | ai | Icon + glyph on the installed copy; footprint; `ApplicationType` | custom icon, 18pt glyph, <25 MB, UIElement | `differs from generic: true`; glyph `18x18` pt / reps `18,36,54` / `isTemplate: true`; `phys_footprint: 11 MB`; `"UIElement"` | **PASS** |

Adding `Contents/Resources` does not disturb the default-browser registration: the
`web-browser` flag and the single Launch Services record both survived the reinstall.

**Reset after testing**
- `make clean` removes `build/` and unregisters it. Nothing else to restore.

**Result (ai rows):** 13 of 13 pass — 2026-09-22
**Result (user rows):** recorded at the PR
Failures: none

## Next
Merge-order question is moot: #19 and #20 both merged on 2026-09-22, this branch is rebased
onto `main`, and the PR targets `main` directly.

Outstanding: #19 changed `Support/Info.plist` without amending `Project.md`'s §5 key list,
which still reads "no `CFBundleDocumentTypes`" — a guardrail §3 (*No Orphan
Implementations*) gap now on `main`. Worth a small follow-up task; deliberately not fixed
here, since silently editing another task's spec line is the kind of drive-by this project's
rules exist to prevent.
