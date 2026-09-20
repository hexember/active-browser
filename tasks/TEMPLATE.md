# Task NN — <title>

Status: planned
Phase: <1–6, from Project.md §3>
Branch: <feature/… | fix/… | chore/…, filled by git-agent>
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

## Manual Test Steps (planner writes; user executes and fills Actual / Result)

**Preconditions**
- Build: `make install` completed on commit `<hash>`; test the copy in `/Applications`, never `build/` or `.build/`.
- System state: <e.g. ActiveBrowser set as default browser; Brave and Arc installed; all browsers quit>
- Covers: <Project.md §3 Phase N Verify steps X–Y, or "task-specific">

| # | Action (exact command / click) | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | <`open https://example.com` from Terminal> | <opens in Brave> | | pass / fail |
| 2 | <Focus Arc, then Terminal, `open https://example.com`> | <opens in Arc> | | pass / fail |
| 3 | | | | |

**Reset after testing**
- <System Settings → Desktop & Dock → Default web browser → your real browser>
- <Launch at Login off>
- or: none

**Result:** <not run | pass | fail> — <date> — <machine / macOS version>
Failures: <step # — what happened — link to follow-up task, or "none">

## Next
<what unblocks or follows this task>
