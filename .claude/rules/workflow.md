# Development Workflow (Main Session as Orchestrator)

The main Claude session coordinates the cycle below, routing work between the subagents defined in `.claude/agents/`. Subagents never call each other directly; every hand-off goes through the main session.

## Execution Loop (batch mode, stacked PRs)

0. Create `tasks/NN-<slug>.md` from `tasks/TEMPLATE.md` (rules in `CLAUDE.md`). **git-agent** `start` → creates the task's branch — from `main` if every earlier task is `done`, otherwise from the newest unmerged task's branch (stacked) — and fills *Branch*. Every agent below receives the task file path and reads it before acting.
1. **planner** → fills *Goal*, *Spec*, *Test Steps* (each step tagged `ai` or `user`). Status → `planned`.
2. **implementer** → fills *Implementation Notes*. Status → `in-progress`.
   - `[RE-PLAN REQUEST]` → Status `blocked` with reason, back to step 1.
3. **code-reviewer** → fills *Review*. Status → `in-review`.
   - `CHANGES_REQUESTED` → back to **implementer** with the review notes.
4. On `APPROVED`, the main session runs every `ai` Test Step on this machine and fills *Actual* / *Result* for them. Any `ai` failure → back to **implementer**.
5. **git-agent** `commit` → commits code + task file, pushes, opens the PR (base = parent branch) with the task's *Testing notes* in the body, fills *PR*. Status → `pr-open`. Main session appends the task's `user` steps to `tasks/TEST-PLAN.md`.
6. **Continue to the next task without waiting.** The user reviews, runs the `user` steps, and merges at the PR. When a parent PR is merged, GitHub retargets the child to `main`; when a parent PR changes after review, **git-agent** `restack` rebases every child branch.
7. A review comment or failed `user` step on an open PR is handled as a new `fix/` task stacked on top of the current tip, or — if the PR is still the tip — as a follow-up commit on that branch.

Testing: `ai` steps run by the main session before the PR opens; `user` steps by the human at the PR. No XCTest target; see `.claude/rules/guardrails.md` §3.

```
┌───────────────────────────────┐
│      Main Session             │   for each task, in order:
└──────────────┬────────────────┘
               ▼
       git-agent: start  (branch stacked on previous task)
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
       main session runs `ai` test steps ──(fail)──► implementer
             ▼ (pass)
       git-agent: commit + PR  ──►  next task
                                        ⋮
       user: review + `user` steps + merge, bottom of stack first
```

## Source of truth

- Architecture, phases, code skeleton, manual test checklist: `Project.md`
- Hard constraints every agent must satisfy: `.claude/rules/guardrails.md`
- Required technical background: `docs/skills.md`
