
## Instructions:
- Think critically and then give direct answers

## Task tracking (one task = one PR)
- Every task gets exactly one file in `tasks/`, named `NN-<slug>.md` (zero-padded, sequential), copied from `tasks/TEMPLATE.md` **before** any planning or code is written. One task produces exactly one PR.
- A task never spans phases. A phase may be split into several tasks when the pieces are independently reviewable; `Project.md` §3 lists the suggested split.
- The task file is the shared state between agents. Each agent reads it first and writes only to its own section: `planner` → Spec + Test Steps; `implementer` → Implementation Notes; `code-reviewer` → Review; `git-agent` → Branch / PR. Never rewrite another agent's section; append a dated note if something changes.
- `Status:` at the top is the single source of truth: `planned` → `in-progress` → `in-review` → `pr-open` → `done` (user merged), or `blocked` (with reason). The main session updates it at every hand-off; `done` is set only when the PR is merged.
- Tasks run strictly sequentially. The next task starts only after the current task's PR is open. Before starting, `ls tasks/` and read every task that is not `done` — the new branch stacks on the newest unmerged one.

## Running a task
- Run `/next-task [scope]` to take one task from task file to open PR. It stops after the PR; nothing starts the next task automatically.
- Outside `/next-task`, do only what the user asked — do not start the task pipeline on your own.
