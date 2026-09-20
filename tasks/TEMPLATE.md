# Task NN — <title>

Status: planned            <planned | in-progress | in-review | pr-open | done | blocked: reason>
Phase: <1–6, from Project.md §3>
Branch: <feature/… | fix/… | chore/…, filled by git-agent>
Base: <main | branch of the previous unmerged task, filled by git-agent>
PR: <url, filled by git-agent>
Created: YYYY-MM-DD

## Goal
<one or two sentences: what this task delivers and why>

## Spec (planner)
- [ ] <file-level task 1>
- [ ] <file-level task 2>

Acceptance criteria:
- <observable behaviour the reviewer can verify>

## Implementation Notes (implementer)
<what was built, decisions made, anything that deviates from the spec and why>

Build: `swift build` <clean | warnings listed> · `make bundle` <ok | n/a>

## Review (code-reviewer)
Verdict: <APPROVED | CHANGES_REQUESTED>
- <file:line — finding — required change>

## Test Steps (planner writes; `ai` rows run by the main session before the PR opens, `user` rows by the human at the PR)

**Preconditions**
- Build: `make install` completed on commit `<hash>`; test the copy in `/Applications`, never `build/` or `.build/`.
- System state: <e.g. ActiveBrowser set as default browser; Brave and Arc installed; all browsers quit>
- Covers: <Project.md §3 Phase N Verify steps X–Y, or "task-specific">

| # | Who | Action (exact command / click) | Expected | Actual | Result |
|---|---|---|---|---|---|
| 1 | ai | <`make install`> | <`/Applications/ActiveBrowser.app` exists, `pgrep -x ActiveBrowser` prints a pid> | | pass / fail |
| 2 | user | <Menu bar → Set as Default Browser → accept dialog> | <System Settings shows ActiveBrowser as default> | | pass / fail |
| 3 | ai | <`open https://example.com` from Terminal> | <Brave becomes frontmost> | | pass / fail |

**Reset after testing**
- <System Settings → Desktop & Dock → Default web browser → your real browser>
- <Launch at Login off>
- or: none

**Result (ai rows):** <pass | fail | not run — needs user step N> — <date>
**Result (user rows):** <recorded at the PR by the user>
Failures: <step # — what happened — link to follow-up task, or "none">

## Next
<what unblocks or follows this task>
