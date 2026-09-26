---
name: next-task
description: Run exactly one ActiveBrowser task end-to-end — task file, stacked branch, planner, implementer, code-reviewer, ai test steps, PR — then stop.
argument-hint: "[what to build, or an existing tasks/NN-<slug>.md to resume]"
disable-model-invocation: true
---

# /next-task — one task, one PR, then stop

Request: $ARGUMENTS

You are the orchestrator. Route work between the subagents in `.claude/agents/`; subagents never call each other, every hand-off goes through you. Task-file rules (naming, sections, `Status:` values) are in `CLAUDE.md`; hard constraints are in `.claude/rules/guardrails.md`.

## Pick the task

1. `ls tasks/` and read every task whose `Status:` is not `done`.
2. If one is `planned`, `in-progress`, `in-review` or `blocked`, **resume it** from the step matching its status — do not start a new one. If `$ARGUMENTS` names a task file, resume that one.
3. Otherwise create the next `tasks/NN-<slug>.md` from `tasks/TEMPLATE.md`. Scope comes from `$ARGUMENTS`; if empty, take the next unstarted item in `Project.md` §3 and say which one you picked.

## Execution loop

0. **git-agent** `start` → branch from `main` if every earlier task is `done`, otherwise from the newest unmerged task's branch (stacked); fills *Branch* / *Base*. Every agent below receives the task file path and reads it before acting.
1. **planner** → fills *Goal*, *Spec*, *Test Steps* (each tagged `ai` or `user`). Status → `planned`.
2. **implementer** → fills *Implementation Notes*. Status → `in-progress`.
   - `[RE-PLAN REQUEST]` → Status `blocked: <reason>`, back to step 1.
3. **code-reviewer** → fills *Review*. Status → `in-review`.
   - `CHANGES_REQUESTED` → back to **implementer** with the review notes.
4. On `APPROVED`, run every `ai` Test Step yourself on this machine (build, `make install`, `lsregister` checks, `open <url>` routing checks) and fill *Actual* / *Result*. Any `ai` failure → back to **implementer**.
5. **git-agent** `commit` → commits code + task file, pushes, opens the PR (base = parent branch) with the task's *Testing notes* in the body (preconditions, `user` steps as a table with expected results, reset step), fills *PR*. Status → `pr-open`. Append the task's `user` steps to `tasks/TEST-PLAN.md`.
6. **Stop.** Report the PR URL and the `user` steps. Do not start another task — the user runs `/next-task` again when ready.

```
git-agent: start ─► planner ◄──[RE-PLAN]── implementer ◄──CHANGES_REQUESTED── code-reviewer
                       └──────────────────────►┘ └──────────────────────────────►┘
                                                            │ APPROVED
                               ai test steps ──(fail)──► implementer
                                    │ pass
                           git-agent: commit + PR ─► STOP
```

## Pausing for the user

Ask the user mid-task only when a `user` step blocks all further verification (currently one case: macOS's "set as default browser" confirmation dialog). Ask once, keep building everything that does not depend on it, and mark dependent `ai` steps `not run — needs user step N`.

## Follow-ups on open PRs

- A review comment or failed `user` step on an open PR: if that PR is the stack tip, a follow-up commit on its branch; otherwise a new `fix/` task stacked on the tip.
- A parent PR changed after review, or was merged: **git-agent** `restack` rebases every child branch. GitHub retargets children to `main` when a parent merges. `Status: done` is set only once the user has merged.

## Sources of truth

- Architecture, phases, code skeleton, manual test checklist: `Project.md`
- Hard constraints: `.claude/rules/guardrails.md` (no XCTest target; testing is manual, §3)
- Technical background: `docs/skills.md`
