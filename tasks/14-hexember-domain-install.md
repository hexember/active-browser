# Task 14 — Rename repo owner to hexember and serve install.sh from activebrowser.app

Status: in-review            <planned | in-progress | in-review | pr-open | done | blocked: reason>
Phase: 6
Branch: chore/hexember-domain-install
Base: main
PR: <url, filled by git-agent>
Created: 2026-09-23

## Goal
Point every link and `install.sh` at the renamed repo `hexember/active-browser`, and make `curl -fsSL https://activebrowser.app/install.sh | sh` the one-liner, served by GitHub Pages from this repo with the repo-root `install.sh` as the only copy.

## Spec (planner)
Note on the grep target: this file never spells the old owner as one word, so the Test Step grep can cover the whole tree. Every command below uses `'tajpuriya''27'` (shell concatenation) for the same reason. The implementer must do the same in any file this task touches, including CHANGELOG ("the repository moved to the `hexember` account"). Do not write the old name there.

1. [x] **`Project.md`** (do this first; it clears the §4 re-plan trigger)
   - §3 split table: add row `| 14 | 6 | Repo owner → hexember; `site/` + `pages.yml` serve `install.sh` at activebrowser.app | domain one-liner installs |`.
   - §3 Phase 6: in step 2, change the API URL to `hexember/active-browser`. Change *Usage* to `curl -fsSL https://activebrowser.app/install.sh | sh`. Add a bullet: *GitHub Pages (`.github/workflows/pages.yml`) publishes `site/` plus a deploy-time copy of the root `install.sh` to `https://activebrowser.app`. The root file is the only committed copy. The custom domain is set in repo Settings → Pages, not by a `CNAME` file (Actions-deployed Pages ignores one). Fallback URL: `https://raw.githubusercontent.com/hexember/active-browser/main/install.sh`.*
   - Phase 6 Verify: the header note becomes "Steps 4–6 need the repo to be public and activebrowser.app live on Pages". Steps 4 and 6 use the domain one-liner. Add step 8: `curl -fsSL https://activebrowser.app/install.sh | diff - install.sh` — expected: no output.
   - §4 tree: replace the `release.yml` line with `.github/workflows/{ci,release,pages}.yml   # Phase 6 (pages: serves site/ + install.sh)`. Add `site/index.html   # Phase 6 landing page for activebrowser.app; install.sh is copied in at deploy time`.
2. [x] **`install.sh`**: line 12 usage → the domain one-liner. Line 40 → `REPO="hexember/active-browser"`. No other change; `git diff` on this file is exactly those 2 lines.
3. [x] **`site/index.html`** (new): a single self-contained HTML5 page with inline `<style>` only. It has no `<script>` and no external CSS, fonts, images or trackers. Contents: the title, a one-line description, the one-liner in `<pre><code>`, "then choose *Set as Default Browser* from the menu bar icon", and links to `https://github.com/hexember/active-browser` and `.../releases/latest`. Requirements line: macOS 13+. Nothing else. **No `site/CNAME`**: with Actions-based Pages it is ignored, and a file that looks authoritative but isn't would mislead. The domain setting lives in repo Settings (user step 4) and is documented in Project.md.
4. [x] **`.github/workflows/pages.yml`** (new):
   - `on: push: branches: [main], paths: ['site/**', 'install.sh', '.github/workflows/pages.yml']` plus `workflow_dispatch:`.
   - `permissions: { contents: read, pages: write, id-token: write }`. `concurrency: { group: pages, cancel-in-progress: false }`. Don't cancel a deployment that is already running.
   - Job `build` on `ubuntu-latest` (no macOS needed). Steps: `actions/checkout@v4`, `actions/configure-pages@v5`, then a `run` step that
     - fails if `site/install.sh` exists (this keeps a single source),
     - runs `mkdir _site && cp -R site/. _site/ && cp install.sh _site/install.sh`,
     - checks `cmp install.sh _site/install.sh`,
     - then `actions/upload-pages-artifact@v3` with `path: _site`.
   - Job `deploy`: `needs: build`, `environment: { name: github-pages, url: ${{ steps.deployment.outputs.page_url }} }`, `actions/deploy-pages@v4` with `id: deployment`.
   - Header comment: explain that root `install.sh` is the single source and that the custom domain is set in Settings. These are GitHub's first-party actions only, the same category as `actions/checkout` in `ci.yml`, so the zero-dependency rule (which applies to the Swift app) is not affected.
5. [x] **`.github/workflows/release.yml:128`**: the release-notes install line → the domain one-liner. **`.github/ISSUE_TEMPLATE/config.yml:4`** → hexember security-advisories URL. (Both are hits the task brief missed.)
6. [x] **`README.md`**: change the badges (lines 3–4) and the clone URL (line 63) to hexember. Line 46 becomes the domain one-liner. Directly below the code block, add one line: *"If activebrowser.app is unreachable: `curl -fsSL https://raw.githubusercontent.com/hexember/active-browser/main/install.sh | sh`"*.
7. [x] **`CONTRIBUTING.md:9`**, **`SECURITY.md:6`**: owner → hexember.
8. [x] **`CHANGELOG.md`**: change the links on lines 16, 19, 56 and 57 to hexember. Under `[Unreleased]`, add a `### Changed` entry: the repo moved to the `hexember` account; the installer is now served from `https://activebrowser.app/install.sh`; the raw GitHub URL is kept as a fallback.
9. [x] **`tasks/TEST-PLAN.md`** (lines 188, 207, 208, 218): repo slug → hexember and `gh auth token --user hexember`. Make no other edits, including to the "repo is currently private" narrative, which is historical.
10. [x] **`tasks/01`–`11` `*.md`**: mechanical replace only. Change `<old>/active-browser` to `hexember/active-browser`, and `--user <old>` to `--user hexember`. Change nothing else. This touches other agents' sections, which is justified as link maintenance, not a content rewrite. Do not add dated notes. The line in `tasks/09:177` about "active `gh` account is `sunil-phil`" stays as history, with only the `--user` value changed.

Acceptance criteria:
- `grep -rn 'tajpuriya''27' . --exclude-dir=.git --exclude-dir=.build --exclude-dir=build` prints nothing.
- The domain one-liner appears verbatim in `install.sh:12`, `README.md`, `Project.md` (Usage, Verify 4 and 6), `release.yml` and `site/index.html`. `raw.githubusercontent.com` appears only in the README fallback line and the Project.md fallback note.
- `install.sh` diff is exactly 2 lines. It still parses under `bash -n`/`sh -n` and stays executable.
- `pages.yml` matches item 4. The assembled artifact holds exactly `index.html` and `install.sh`, and that `install.sh` is byte-identical to the root copy. No `site/install.sh` or `site/CNAME` is committed.
- `swift build` is clean (no Swift changes).

Architectural notes and risks:
- **Deploy ordering.** Pages must be set to *Source: GitHub Actions* (user step 2) before the first `pages.yml` run. Otherwise `configure-pages`/`deploy-pages` fails on the merge push. If it ran early, re-run it from the Actions tab (`workflow_dispatch`).
- **Dead-link window.** After merge, README and the release notes advertise a URL that fails until DNS, the certificate and the custom domain are live. `.app` is HSTS-preloaded, so there is no HTTP fallback; `curl -f` errors out cleanly. The README fallback line covers this gap. Preferably finish user steps 1–2 before merging.
- **Domain = trust root.** Whoever controls activebrowser.app controls what users pipe into `sh`. Recommend verifying the domain at account level (user step 1b) to block Pages domain takeover. Keep registration auto-renew on. SHA256SUMS verification inside `install.sh` still protects the app payload, but not the script itself.
- **Staleness.** Pages serves with `Cache-Control: max-age=600`, so the domain can lag a push to `install.sh` by about 10 minutes. The Verify diff step should be run after that.
- **YAML `on:` key.** Ruby/Psych (YAML 1.1) parses `on` as boolean `true`. Test step 5 reads `y["on"] || y[true]`. This is not a workflow bug.
- No Swift, Info.plist or Makefile changes. No guardrail touched. The new paths are added to §4 in item 1.

## Implementation Notes (implementer)
- **Project.md**: I added §3 split row 14 and changed the Phase 6 step 2 API URL to hexember. *Usage* is now the domain one-liner. There is a new GitHub Pages bullet with the raw fallback URL. The Verify header now says "public and activebrowser.app live on Pages". Verify 4 and 6 use the domain one-liner, and step 8 is the new `diff` check. In §4, the tree has the `{ci,release,pages}.yml` line and the `site/index.html` line.
- **install.sh**: only lines 12 and 40 changed (`git diff --numstat` = `2	2`). The file is still executable.
- **site/index.html** (new): HTML5 with inline `<style>` only, including a `prefers-color-scheme` dark variant, which is still inline CSS. It has no script, links, fonts or images. It contains the title, a one-line description, the one-liner in `<pre><code>`, the Set as Default Browser line, "Requirements: macOS 13+." and links to the repo and releases/latest. There is no `site/CNAME`.
- **.github/workflows/pages.yml** (new): built as item 4 describes. The run step uses `set -euo pipefail`, fails with `::error::` if `site/install.sh` exists, then assembles `_site` and runs `cmp`. The `deploy` job also has `runs-on: ubuntu-latest`, which GitHub requires on every job (item 4 lists `build`'s runner only).
- **release.yml:128** now uses the domain one-liner. **ISSUE_TEMPLATE/config.yml:4** points to the hexember advisories URL.
- **README.md**: badges and clone URL now point to hexember. The install block uses the domain one-liner, with the fallback line directly below it.
- **CONTRIBUTING.md**, **SECURITY.md**: owner changed to hexember.
- **CHANGELOG.md**: the four links now point to hexember. I added `### Changed` under `[Unreleased]`, after `### Added`. The entry says the raw GitHub URL is kept as a fallback, "see the README", but does not spell out the raw URL. Spelling it out would break the acceptance rule that `raw.githubusercontent.com` appears only in README and Project.md.
- **tasks/TEST-PLAN.md** and **tasks/01–11**: I did a scripted mechanical replace of `<old>/active-browser` → `hexember/active-browser` and `--user <old>` → `--user hexember`. Nothing else changed. There are no dated notes. The old owner name is not spelled out anywhere in this change; the scripts built it by concatenation.
- Side effect of the mechanical replace: historical lines in tasks/09 and tasks/10 now say `raw.githubusercontent.com/hexember/...`. Test step 2 excludes `tasks/`, and the spec asks for exactly this replacement.

Checks run here: the old-owner grep prints nothing. Test steps 2, 3, 5, 6 and 7 give the expected output: all 5 files listed; raw URL only in the README and Project.md; `bash -n`/`sh -n` OK; numstat `2 2`; YAML asserts match; artifact is exactly `index.html install.sh` and `cmp` is silent; `0` external refs, and xmllint is silent. I did not run steps 8 and 9 (network) and left them for the main session.

Build: `swift build` clean (only the CommandLineTools `ld` search-path noise) · `make bundle` ok (codesign succeeded; no Swift changes)

## Review (code-reviewer)
Verdict: APPROVED
- Checked by the reviewer (2026-09-23), not taken from the implementation notes. `swift build`: no project errors or warnings, only the two CommandLineTools `ld` search-path lines. `make bundle`: ok, codesign succeeded. Old-owner grep across the tree: no output. The 5-file domain grep lists all 5 files. `raw.githubusercontent.com` outside `tasks/` appears only at `README.md:49` and `Project.md:193`. `install.sh`: numstat `2 2`, mode 100755, passes `bash -n` and `sh -n`. `pages.yml` Ruby asserts: all expected values. Artifact simulation gives exactly `index.html install.sh`, and `cmp` is silent. `index.html`: 0 external refs, and xmllint is silent. Steps 8 and 9 already pass (`#!/bin/bash`, `200`, `302`), and `origin` is already `hexember/active-browser`.
- Mechanical-replace audit: I applied the two spec substitutions to every changed file's `main` version and diffed the result against the working tree. All of `tasks/01–11`, `TEST-PLAN.md`, `CONTRIBUTING.md`, `SECURITY.md` and `ISSUE_TEMPLATE/config.yml` match exactly. Only the five intentionally edited files (`install.sh`, `README.md`, `Project.md`, `CHANGELOG.md`, `release.yml`) differ, and each differs only as items 1, 2, 5, 6 and 8 describe.
- `.github/workflows/release.yml:128`: the change sits inside a quoted heredoc (`<<'EOF'`), so no expansion happens and the YAML still parses. The release job does nothing else with the repo slug (`gh` uses the implicit `GITHUB_REPOSITORY`), so the release workflow is not at risk.
- `.github/workflows/pages.yml`: triggers, `permissions`, `concurrency` (`cancel-in-progress: false`), the `github-pages` environment with `page_url`, and the pinned first-party action versions all match spec item 4. The added `deploy.runs-on` is required and correct. `upload-pages-artifact` tars without `.git` and hidden files, and Actions-deployed Pages skips Jekyll, so `install.sh` is served byte-for-byte. `curl` without `--compressed` receives the uncompressed body. Non-blocking nit: the workflow-level `pages: write` / `id-token: write` also reach the `build` job, which does not need them. Moving them to `jobs.deploy.permissions` would be least-privilege, but the spec puts them at the top level, so no change is required.
- `.github/workflows/pages.yml:49`: `cmp install.sh _site/install.sh` compares a file against a copy made one line earlier, so it only catches a failed copy. The real guarantee of byte-identical serving is Project.md Verify 8 (user step 16). No change required; I note it so nobody reads the CI step as that proof.
- HTTPS on `.app`: the HSTS preload makes the domain unusable until the Pages certificate is issued. Architectural notes and user step 13 (Enforce HTTPS) cover this, and the README fallback line covers the dead-link window. Nothing is missing.
- `site/`: only `index.html` is present; there is no `CNAME` and no `install.sh`. The page meets item 3 (inline style only, no script or external assets).
- Test Steps: I ran ai steps 1–9 against the tree as written, and all can pass. User steps 10–16 depend on DNS, repo settings and the merge, and the code supports them: the domain one-liner is correct in every advertised place, and `install.sh` prints `Resolving the latest release of hexember/active-browser` because `REPO` changed. No step is unsatisfiable.

## Test Steps (planner writes; `ai` rows run by the main session before the PR opens, `user` rows by the human at the PR)

**Preconditions**
- Build: `ai` rows run on the task branch from the repo root. No `make install` is needed (no app change). User steps 5–7 need the PR merged to `main`.
- System state: repo `hexember/active-browser` is public; `gh` is logged in as `hexember`. For user steps 1–7: you own `activebrowser.app` and can edit its DNS.
- Covers: Project.md §3 Phase 6 Verify 4, 6 and 8 (new), plus task-specific checks.

| # | Who | Action (exact command / click) | Expected | Actual | Result |
|---|---|---|---|---|---|
| 1 | ai | `grep -rn 'tajpuriya''27' . --exclude-dir=.git --exclude-dir=.build --exclude-dir=build` | no output (exit 1) | no output, exit 1 | pass |
| 2 | ai | `grep -rln 'https://activebrowser.app/install.sh' install.sh README.md Project.md .github/workflows/release.yml site/index.html` ; `grep -rn 'raw.githubusercontent.com' --exclude-dir=.git --exclude-dir=tasks .` | first: all 5 files listed; second: only the README fallback line and the Project.md fallback note | all 5 files listed; raw URL only at README.md:49 (fallback) and Project.md:193 note | pass |
| 3 | ai | `bash -n install.sh && sh -n install.sh && test -x install.sh && git diff --numstat main -- install.sh` | parses; executable; numstat `2	2	install.sh` | parses under bash and sh; executable; `2	2	install.sh` | pass |
| 4 | ai | `swift build 2>&1 \| grep -E 'error:\|warning:'` (ignore CommandLineTools search-path noise) | no project errors or warnings | no project errors or warnings | pass |
| 5 | ai | `ruby -ryaml -e 'y=YAML.load_file(".github/workflows/pages.yml"); o=y["on"]\|\|y[true]; p o["push"]["branches"], o["push"]["paths"], o.key?("workflow_dispatch"), y["permissions"], y["concurrency"], y["jobs"]["deploy"]["environment"]["name"], y["jobs"]["deploy"]["needs"]'` | `["main"]`; paths include `site/**`, `install.sh`, `.github/workflows/pages.yml`; `true`; `{contents: read, pages: write, id-token: write}`; group `pages`, cancel `false`; `github-pages`; `build` | `["main"]`; `["site/**","install.sh",".github/workflows/pages.yml"]`; `true`; contents read/pages write/id-token write; group `pages`, cancel `false`; `github-pages`; `build` | pass |
| 6 | ai | Artifact simulation: `S=<scratchpad>/_site; rm -rf $S; test ! -e site/install.sh && test ! -e site/CNAME && mkdir $S && cp -R site/. $S/ && cp install.sh $S/install.sh && cmp install.sh $S/install.sh && ls -A $S` | no error; `cmp` silent; listing is exactly `index.html install.sh` | cmp silent; listing `index.html install.sh` | pass |
| 7 | ai | `grep -ciE '<script\|<link\|@import\|src="http' site/index.html ; xmllint --html --noout site/index.html` | `0`; xmllint prints nothing | `0`; xmllint silent | pass |
| 8 | ai | `curl -fsSL https://raw.githubusercontent.com/hexember/active-browser/main/install.sh \| head -1` | `#!/bin/bash` (the fallback path resolves under the new owner; main still has the old REPO line until merge, which is expected) | `#!/bin/bash` | pass |
| 9 | ai | `curl -s -o /dev/null -w '%{http_code}\n' https://api.github.com/repos/hexember/active-browser/releases/latest ; curl -s -o /dev/null -w '%{http_code}\n' https://github.com/hexember/active-browser/releases/latest/download/SHA256SUMS` | `200`; `302` (the endpoints `install.sh` uses resolve under hexember) | `200`; `302` | pass |
| 10 | user | **1.** At your registrar, own `activebrowser.app` and add apex `A` 185.199.108.153, .109.153, .110.153, .111.153 and `AAAA` 2606:50c0:8000::153, 8001::153, 8002::153, 8003::153. Optional: `www` CNAME `hexember.github.io`. **1b (recommended).** GitHub → your Settings → Pages → *Add a verified domain* → add the TXT record it shows. | `dig +short activebrowser.app A` lists the four IPs; the domain shows *Verified* | | pass / fail |
| 11 | user | **2.** Repo Settings → Pages → Build and deployment → Source: **GitHub Actions** (preferably before merging) | Setting saved | | pass / fail |
| 12 | user | **3.** Merge the PR. Actions tab → `pages` workflow. If it ran before step 2 and failed, *Run workflow* on `main`. | `build` and `deploy` green; the deploy job shows a `github-pages` URL | | pass / fail |
| 13 | user | **4.** Settings → Pages → Custom domain: `activebrowser.app` → Save; wait for the DNS check to pass → tick **Enforce HTTPS** (it may take up to about 1 h for the certificate) | Green DNS check; Enforce HTTPS is ticked | | pass / fail |
| 14 | user | **5.** `curl -fsSI https://activebrowser.app/install.sh \| head -1` and open `https://activebrowser.app` in a browser | `HTTP/2 200`; the landing page shows the one-liner and repo links | | pass / fail |
| 15 | user | **6.** Phase 6 Verify 3–4: quit ActiveBrowser, `rm -rf /Applications/ActiveBrowser.app`, then `curl -fsSL https://activebrowser.app/install.sh \| sh`. Then run it again with the app running (Verify 6). | Prints `==>` steps, including `Resolving the latest release of hexember/active-browser`, and ends with the Set-as-Default hint; menu bar item appears; the second run replaces the app in place without error | | pass / fail |
| 16 | user | **7.** Phase 6 Verify 8: `curl -fsSL https://activebrowser.app/install.sh \| diff - install.sh` (run from an up-to-date `main` checkout, at least 10 min after the last deploy) | no output | | pass / fail |

**Reset after testing**
- Repo settings (Pages source, custom domain, DNS) are the intended end state. Nothing to undo.
- Step 15 leaves the released build in `/Applications` in place of any dev build. To go back: `make install`. The default-browser binding survives either way (same path, same bundle id).

**Result (ai rows):** pass — 2026-09-23 (steps 1–9, run by main session)
**Result (user rows):** <recorded at the PR by the user>
Failures: <step # — what happened — link to follow-up task, or "none">

## Next
<what unblocks or follows this task>
