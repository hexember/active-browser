
## Instructions:
- Think critically and then give direct answers

## Task tracking (one markdown file per task)
- Every unit of work — a phase, a feature, a bug fix — gets exactly one file in `tasks/`, named `NN-<slug>.md` (zero-padded, sequential), copied from `tasks/TEMPLATE.md` **before** any planning or code is written.
- The task file is the shared state between agents. Each agent reads it first and writes only to its own section: `planner` → Spec + Manual Test Steps; `implementer` → Implementation Notes; `code-reviewer` → Review; `git-agent` → Branch / PR. Never rewrite another agent's section; append a dated note if something changes.
- The `Status:` line at the top is the single source of truth for what is done and what is next. Values: `planned` → `in-progress` → `in-review` → `awaiting-manual-test` → `done`, or `blocked` (with reason). The main session updates it at every hand-off.
- Before starting any task, `ls tasks/` and read the most recent non-`done` file. Do not open a second task while one is `in-progress` or `in-review`.
- A task is `done` only after the user has executed the Manual Test Steps and the result is recorded in the task file.

## Phase completion → hand the user test steps
- When the last task of a phase reaches `awaiting-manual-test`, stop and give the user the **Verify** checklist for that phase from `Project.md` §3 as a numbered list they can run, plus the reset step if the phase changes system state (default browser, login item). Do not begin the next phase until the user reports the result.
