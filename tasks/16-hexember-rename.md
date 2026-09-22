# Task 16 — Point every link and install.sh at the hexember account

Status: pr-open
Phase: 6
Branch: chore/hexember-rename
Base: main
PR: https://github.com/hexember/active-browser/pull/27
Created: 2026-09-23

## Goal
The GitHub account was renamed to `hexember`. Update every repository link and the `install.sh` release source so nothing depends on GitHub's rename redirect (the old name is unclaimed, so anyone could register it and take over the old URLs). Replaces reverted PR #25 with only the required change: no custom domain, no Pages site. (Task 14 was reverted; 15 is an unmerged local draft, so this is 16.)

## Spec (planner)
- [x] Replace the repo slug `<old>/active-browser` → `hexember/active-browser` in every tracked file (install.sh `REPO=` and usage comment, README badges/one-liner/clone URL, CONTRIBUTING, SECURITY, CHANGELOG links, Project.md, `.github/workflows/release.yml`, `.github/ISSUE_TEMPLATE/config.yml`, `tasks/*`).
- [x] Replace `gh auth token --user <old>` → `--user hexember` (tasks/10, TEST-PLAN).
- [x] CHANGELOG `[Unreleased] → Changed` entry.

Acceptance criteria:
- `git grep` for the old name prints nothing.
- The install one-liner is `curl -fsSL https://raw.githubusercontent.com/hexember/active-browser/main/install.sh | sh`.
- `install.sh` differs from `main` in exactly the two lines above; no behaviour change.

## Implementation Notes (implementer)
Mechanical `sed` over the files `git grep` listed (20 files, 54 lines), plus the CHANGELOG entry. No Swift changes.

Build: `swift build` clean · `make bundle` n/a

## Review (code-reviewer)
Verdict: APPROVED — mechanical rename; diff reviewed by the main session (every changed line is a slug or `--user` substitution, plus the CHANGELOG entry).

## Test Steps (planner writes; `ai` rows run by the main session before the PR opens, `user` rows by the human at the PR)

**Preconditions**
- No app change; nothing to install.
- Covers: task-specific.

| # | Who | Action (exact command / click) | Expected | Actual | Result |
|---|---|---|---|---|---|
| 1 | ai | `git grep -n 'tajpuriya''27'` | no output | no output (exit 1) | pass |
| 2 | ai | `bash -n install.sh && sh -n install.sh && git diff --numstat origin/main -- install.sh` | parses; `2	2	install.sh` | parses; `2	2	install.sh` | pass |
| 3 | ai | `swift build` | no errors or warnings | `Build complete!`, no errors or warnings | pass |
| 4 | ai | `curl -s -o /dev/null -w '%{http_code}\n'` on `raw.githubusercontent.com/hexember/active-browser/main/install.sh`, `api.github.com/repos/hexember/active-browser/releases/latest`, `github.com/hexember/active-browser/releases/latest/download/SHA256SUMS` | `200`, `200`, `302` | `200`, `200`, `302` | pass |
| 5 | user | After merge, in a fresh Terminal: `curl -fsSL https://raw.githubusercontent.com/hexember/active-browser/main/install.sh \| sh` | Prints `Resolving the latest release of hexember/active-browser`, installs, ends with the Set-as-Default hint | | pass / fail |
| 6 | user | Open the README on GitHub | ci and release badges render; links go to `hexember/active-browser` | | pass / fail |

**Reset after testing**
- Step 5 replaces any dev build in `/Applications` with the released one; `make install` to go back.

**Result (ai rows):** pass — 2026-09-23 (steps 1–4)
**Result (user rows):** <recorded at the PR by the user>
Failures: none

## Next
Optional later: GitHub Pages site at `hexember.github.io/active-browser` (the draft landing-page work on `feature/landing-page` needs rebasing onto this).
