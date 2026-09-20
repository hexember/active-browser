
## Instructions:
- Think critically and then give direct answers

## Task tracking (one task = one PR)
- Every task gets exactly one file in `tasks/`, named `NN-<slug>.md` (zero-padded, sequential), copied from `tasks/TEMPLATE.md` **before** any planning or code is written. One task produces exactly one PR.
- A task never spans phases. A phase may be split into several tasks when the pieces are independently reviewable; `Project.md` §3 lists the suggested split.
- The task file is the shared state between agents. Each agent reads it first and writes only to its own section: `planner` → Spec + Test Steps; `implementer` → Implementation Notes; `code-reviewer` → Review; `git-agent` → Branch / PR. Never rewrite another agent's section; append a dated note if something changes.
- `Status:` at the top is the single source of truth: `planned` → `in-progress` → `in-review` → `pr-open` → `done` (user merged), or `blocked` (with reason). The main session updates it at every hand-off; `done` is set only when the PR is merged.
- Tasks run strictly sequentially. The next task starts only after the current task's PR is open. Before starting, `ls tasks/` and read every task that is not `done` — the new branch stacks on the newest unmerged one.

## Batch mode: do not wait for the user between tasks
- The user reviews and tests at the PR, not in chat. After a PR is open, continue to the next task.
- Before opening a PR, run every Test Step marked `ai` yourself on this machine (build, `make install`, `lsregister` checks, `open <url>` routing checks) and record the actual result in the task file and PR body. Steps marked `user` are the only ones left for the human.
- Every PR description carries a **Testing notes** section: preconditions, the `user` steps as a table with expected results, and the reset step. Copy it from the task file.
- Maintain `tasks/TEST-PLAN.md`: append each PR's `user` steps in merge order. At the end of the run, hand the user that file as the single consolidated checklist.
- Pause for the user only when a `user` step blocks all further verification (currently one case: macOS's "set as default browser" confirmation dialog). Ask once, keep building everything that does not depend on it, and mark dependent `ai` steps as `not run — needs user step N`.
