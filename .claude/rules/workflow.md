# Development Workflow (Main Session as Orchestrator)

The main Claude session coordinates the cycle below, routing work between the subagents defined in `.claude/agents/`. Subagents never call each other directly; every hand-off goes through the main session.

## Execution Loop

0. Create `tasks/NN-<slug>.md` from `tasks/TEMPLATE.md` (rules in `CLAUDE.md`), then **git-agent** `start` → creates the task's branch from up-to-date `main` and fills *Branch*. All later work happens on that branch. Every agent below receives the task file path and reads it before acting.
1. Hand the task file to **planner** → fills *Spec* and *Manual Test Steps*. Status → `planned`.
2. Send the task file to **implementer** → fills *Implementation Notes*. Status → `in-progress`.
   - *Re-plan trigger*: if implementer returns a `[RE-PLAN REQUEST]`, set Status → `blocked` with the reason and return to step 1.
3. Send the task file to **code-reviewer** → fills *Review*. Status → `in-review`.
   - `CHANGES_REQUESTED` → back to **implementer** with the review notes.
4. On `APPROVED`, **git-agent** `commit` → commits the code + task file, pushes, opens a **draft** PR, fills *PR*. Status → `awaiting-manual-test`. Hand the user the task's *Manual Test Steps* (and, if this closes a phase, the phase's **Verify** block from `Project.md`). Wait for the result and record it in the task file.
5. On pass, **git-agent** `finish` → commits the recorded result (`docs:`), marks the PR ready for review. Status → `done`. The user merges the PR; `main` never changes any other way.
   - On fail: Status → `in-progress`, back to **implementer** with the failing step numbers.

Testing is manual (no XCTest target); see `.claude/rules/guardrails.md` §3.

```
┌───────────────────────────────┐
│      Main Session             │
└──────────────┬────────────────┘
               ▼
┌───────────────────────────┐
│         planner           │◄────────┐
└────────────┬──────────────┘         │
             ▼                        │ [RE-PLAN REQUEST]
┌───────────────────────────┐         │
│        implementer        │─────────┘
└────────────┬──────────────┘
             ▼
┌───────────────────────────┐
│       code-reviewer       │──(CHANGES_REQUESTED)──► implementer
└────────────┬──────────────┘
             ▼ (APPROVED)
┌───────────────────────────┐
│    git-agent: commit+PR   │
└────────────┬──────────────┘
             ▼ (user runs Manual Test Steps)
      pass → git-agent: finish → user merges PR
      fail → implementer
```

## Source of truth

- Architecture, phases, code skeleton, manual test checklist: `Project.md`
- Hard constraints every agent must satisfy: `.claude/rules/guardrails.md`
- Required technical background: `docs/skills.md`
