# Multi-Agent Workflow & Collaboration Pipeline

## 1. Primary Orchestrator (Main Agent)
- **Role**: Coordinates the development cycle, routes outputs between sub-agents, and enforces workflow continuity.
- **Execution Loop**:
  1. Hand off task specification to **Planning Agent**.
  2. Send implementation requirements to **Code Implementer Agent**.
     - *Feedback Trigger*: If the Implementer flags an ambiguity, architecture gap, or missing requirement, execution halts and returns to step 1.
  3. Pass written code to **Code Reviewer Agent**.
     - If changes are requested, route back to **Code Implementer Agent**.
  4. Once approved, send artifacts to **Git Agent** for branch management, commit, push, and PR creation.

```
┌───────────────────────────┐
│     Main Orchestrator     │
└─────────────┬─────────────┘
              ▼
┌───────────────────────────┐
│       Plan & Review       │◄────────┐
└─────────────┬─────────────┘         │ (Re-plan needed)
              ▼                       │
┌───────────────────────────┐         │
│      Code Implementer     │─────────┘
└─────────────┬─────────────┘
              ▼
┌───────────────────────────┐
│       Code Reviewer       │──(Revisions)──► [Implementer]
└─────────────┬─────────────┘
              ▼ (Approved)
┌───────────────────────────┐
│         Git Agent         │
└───────────────────────────┘
```

---

## 2. Sub-Agent Definitions

### Agent A: Plan & Review Agent
- Break project requirements into distinct technical milestones and file-level tasks.
- Review proposed changes against macOS architectural best practices.
- Revise task plans whenever the Code Implementer encounters dead-ends or unhandled edge cases.
- **Deliverables**: Milestone specifications, task checklists, architectural notes.

### Agent B: Code Implementer Agent
- Implement production Swift code adhering precisely to the active plan in `Project.md`.
- Run `swift build` and `make bundle`; verify the bundle launches.
- **Self-Evaluation Hook**: On a design flaw, missing API, or platform incompatibility, produce a `[RE-PLAN REQUEST]` and yield to the Orchestrator.
- **Deliverables**: Swift sources, `Package.swift`, `Support/Info.plist`, `Makefile`.

### Agent C: Code Reviewer Agent
- Verify memory management (no retain cycles in notification observers).
- Verify all state is `@MainActor`; no GCD/locks.
- Check the zero-external-dependency rule and every guardrail.
- **Deliverables**: `APPROVED` or `CHANGES_REQUESTED` with specific file/line requests.

### Agent D: Git Agent
- Manage feature branches (`feature/<milestone-name>`).
- Stage changes, write conventional commit messages (`feat:`, `fix:`, `refactor:`).
- Push branches and create Pull Requests with summary checklists.
- **Deliverables**: Git commands, commit hashes, PR descriptions.

Manual testing on the developer's machine replaces the automated test stage.
