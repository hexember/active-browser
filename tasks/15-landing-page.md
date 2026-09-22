# Task 15 — Landing page on GitHub Pages

Status: pr-open
Phase: 6
Branch: feature/landing-page
Base: main
PR: https://github.com/hexember/active-browser/pull/28
Created: 2026-09-23

## Goal
Publish a dependency-free landing page, which also works with JavaScript off, at the default GitHub Pages URL **https://hexember.github.io/active-browser/** (no custom domain). The page explains why ActiveBrowser exists, how it routes links, how to install and uninstall it, and what it does with your data. Everywhere on the page, the install command is main's canonical one-liner. The app icon is copied in from `assets/` at deploy time, so `assets/` stays the only copy.

## Spec (planner)

> **2026-09-23 (planner, re-plan).** The first version of this task targeted `https://activebrowser.app` and stacked on task 14 (custom domain, `pages.yml`, `install.sh` served from Pages). Task 14 was merged as PR #25 and then reverted by PR #26. Task 16 / PR #27 replaced it and only renamed the owner to `hexember`, with "no custom domain, no Pages site". `tasks/14-*` no longer exists on `main`. The branch was rebuilt from `main` (378d49a), and `Project.md`, `README.md` and `CHANGELOG.md` are back to main's versions, so the draft's edits to them are gone. The user has now decided that the site ships on **https://hexember.github.io/active-browser/** with no custom domain, and that `install.sh` is **not** served from Pages: the only advertised install URL is the raw.githubusercontent one-liner. `site/{index.html,style.css,copy.js}` and `.github/workflows/pages.yml` were carried over, untracked, from the reviewed draft. The items below adapt them. The old item 8 (a note in task 14) is dropped, because that file no longer exists.

Scope: Phase 6 (distribution), website only. No Swift, `Support/`, `Makefile`, `Package.swift`, `install.sh`, `ci.yml` or `release.yml` changes.

**Content rule.** Every factual claim on the page must trace to `README.md`, `Project.md`, `install.sh` or `Sources/`. Item 3 lists the facts the planner checked against those sources. Add nothing else: no feature claims, no benchmark numbers, no exact text of the macOS dialog, and no "Open Anyway" instructions.

**Canonical strings** (use them verbatim):
- Site URL: `https://hexember.github.io/active-browser/` (always with the trailing slash).
- One-liner: `curl -fsSL https://raw.githubusercontent.com/hexember/active-browser/main/install.sh | sh`
- The string `activebrowser.app` (lowercase, i.e. the domain) must not appear anywhere in the tree except in this task file's superseded history. `ActiveBrowser.app`, the bundle name, is fine.

1. [x] **`Project.md`** (do this first, because it clears the §4 re-plan trigger for `site/` and `pages.yml`)
   - §3 split table: after row 10, add `| 15 | 6 | Landing page on GitHub Pages: `site/{index.html,style.css,copy.js}`, `.github/workflows/pages.yml` (icon copied from `assets/` at deploy time) | page renders under `/active-browser/`, copy button works |`.
   - §3 Phase 6: add a bullet after the Homebrew Cask bullet:
     *"GitHub Pages (landing page): `.github/workflows/pages.yml` publishes `site/` to https://hexember.github.io/active-browser/ on pushes to `main` that touch `site/**`, `assets/icon.svg`, `assets/icon-1024.png` or the workflow, and on manual dispatch. There is no custom domain. One-time setup, before the first deploy: repo Settings → Pages → Build and deployment → Source: **GitHub Actions**. At deploy time the workflow copies `assets/icon.svg` → `icon.svg` and `assets/icon-1024.png` → `icon.png` into the artifact. The build fails if `site/` contains `icon.svg`, `icon.png`, `install.sh` or `CNAME`. `install.sh` is deliberately not served from Pages, so the raw.githubusercontent one-liner stays the only advertised install URL."*
   - Phase 6 Verify: add step 8: `for p in "" style.css copy.js icon.svg icon.png; do curl -fsS -o /dev/null -w "%{http_code} /$p\n" https://hexember.github.io/active-browser/$p; done; curl -s -o /dev/null -w "%{http_code} install.sh\n" https://hexember.github.io/active-browser/install.sh`. Expected: `200` on the five page lines and `404 install.sh`.
   - §4 tree: after the `release.yml` line, add `├── .github/workflows/pages.yml      # Phase 6: publishes site/ to GitHub Pages`. After the `install.sh` line, add `├── site/{index.html,style.css,copy.js}  # Phase 6 landing page; icon copied in at deploy time`. Keep the column alignment of the surrounding lines.
2. [x] **`.github/workflows/pages.yml`** (carried over; adapt it)
   - Header comment, rewritten:
     - The workflow publishes the landing page to https://hexember.github.io/active-browser/, and there is no custom domain.
     - The Pages source must be set to "GitHub Actions" in repo Settings.
     - `install.sh` is not served from Pages; the one-liner fetches it from raw.githubusercontent.com on `main`, so there is exactly one advertised URL.
     - `assets/icon.svg` and `assets/icon-1024.png` are the single source and are copied in at deploy time.
     - Only GitHub's first-party `actions/*` are used.
   - `on.push`: `branches: [main]`, with `paths` exactly `'site/**'`, `'assets/icon.svg'`, `'assets/icon-1024.png'` and `'.github/workflows/pages.yml'`. Remove `'install.sh'`. Keep `workflow_dispatch`.
   - `permissions` (`contents: read`, `pages: write`, `id-token: write`), `concurrency` (`group: pages`, `cancel-in-progress: false`) and the `deploy` job are unchanged.
   - Every `uses:` is an `actions/*` action. Keep the reviewed pins: `checkout@v4`, `configure-pages@v5`, `upload-pages-artifact@v3` and `deploy-pages@v4`. Do not pass `enablement:` to `configure-pages`, because the default `GITHUB_TOKEN` cannot enable Pages; that is a user step.
   - The assemble step is named "Assemble site with a deploy-time copy of the icon". Its `run:` is exactly:
     ```
     set -euo pipefail
     for f in icon.svg icon.png; do
       if [ -e "site/$f" ]; then echo "::error::site/$f must not be committed; it is copied from assets/ at deploy time" >&2; exit 1; fi
     done
     for f in install.sh CNAME; do
       if [ -e "site/$f" ]; then echo "::error::site/$f must not be published; the only install URL is raw.githubusercontent.com and there is no custom domain" >&2; exit 1; fi
     done
     mkdir _site && cp -R site/. _site/
     cp assets/icon.svg _site/icon.svg
     cp assets/icon-1024.png _site/icon.png
     cmp assets/icon.svg _site/icon.svg
     cmp assets/icon-1024.png _site/icon.png
     ```
     Each `cmp` sits on its own line, so `set -e` catches every mismatch. There is no `cp install.sh` line.
3. [x] **`site/index.html`** (carried over; adapt it). HTML5, `lang="en"`, UTF-8. No inline `<style>`, no `style=` attributes and no inline `<script>`, so the CSP stays strict.
   - **Subpath rule.** Every local reference is relative, with no leading `/`: `style.css`, `copy.js`, `icon.svg`, `icon.png` and `#…` anchors. This lets the page work at `/active-browser/`. The only absolute URLs are `https://hexember.github.io/active-browser/…` (canonical and OG) and `https://github.com/hexember/active-browser…` (links).
   - `<head>`:
     - Viewport, `<meta name="color-scheme" content="light dark">`, and the title "ActiveBrowser: open links in the browser you're using".
     - `<meta name="description">`: README line 8.
     - CSP meta, unchanged: `default-src 'none'; style-src 'self'; script-src 'self'; img-src 'self'; base-uri 'none'; form-action 'none'`.
     - `<link rel="canonical" href="https://hexember.github.io/active-browser/">`, the stylesheet, the SVG and PNG icons and the apple-touch-icon, all unchanged and relative.
     - Open Graph: `og:title`, `og:description`, `og:type=website`, `og:url` = `https://hexember.github.io/active-browser/` and `og:image` = `https://hexember.github.io/active-browser/icon.png`. Also `twitter:card=summary`.
     - `<script src="copy.js" defer></script>` is the only script.
   - Landmarks are unchanged:
     - A skip link to `#main`, visible on focus.
     - `<header><nav>` with the links Why, How it works, Install, Uninstall and FAQ.
     - `<main id="main">` with sections `#top`, `#why`, `#how`, `#install`, `#uninstall` and `#faq`. The hero's `<h1>` is the only h1. Each other section has an `<h2>`, and install subsections use `<h3>`.
     - `<footer>`.
   - **Hero** (`#top`):
     - The icon `<img src="icon.svg" alt="ActiveBrowser app icon" width="96" height="96">`, the `<h1>` and the lead sentence, all unchanged.
     - `<pre><code id="install-cmd">curl -fsSL https://raw.githubusercontent.com/hexember/active-browser/main/install.sh | sh</code></pre>`, then the `hidden` Copy button and the `role="status"` span, unchanged.
     - The repo and `/releases/latest` links.
     - The line "macOS 13 or later · Apple silicon · MIT licensed".
   - **Why**, **How it works**, **Uninstall**: keep the reviewed content unchanged. The facts it rests on:
     - The routing chain: README "How a URL is routed".
     - Never dropped and never routed to itself: README and guardrails.
     - 25 MB cap: guardrails. About 12 MB: README.
     - Login item on first launch from `/Applications`, with the opt-out: `AppDelegate`.
     - Only Apple frameworks: README "Development".
     - The Uninstall block: README lines 80–88, verbatim.
   - **Install** (`#install`):
     - (a) "Run this in Terminal:" followed by the one-liner above, verbatim, as plain text. The copy button stays in the hero only.
     - (b) "What the script does": keep the five bullets and the "changes nothing else … Running it again is the upgrade path" line unchanged.
     - (c) **Delete** the "If activebrowser.app is unreachable" `<h3>` and its `<pre>`. The page has no fallback or alternative one-liner, and no wording that suggests one.
     - (d) Manual download, (e) Build from source (Intel Macs must use this route, because released builds are arm64-only), and (f) the Final step: all unchanged.
   - **FAQ**:
     - Keep the other four entries.
     - Adapt the privacy answer's last sentence. The one-liner now also contacts `raw.githubusercontent.com`. Suggested wording: "Only installing goes online: the one-liner fetches `install.sh` from `raw.githubusercontent.com`, and the script downloads the release from GitHub (`api.github.com`, `github.com`, and GitHub's release-download host)."
     - "What does this site collect?": "Nothing. No cookies, no analytics, no third-party requests." This stays true on github.io: the page loads only same-origin files, and it is the CSP that makes this so.
   - **Footer**: unchanged (LICENSE, source and releases links).
4. [x] **`site/style.css`** (carried over). No change is expected. Re-verify that it:
   - is the only stylesheet;
   - has no `@import`, `@font-face`, `url(` or `http`, and uses system fonts only;
   - puts colours in `:root` custom properties, with a `prefers-color-scheme: dark` override, and contrast of at least 4.5:1 in both schemes;
   - has `:focus-visible` on links, buttons and summaries, and a skip link hidden until it is focused;
   - uses a column of about 44rem, with no horizontal scroll at 360px (`pre { overflow-x: auto }`; the raw one-liner is longer than the old one, so the check matters more now);
   - has `[hidden] { display: none !important; }` and a reduced-motion rule.
5. [x] **`site/copy.js`** (carried over). No change is expected. Re-verify that it:
   - un-hides `#copy-btn` on `DOMContentLoaded`;
   - copies `#install-cmd`'s `textContent` with `navigator.clipboard.writeText`, showing "Copied";
   - on failure, uses a `Range` select and shows "Press ⌘C to copy", and clears the status after about 2 s;
   - uses no `fetch`, `XMLHttpRequest`, `sendBeacon`, `import`, `eval` or storage APIs, and contains no URLs.
6. [x] **`README.md`**
   - Under the bold tagline (line 8), add a blank line and then `Website: [hexember.github.io/active-browser](https://hexember.github.io/active-browser/)`.
   - In "Repository layout", add `site/             the landing page (GitHub Pages)`, aligned with the other rows.
7. [x] **`CHANGELOG.md`**: under `[Unreleased]` → `### Added`, as the first bullet: "Landing page at https://hexember.github.io/active-browser/ (install, how it works, uninstall, privacy), published from `site/` by a GitHub Pages workflow." Leave the other sections untouched.

Acceptance criteria:
- `git ls-files site` (after staging) lists exactly `site/copy.js`, `site/index.html` and `site/style.css`. There is no `site/install.sh`, `site/icon.svg`, `site/icon.png` or `site/CNAME`.
- Running the `pages.yml` assemble script, extracted from the YAML, produces `_site` with exactly `copy.js icon.png icon.svg index.html style.css`, and both `cmp` lines are silent. Each of the four guarded files, placed in `site/`, makes the script exit 1 with `::error::`.
- `pages.yml` path triggers are exactly the four listed above, every `uses:` starts with `actions/`, and it has no `cname`/custom-domain setting and no `install.sh` copy.
- `index.html` has:
  - no inline style or script, and one `<script>` (`src="copy.js"`);
  - no `src`/`href` starting with `/`;
  - absolute URLs only under `https://hexember.github.io/active-browser/` or `https://github.com/hexember/active-browser`;
  - the canonical one-liner exactly twice (the hero and Install), and no other `…install.sh` URL.
- Served from a simulated `/active-browser/` subdirectory, the page and every relative reference in it return 200, and `/active-browser/install.sh` returns 404.
- `git grep --untracked -F 'activebrowser.app' -- ':!tasks/15-landing-page.md'` prints nothing.
- The page has `header`/`nav`/`main`/`footer`, exactly one `h1`, `alt` on every `img`, a meta description, the `og:*` tags, `color-scheme` and a dark-scheme block. Every claim traces to a source. The page says "Apple silicon" and never claims Intel release support.
- `swift build` is clean. Nothing changes under `Sources`, `Support`, `Makefile`, `Package.swift`, `install.sh`, `ci.yml` or `release.yml` relative to `main`.
- Project.md (split row, Pages bullet, Verify 8, both §4 lines), README (website link and layout line) and CHANGELOG (Added entry) match items 1, 6 and 7.

Architectural notes and risks:
- **One advertised install URL.** Serving `install.sh` from Pages would create a second URL. It could lag `main` (deploys are path-triggered and can fail), and it would need its own guard and diff checks. The guard on `site/install.sh` enforces the decision rather than just documenting it. Removing `install.sh` from the path triggers is correct: the site no longer depends on it.
- **CNAME guard.** Actions-deployed Pages ignores `site/CNAME`, but a committed one would suggest a custom domain that doesn't exist, so the guard keeps "no custom domain" explicit. A custom domain can still be set in Settings → Pages, which no file check can catch. User step 15 confirms that the field is empty.
- **Subpath.** A project site is served under `/active-browser/`. Relative references resolve correctly only when the page URL ends in `/`. GitHub Pages 301-redirects `/active-browser` to `/active-browser/`, as `python3 -m http.server` does, and step 8 checks both. Any root-absolute path (`/style.css`) would 404 on github.io while working on a local root server; step 5 bans them and step 8 serves under the subpath to prove it.
- **Enable Pages before merge.** `actions/configure-pages` fails ("Get Pages site failed") if Pages is not enabled with Source = GitHub Actions. The default `GITHUB_TOKEN` cannot enable it, so user step 15 must happen before merging, or the first run fails. It can be re-run with `workflow_dispatch` afterwards.
- **Account-level custom domain.** If `hexember` ever sets a custom domain on a `hexember.github.io` user site, every project site redirects to that domain, and the canonical and OG URLs here would become redirects. This is out of scope; it is noted so a future domain change is planned as its own task.
- **Clipboard.** `navigator.clipboard` needs a secure context. `https://hexember.github.io` and `http://127.0.0.1` both qualify, and `file://` falls back to the `Range` select.
- **xmllint and HTML5.** macOS `xmllint --html` (HTML4 parser) reports `Tag header/nav/main/section/footer/details/summary invalid` for valid HTML5. Step 6 filters out exactly those messages.
- **Apple silicon wording.** `install.sh` accepts `x86_64`, but the released zip is arm64-only, so `lipo` refuses it on Intel (README "Known limitations"). The page says "Apple silicon" and sends Intel users to build from source.
- **Action pins.** `upload-pages-artifact@v4` exists, but its only relevant change is excluding dotfiles, and `site/` has none. The reviewed `@v3` is kept to avoid an unrelated change. A bump belongs in its own task.
- **Stale task statuses.** Several older task files still show `pr-open`/`in-review`, but their code is on `main`. None of them touches `site/` or `pages.yml`, so there is no overlap.
- No guardrail is touched. The zero-dependency rule is honoured on the site, and CI uses only first-party `actions/*`. Item 1 adds the new paths to §4 before any file is created there.

## Implementation Notes (implementer)

> **2026-09-23 (planner): SUPERSEDED.** The notes below describe the `activebrowser.app` draft built on top of task 14, which has since been reverted. They are kept as history. The implementer replaces them with notes for the re-planned spec above; the carried-over `site/*` and `pages.yml` are the starting point.

Built (items 1–8, in spec order, Project.md first):
- `Project.md`: split-table row 15, GitHub Pages bullet extended (icon copies + guard), Phase 6 Verify step 9, §4 tree line replaced.
- `site/index.html`: rewritten per item 2. No inline style/script; the only script is `<script src="copy.js" defer>`; strict CSP meta; canonical, SVG + PNG icons, apple-touch-icon, og:* and twitter:card. Landmarks are the skip link, header/nav, `main#main` with sections `#top` (h1), `#why`, `#how`, `#install`, `#uninstall` and `#faq` (each h2), and footer. Install subsections use h3. The Uninstall block is the README text verbatim.
- `site/style.css`: `:root` custom properties with the suggested palette and a `prefers-color-scheme: dark` override; `:focus-visible` outlines on a/button/summary; the skip link sits off-screen until `:focus`; the column is 44rem; `pre { overflow-x: auto }`; `[hidden]` rule; reduced-motion removes the single button transition. System fonts only; no `url(`/`@import`/`@font-face`/`http`.
- `site/copy.js`: 33 lines. On DOMContentLoaded it un-hides the button. The click handler uses `navigator.clipboard.writeText` and shows "Copied". On rejection or a missing clipboard, it Range-selects the `<code>` and shows "Press ⌘C to copy". The status clears after 2 s. No network or storage APIs.
- `pages.yml`: two `assets/` paths added, the assemble step replaced verbatim with the spec script and renamed, and the header comment extended to the icon. Triggers, permissions, concurrency and jobs are unchanged.
- README (website link and layout line; the layout column is padded to align with the other rows), CHANGELOG `[Unreleased] → Added` entry, and the dated note appended under task 14 `## Next` (nothing else in task 14 touched).

Deviations / decisions:
- **Privacy FAQ wording.** The spec says "stores only your browser choices". `Settings.swift` also persists `launchAtLoginOptOut`, so the page says "only your menu choices (included browsers, Fallback Browser, and a Launch at Login opt-out)". Everything else in that answer is as specified.
- The footer "releases link" points to `/releases`, and the hero points to `/releases/latest`. Both are under `github.com/hexember/active-browser`.
- The spec text for (b)–(e) was lightly worded into sentences, with no added claims. `assets/icon.svg` was checked: it uses only internal `url(#…)` refs, so it is safe under `img-src 'self'`.

Self-check of the `ai` steps (for the main session to re-run):
- 1: `ls -A site` = `copy.js index.html style.css`, no BAD. `git ls-files site` shows only `index.html` until the new files are committed (per instructions, nothing is committed).
- 2, 3, 4, 5, 7, 9, 10, 12: pass as written. Step 3 listing is exactly `copy.js icon.png icon.svg index.html install.sh style.css`, with no cmp output; step 4 gives `::error::` and `exit=1` for all three files.
- **6: the Test Step filter is incomplete.** libxml2's HTML4 parser also reports `Tag details invalid` / `Tag summary invalid`, and the spec requires those elements for the FAQ. With `details|summary` added to the filter, the output is empty. The page is correct; step 6's regex needs those two tags.
- **8: port 8765 is taken on this machine** by an unrelated process (`Kiro H…`, pid 23893), so the command as written gets 404s from it. On port 8766 every line is 200 with the expected types (`text/html`, `text/css`, `text/javascript`, `image/svg+xml`, `image/png`), and the last line is `same`. User steps 13–18 will hit the same conflict; use another port.
- **11: `git diff --stat main... -- … install.sh` is not empty.** It shows `install.sh | 4 ++--`, which comes from the base branch's task 14 commit 25c03b5, not from this task. `git diff --stat chore/hexember-domain-install -- Sources Support Makefile Package.swift install.sh` is empty. It becomes empty against `main` once PR #25 merges.

Build: `swift build` clean (Build complete, no errors or warnings) · `make bundle` ok (codesign succeeded; no app changes in this task)

> **2026-09-23 (implementer, re-planned spec).** This entry replaces the superseded notes above.

Built (items 1–7, in spec order, Project.md first):
- `Project.md`: added split row 15 after row 10, the GitHub Pages bullet after the Homebrew Cask bullet, Phase 6 Verify step 8, and both §4 tree lines (`site/…` after `install.sh`, `pages.yml` after `release.yml`). All text is verbatim from item 1.
- `.github/workflows/pages.yml`: rewrote the header comment to cover the five points in item 2. `paths` are now exactly `site/**`, `assets/icon.svg`, `assets/icon-1024.png` and `.github/workflows/pages.yml`, with `install.sh` removed. The assemble step is renamed, and its `run:` is the item 2 script verbatim: two guard loops, no `cp install.sh`, and each `cmp` on its own line. `permissions`, `concurrency`, the action pins and the `deploy` job are unchanged, and there is no `enablement:`.
- `site/index.html`: canonical, `og:url` and `og:image` now point at `https://hexember.github.io/active-browser/…`. Both one-liners (the hero `#install-cmd` and Install) are the canonical raw.githubusercontent one. The "If activebrowser.app is unreachable" `<h3>` and its `<pre>` are deleted. The privacy answer's last sentence now uses the suggested wording, which names `raw.githubusercontent.com`. Everything else is unchanged from the reviewed draft.
- `site/style.css` and `site/copy.js`: re-verified against items 4 and 5, with no changes.
- `README.md`: the Website line under the tagline, and `site/` in Repository layout, aligned with the other rows. `CHANGELOG.md`: `[Unreleased]` had no `### Added` heading, so I created one above `### Changed`, in Keep a Changelog order, with the entry as its only bullet. The other sections are untouched.

Decisions / deviations:
- None against the spec. The §4 `site/{index.html,style.css,copy.js}` path is longer than the comment column, so its comment cannot line up with the others. I used the spec's literal text (two spaces before `#`).
- Claim re-trace after the task 16 rename: the bundle id `com.local.activebrowser` and the `http`/`https` schemes are in `Support/Info.plist`. `api.github.com`, `releases/latest/download`, `SHA256SUMS`, `lipo`, `pkill` and `/Applications` are in `install.sh`. The `launchAtLoginOptOut` key is in `Settings.swift`, and "~12 MB" is in README line 172. The Uninstall block matches README lines 80–88.

Self-check of the `ai` steps (staged with `git add site .github/workflows/pages.yml`, not committed):
- 1: both listings are exactly `copy.js index.html style.css`, with no BAD line. Pass.
- 2: branches `["main"]`, the four paths exactly, `true`, and the expected permissions and concurrency. All four `uses` are `actions/*`. `cmp` count `2`, forbidden-pattern count `0`. Pass.
- 3: `exit=0`, no `cmp` output. The listing is `copy.js icon.png icon.svg index.html style.css`. Pass.
- 4: each of `icon.svg`, `icon.png`, `install.sh` and `CNAME` gives the expected `::error::` text and `exit=1`. Pass.
- 5: absolute URLs are only under `hexember.github.io/active-browser/` and `github.com/hexember/active-browser`. The counts are 0 / 0 / 1 (`<script src="copy.js" defer></script>`) / 0 / 0. Pass.
- 6: no output. Pass.
- 7: `2`, the `install-cmd` line is canonical, one URL, `0`, `1`. Pass.
- 8: on port 57208 (free), `/active-browser` gives 301 → `/active-browser/`. All page lines are 200 with `text/html`, `text/css`, `text/javascript`, `image/svg+xml` and `image/png`. The refs `copy.js`, `icon.png`, `icon.svg` and `style.css` are all 200, and the last line is `404 install.sh`. Pass.
- 9: no MISSING line. h1 `1`, alt-less imgs `0`, dark `1`, focus-visible `3`. Pass.
- 10: no networking symbols. The only NSLog is the URL **count** line in `URLDispatcher.swift:28`. Then `0`, `1`, `3`. Pass.
- 11: no matches, `exit=1`. Pass.
- 12: `swift build` gives "Build complete!". The only `warning:` lines are the two CommandLineTools `ld` search-path lines, which the step says to ignore. The diff and status outputs for Sources, Support, Makefile, Package.swift, install.sh, ci.yml and release.yml are empty. The `main...` form still needs to run after the commit. Pass.
- 13: all eight greps print a line. Pass.
- 14: `200`. Pass.

Build: `swift build` clean (Build complete; only the CommandLineTools ld search-path noise) · `make bundle` ok (`codesign --force --sign -` succeeded; no app changes in this task)

## Review (code-reviewer)

> **2026-09-23 (planner): SUPERSEDED.** This review approved the `activebrowser.app` draft, which has since been reverted along with task 14. It does not cover the re-planned spec. A fresh review is required. Two of its advisories are already built into the new spec: `cmp` lines on separate lines (item 2) and the third GitHub host in the privacy answer (item 3).

Verdict: APPROVED
- Checked independently on 2026-09-23. `swift build` is clean and `make bundle` succeeds (codesign ok). Ran ai steps 2–12 myself and all pass. Step 3 lists exactly `copy.js icon.png icon.svg index.html install.sh style.css` with no `cmp` output. Step 4 exits 1 with `::error::` for each of the three files. Step 6 prints nothing, using the amended filter. Step 8 used a free port (56884): every line is 200 with the expected types, and the last line is `same`. Step 11 against `chore/hexember-domain-install...` is empty. I also ran one extra check: a forced icon mismatch makes the assemble script exit 1, so the `cmp` chain does fail the build.
- Step 1: `git ls-files site` shows only `site/index.html` because `style.css` and `copy.js` are still untracked. This is expected before the commit. The main session must re-run step 1 after `git add` and before the PR opens; it cannot pass until then.
- Claim trace: every page claim maps to a source.
  - Why section: README §Why this exists.
  - Routing chain and "never dropped / never routed to itself": README §How a URL is routed.
  - 25 MB cap: guardrails. ~12 MB: README §Architecture.
  - Login item on first launch from `/Applications` and the opt-out: `AppDelegate.registerLoginItemIfInstalled`.
  - Install-script bullets and "changes nothing else": `install.sh` lines 1–8 and 64–255.
  - Apple silicon and the Intel route: README lines 57 and 237.
  - Uninstall block: README lines 84–92, verbatim.
  - Scheme answer: `Support/Info.plist` `CFBundleURLSchemes` = http, https.
  - "No networking code": step 10 grep is empty. The only URL-related `NSLog` logs a count.
  - The implementer's broader "menu choices … Launch at Login opt-out" wording matches `Settings.swift` more closely than the spec text. Accepted.
- site/index.html:123 (advisory, not blocking; the wording is what the spec asked for). "Only the installer goes online, to `api.github.com` and `github.com`" is incomplete. `install.sh` fetches `github.com/…/releases/download/…` with `curl -L`, which GitHub redirects to its release-asset CDN host (`*.githubusercontent.com`). A firewall-conscious reader would see a third host. Suggested follow-up: "to GitHub (`api.github.com`, `github.com` and GitHub's release-download host)".
- .github/workflows/pages.yml:55 (advisory). The single `cmp … && cmp … && cmp …` line only fails the step because it is the script's last command: `set -e` ignores failures in non-final members of an `&&` list. It works today, and I verified this. If a line is ever appended after it, a mismatch would pass silently. Suggested hardening, in a later task: three separate `cmp` lines.
- site/index.html:135 (acceptable). "Other schemes are left to the system" goes slightly beyond the spec's "Only http/https are handled". It is true by `Info.plist`, so no change is needed.
- CSP, isolation and accessibility checks pass:
  - The CSP meta comes before every subresource.
  - There is no inline style or script, and the only script is `copy.js`.
  - `style.css` and `copy.js` make no external or network references.
  - `assets/icon.svg` uses only internal `url(#…)` references, so it is safe under `img-src 'self'`.
  - With JS off, the button stays `hidden`, backed by the `[hidden]{display:none !important}` rule.
  - The skip link sits off-screen until it is focused.
  - `:focus-visible` covers a, button and summary. Reduced motion removes the only transition.
  - Palette contrast is ≥ 4.5:1 in both schemes: light link #0066cc on #fff ≈ 5.6:1, dark muted #a1a1a6 on #1d1d1f ≈ 7:1.
  - At 360px the content box is about 320px, the longest inline `<code>` (`/Applications/ActiveBrowser.app`) is about 285px, and `pre` has `overflow-x: auto`, so there should be no horizontal page scroll. User step 15 confirms this visually.
- Docs:
  - Project.md: split row 15, Pages bullet, Verify 9 and the §4 tree line all match item 1.
  - README: website link and layout line.
  - CHANGELOG: the entry is under `[Unreleased] → Added`.
  - Task 14: only a dated note was appended under `## Next`. Its other sections are untouched.
- Guardrails: no Swift, `Support/`, `Makefile`, `Package.swift` or `install.sh` change, and no third-party resources. `pages.yml` triggers, permissions, concurrency and jobs are unchanged apart from the two `assets/` paths.
- Test Steps: all ai steps can run against the code as written, with step 1 passing once the new files are staged. User steps 13–19 are consistent with the code: the copy button, the JS-off state, the focus rings, the dark scheme and the live curl loop all have backing code or config.

> **2026-09-23 (code-reviewer, re-planned spec).** Fresh review of the github.io spec. It replaces the superseded review above.

Verdict: APPROVED
- Independent run on 2026-09-23 of the staged `site/*` and `pages.yml` and the unstaged `Project.md`/`README.md`/`CHANGELOG.md` edits. `swift build` gives "Build complete!" with no `error:`/`warning:` lines. `make bundle` succeeds (codesign ok). No app code changed.
- ai steps I ran myself, all passing: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 (working-tree forms), 13 and 14.
  - Step 1: `git ls-files site` and `ls -A site` both list exactly `copy.js index.html style.css`, with no BAD line.
  - Step 2: the paths are exactly the four specified, and the four `uses` are the `actions/*` pins. `cmp` count is 2 and the forbidden-pattern count is 0.
  - Steps 3 and 4: `exit=0`, and `_site` holds exactly `copy.js icon.png icon.svg index.html style.css`. All four guards print the correct `::error::` text and exit 1.
  - Extra check: I forced the **first** `cmp` to mismatch, and the script exits 1. This proves the separate-line fix works (the old `&&` chain would have passed silently here).
  - Step 8: served on a free port under `/active-browser/`. The bare path returns 301 to `/active-browser/`. All page lines and refs return 200 with the correct MIME types, and `/active-browser/install.sh` returns 404.
  - Step 11: `git grep --untracked` finds no `activebrowser.app` outside this file (`exit=1`). A case-insensitive pass finds only the bundle name `ActiveBrowser.app`.
  - Step 14: the one-liner URL returns 200.
- `pages.yml` matches item 2 exactly: the header comment covers all five points, the triggers are right, `permissions`/`concurrency`/`deploy` are unchanged, and there is no `enablement:`, `cname` or `cp install.sh`. The `run:` block is the spec script verbatim.
- Subpath: every local `src`/`href` is relative (0 root-absolute). All absolute URLs are under `https://hexember.github.io/active-browser/` or `https://github.com/hexember/active-browser`.
- CSP and isolation:
  - The CSP meta comes before every subresource. There is no inline style or script, and the only `<script>` is `copy.js` (deferred).
  - `style.css` and `copy.js` contain no URLs, imports, fonts, network calls or storage calls.
  - `assets/icon.svg` references only internal `url(#…)` IDs.
- JS-off: the button is `hidden` in the markup and backed by `[hidden]{display:none !important}`. `details`/`summary` and the anchors need no JS.
- Accessibility and dark mode: skip link, landmarks, one h1, alt text, `:focus-visible` on a/button/summary, reduced motion, and a dark-scheme block. The palette clears 4.5:1 in both schemes.
- At 360px, `pre` scrolls on its own (`overflow-x: auto`) and the nav wraps. User step 18 confirms this visually.
- Claim trace: every claim maps to a source.
  - Why section and routing: README lines 31–37 and "How a URL is routed".
  - 25 MB: guardrails. ~12 MB: README line 174.
  - Apple silicon / Intel via source: README lines 55 and 235.
  - Login item gate and opt-out: `AppDelegate.registerLoginItemIfInstalled`.
  - Script bullets: `install.sh` lines 64–244 (sw_vers, uname, `-w /Applications`, the api.github.com → `releases/latest/download` fallback, SHA256SUMS, the plutil bundle-id and lipo checks, pkill, ditto, lsregister).
  - Uninstall block: README lines 82–90, verbatim.
  - Schemes: `Support/Info.plist`.
  - The privacy answer uses item 3's suggested wording, including `raw.githubusercontent.com` and the release-download host.
  - The fallback/"unreachable" block is gone.
- Docs:
  - Project.md: row 15, the Pages bullet, Verify 8 and both §4 lines are verbatim from item 1.
  - README: the Website line under the tagline, and `site/` in the layout, aligned.
  - CHANGELOG: `### Added` is created above `### Changed` under `[Unreleased]`, with the item 7 text.
- Guardrails: nothing changed under `Sources`, `Support`, `Makefile`, `Package.swift`, `install.sh`, `ci.yml` or `release.yml` (the diff and status are empty). There are no third-party resources, and CI uses only first-party `actions/*`.
- Project.md:218 (advisory, not blocking). The `site/{…}` comment sits two columns right of the tree's comment column. This is unavoidable given the path length and the spec's literal text, so no change is needed.
- tasks/15-landing-page.md, `## Next` (advisory, for the main session and not in my section). The 2026-09-23 "after APPROVED" note describes edits to the superseded draft. Both of those fixes are now part of the re-planned spec. Mark the note as superseded, or replace it, so the PR body does not describe work as post-review edits.
- Test Steps: every ai step runs against the files as written. Step 12's `main...` form must be re-run after the commit. The user steps have code behind them:
  - Step 15: the one-time setup is documented in the workflow header and Project.md.
  - Steps 16–21: the preview command mirrors the deploy.
  - Step 19: `copy.js` copies `#install-cmd`'s `textContent`, which is the canonical one-liner.
  - Step 22: this is Project.md Verify 8, which matches the artifact contents.

## Test Steps (planner writes; `ai` rows run by the main session before the PR opens, `user` rows by the human at the PR)

> **2026-09-23 (planner, re-plan).** All steps are rewritten for the github.io decision (see the note at the top of Spec). Task 14 is reverted, so there is no custom domain. `install.sh` is no longer in the artifact. The listing is now `copy.js icon.png icon.svg index.html style.css`. Step 8 serves the artifact under `/active-browser/` to prove the subpath works. Step 11 checks that `activebrowser.app` is absent from the tree. Step 12 diffs against `main`. User step 15 (enable Pages) must happen before merge. The results of the previous run applied to the old steps and are discarded.

**Preconditions**
- Run every `ai` row from the repo root on branch `feature/landing-page`. `S` is the session scratchpad directory, and `T=$S/pages`. No `make install` is needed, because the app does not change.
- Stage the new files (`git add site .github/workflows/pages.yml`) before step 1. Step 12's `main...` form is meaningful only after the commit; before it, the working-tree forms in that step are authoritative.
- **Local preview** for user steps 16–21, run from the repo root. It is self-contained and mirrors the deploy:
  `D=$(mktemp -d) && mkdir $D/active-browser && cp -R site/. $D/active-browser/ && cp assets/icon.svg $D/active-browser/icon.svg && cp assets/icon-1024.png $D/active-browser/icon.png && PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("",0));print(s.getsockname()[1])') && echo "Preview: http://127.0.0.1:$PORT/active-browser/" && python3 -m http.server $PORT --bind 127.0.0.1 --directory $D`
  Open the printed URL. Stop the server with Ctrl-C.
- User step 15 must be done **before merge**. Step 22 needs the PR merged to `main` and the `pages` workflow green.
- Covers: Project.md §3 Phase 6 Verify 8 (new), plus task-specific checks.

| # | Who | Action (exact command / click) | Expected | Actual | Result |
|---|---|---|---|---|---|
| 1 | ai | `git ls-files site ; ls -A site ; for f in install.sh icon.svg icon.png CNAME; do test ! -e site/$f \|\| echo "BAD $f"; done` | Both listings show exactly `copy.js index.html style.css`, with no `BAD` line | both `copy.js index.html style.css` (after `git add site`); no BAD | pass |
| 2 | ai | `ruby -ryaml -e 'y=YAML.load_file(".github/workflows/pages.yml"); o=y["on"]\|\|y[true]; p o["push"]["branches"], o["push"]["paths"], o.key?("workflow_dispatch"), y["permissions"], y["concurrency"]; p y["jobs"].values.flat_map{\|j\| j["steps"].map{\|s\| s["uses"]}.compact}; puts y["jobs"]["build"]["steps"].find{\|s\| s["run"]}["run"]' ; grep -cE '^\s*cmp ' .github/workflows/pages.yml ; grep -cE 'cmp .*&&\|cp install\.sh\|cname' .github/workflows/pages.yml` | Branches `["main"]`. Paths are exactly `site/**`, `assets/icon.svg`, `assets/icon-1024.png`, `.github/workflows/pages.yml`. `true`. Permissions are `contents: read`, `pages: write`, `id-token: write`. Concurrency is `pages` / `false`. Every `uses` starts with `actions/`. The run script matches item 2. `cmp` line count `2`. Forbidden-pattern count `0` | all expected; uses only actions/*; cmp lines 2; forbidden 0 | pass |
| 3 | ai | Artifact simulation using the real workflow script: `T=$S/pages; rm -rf $T && mkdir -p $T/assets && cp -R site $T/ && cp assets/icon.svg assets/icon-1024.png $T/assets/ && ruby -ryaml -e 'puts YAML.load_file(ARGV[0])["jobs"]["build"]["steps"].find{\|s\| s["run"]}["run"]' .github/workflows/pages.yml > $T/assemble.sh && (cd $T && bash assemble.sh); echo "exit=$?"; ls -A $T/_site` | `exit=0`, no `cmp` output. The listing is exactly `copy.js icon.png icon.svg index.html style.css` | exit=0; `copy.js icon.png icon.svg index.html style.css` | pass |
| 4 | ai | Guard check: for each `f` in `icon.svg icon.png install.sh CNAME`, rebuild `$T` as in step 3 (without running the script), `touch $T/site/$f`, then `(cd $T && bash assemble.sh); echo "exit=$?"`. Finally, restore `$T` by re-running step 3 | For each `f`: an `::error::site/$f must not be …` line and `exit=1`. The icon files say "copied from assets/", while `install.sh` and `CNAME` say "must not be published" | `::error::` + exit=1 for all four, with the expected messages | pass |
| 5 | ai | `grep -Eo '(src\|href\|content)="https?://[^"]*"' site/index.html \| sort -u ; grep -cE '(src\|href)="/' site/index.html ; grep -cE '<style\|style="' site/index.html ; grep -c '<script' site/index.html ; grep '<script' site/index.html ; grep -ciE 'http\|url\(\|@import\|@font-face' site/style.css ; grep -ciE 'http\|fetch\|XMLHttpRequest\|sendBeacon\|import\|eval\|localStorage\|sessionStorage' site/copy.js` | Every absolute URL starts with `https://hexember.github.io/active-browser/` or `https://github.com/hexember/active-browser`. Root-absolute count `0`. Inline-style count `0`. Script count `1`, and that line is `<script src="copy.js" defer></script>`. The `style.css` count is `0` and the `copy.js` count is `0` | absolute URLs only hexember.github.io/active-browser/* and github.com/hexember/active-browser*; 0; 0; 1 = copy.js defer; 0; 0 | pass |
| 6 | ai | `xmllint --html --noout site/index.html 2>&1 \| grep -vE 'Tag (header\|nav\|main\|section\|footer\|details\|summary) invalid' \| grep -E 'error\|warning'` | No output | no output | pass |
| 7 | ai | `grep -cF 'curl -fsSL https://raw.githubusercontent.com/hexember/active-browser/main/install.sh \| sh' site/index.html ; grep -F 'id="install-cmd"' site/index.html ; grep -oE 'https?://[^ "<]*install\.sh' site/index.html \| sort -u ; grep -ciE 'unreachable\|alternative one-liner\|fallback one-liner' site/index.html ; grep -cF 'make install' site/index.html` | `2` (the hero and Install). The `install-cmd` line contains the canonical one-liner. The URL list is exactly one line, `https://raw.githubusercontent.com/hexember/active-browser/main/install.sh`. `0`. At least `1` | `2`; install-cmd has the one-liner; single raw URL; `0`; `1` | pass |
| 8 | ai | Subpath serve (Verify 8 simulated locally): `R=$S/root; rm -rf $R && mkdir -p $R && cp -R $T/_site $R/active-browser && PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("",0));print(s.getsockname()[1])'); echo "port $PORT"; python3 -m http.server $PORT --bind 127.0.0.1 --directory $R >/dev/null 2>&1 & P=$!; sleep 1; B=http://127.0.0.1:$PORT/active-browser; curl -s -o /dev/null -w "%{http_code} %{redirect_url} /active-browser\n" $B; for p in "" index.html style.css copy.js icon.svg icon.png; do curl -s -o /dev/null -w "%{http_code} %{content_type} /$p\n" $B/$p; done; for r in $(grep -oE '(src\|href)="[^"#:]+"' site/index.html \| sed -E 's/.*="([^"]+)"/\1/' \| sort -u); do curl -s -o /dev/null -w "%{http_code} ref $r\n" $B/$r; done; curl -s -o /dev/null -w "%{http_code} install.sh\n" $B/install.sh; kill $P` | The first line is the port. `/active-browser` gives `301` with a redirect to `…/active-browser/`. Every page line is `200`, with `text/html` for `/` and `index.html`, `text/css`, a JavaScript type, `image/svg+xml` and `image/png`. Every `ref` line is `200`; the refs are at least `style.css`, `copy.js`, `icon.svg` and `icon.png`. The last line is `404 install.sh` | port 57332; 301 → /active-browser/; all 200 with expected types; refs copy.js/icon.png/icon.svg/style.css 200; `404 install.sh` | pass |
| 9 | ai | Structure, a11y and absolute URLs: `for t in '<html lang="en"' '<header' '<nav' '<main id="main"' '<footer' 'href="#main"' 'name="description"' 'name="color-scheme"' 'http-equiv="Content-Security-Policy"' '<link rel="canonical" href="https://hexember.github.io/active-browser/">' 'property="og:title"' 'property="og:description"' 'property="og:url" content="https://hexember.github.io/active-browser/"' 'property="og:image" content="https://hexember.github.io/active-browser/icon.png"' 'id="why"' 'id="how"' 'id="install"' 'id="uninstall"' 'id="faq"' 'id="copy-btn" hidden'; do grep -qF "$t" site/index.html \|\| echo "MISSING $t"; done; grep -c '<h1' site/index.html; grep -o '<img[^>]*>' site/index.html \| grep -vc 'alt="[^"]'; grep -c 'prefers-color-scheme: dark' site/style.css; grep -c ':focus-visible' site/style.css` | No `MISSING` line. h1 count `1`. The count of `img` tags without a non-empty `alt` is `0`. Both CSS counts are at least `1` | no MISSING; 1; 0; 1; 3 | pass |
| 10 | ai | Checks behind the privacy and facts claims: `grep -rnE 'URLSession\|URLRequest\|NWConnection\|CFNetwork\|WKWebView\|Analytics' Sources ; grep -rn 'NSLog' Sources \| grep -i 'url' ; grep -ciE 'intel supported\|x86_64 build' site/index.html ; grep -cF 'Apple silicon' site/index.html ; grep -cF 'raw.githubusercontent.com' site/index.html` | First: no output. Second: only the `URLDispatcher` line that logs a URL **count**, never a URL. Third: `0`. Fourth: at least `1`. Fifth: at least `3` (two one-liners plus the privacy answer) | no hits; only URLDispatcher count log; 0; 1; 3 | pass |
| 11 | ai | `git grep --untracked -nF 'activebrowser.app' -- ':!tasks/15-landing-page.md' ; echo "exit=$?"` | No match lines, and `exit=1` (nothing found, including in untracked `site/` and `pages.yml`) | no matches, exit=1 | pass |
| 12 | ai | `swift build 2>&1 \| grep -E 'error:\|warning:'` ; `git diff --stat main -- Sources Support Makefile Package.swift install.sh .github/workflows/ci.yml .github/workflows/release.yml ; git status --porcelain -- Sources Support Makefile Package.swift install.sh .github/workflows/ci.yml .github/workflows/release.yml` ; after the commit, also `git diff --stat main... -- Sources Support Makefile Package.swift install.sh .github/workflows/ci.yml .github/workflows/release.yml` | No project errors or warnings (ignore the CommandLineTools search-path noise). All three diff/status outputs are empty | only CommandLineTools ld noise; diff/status empty (main... form re-run after commit by git-agent) | pass |
| 13 | ai | `grep -nE '^\| 15 \| 6 \|' Project.md ; grep -nF 'Source: **GitHub Actions**' Project.md ; grep -nF 'https://hexember.github.io/active-browser/$p' Project.md ; grep -nF '.github/workflows/pages.yml' Project.md ; grep -nF 'site/{index.html,style.css,copy.js}' Project.md ; grep -nF '(https://hexember.github.io/active-browser/)' README.md ; grep -nE '^site/ ' README.md ; grep -nF 'Landing page at https://hexember.github.io/active-browser/' CHANGELOG.md` | Each grep prints at least one line: the split row, the Pages setup bullet, Verify 8, the §4 `pages.yml` line, the §4 `site/` line, the README link, the README layout line and the CHANGELOG entry (under `[Unreleased]` → `### Added`) | all eight greps print a line | pass |
| 14 | ai | `curl -s -o /dev/null -w '%{http_code}\n' https://raw.githubusercontent.com/hexember/active-browser/main/install.sh` | `200`: the one URL the page advertises is live | `200` | pass |
| 15 | user | **Before merge:** GitHub → `hexember/active-browser` → Settings → Pages → Build and deployment → Source: **GitHub Actions**. Leave *Custom domain* empty | Pages shows Source "GitHub Actions" and no custom domain. (If a previous attempt set `activebrowser.app` here, clear it.) | | pass / fail |
| 16 | user | Start the local preview (see Preconditions) and open the printed `http://127.0.0.1:<port>/active-browser/` in Safari, with macOS in **Light** appearance | The icon shows, and the hero shows the raw.githubusercontent one-liner. Why, How it works, Install, Uninstall and FAQ read correctly. The nav links jump to each section. There is no "unreachable"/fallback install block | | pass / fail |
| 17 | user | System Settings → Appearance → **Dark**, then reload | Dark background and light text. Links are still clearly visible, and the code blocks are readable | | pass / fail |
| 18 | user | Safari → Develop → Enter Responsive Design Mode → 360 px wide | No horizontal page scroll. The long one-liner scrolls inside its own box. The nav wraps without overlapping, and the icon and headings are not clipped | | pass / fail |
| 19 | user | Click **Copy**, then paste into Terminal (do not press Return) | The status reads "Copied". The pasted text is exactly `curl -fsSL https://raw.githubusercontent.com/hexember/active-browser/main/install.sh \| sh` | | pass / fail |
| 20 | user | Safari → Develop → Disable JavaScript, then reload | No Copy button is shown. All content, the nav anchors and the FAQ `<details>` still work. Re-enable JavaScript afterwards | | pass / fail |
| 21 | user | Reload and press Tab repeatedly | The first Tab reveals a "Skip to content" link. Every link, the Copy button and each FAQ summary shows a visible focus ring | | pass / fail |
| 22 | user | **After merge**, once the `pages` workflow is green (Actions tab): run Project.md Phase 6 Verify 8, `for p in "" style.css copy.js icon.svg icon.png; do curl -fsS -o /dev/null -w "%{http_code} /$p\n" https://hexember.github.io/active-browser/$p; done; curl -s -o /dev/null -w "%{http_code} install.sh\n" https://hexember.github.io/active-browser/install.sh`, then open https://hexember.github.io/active-browser/ | `200` on the five page lines, then `404 install.sh`. The live page matches the preview, the tab shows the ActiveBrowser icon, and the Copy button works (the page is HTTPS) | | pass / fail |

**Reset after testing**
- Stop the local preview server (Ctrl-C) and run `rm -rf "$D"`. The ai-step server in step 8 is killed by the step itself.
- Set System Settings → Appearance back to your usual setting. Re-enable JavaScript in Safari (Develop menu), and exit Responsive Design Mode.
- Pages stays enabled; that is the intended end state. To take the site down: Settings → Pages → Unpublish site (or set Source back to "Deploy from a branch" / None).
- There is no app or Launch Services state to undo.

**Result (ai rows):** pass — 2026-09-23 (steps 1–14, run by main session; step 12's `main...` form to be re-run after commit)
**Result (user rows):** <recorded at the PR by the user>
Failures: <step # — what happened — link to follow-up task, or "none">

## Next
<what unblocks or follows this task>

_2026-09-23 (main session, after APPROVED) — SUPERSEDED by the github.io re-plan; both fixes are now part of the Spec:_ I applied two advisory fixes from the review. `pages.yml` now puts each `cmp` on its own line, so `set -e` catches every mismatch. The privacy answer in `site/index.html` now includes GitHub's release-download host. After the edits I re-ran the ai steps (see Result).
