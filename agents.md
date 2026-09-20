# Multi-Agent Workflow & Collaboration Pipeline

## 1. Primary Orchestrator (Main Agent)
- **Role**: Coordinates the development cycle, routes outputs between sub-agents, and enforces workflow continuity.
- **Execution Loop**:
  1. Hand off task specification to **Planning Agent**.
  2. Forward the verified plan to **Test Writer Agent**.
  3. Send implementation requirements and test constraints to **Code Implementer Agent**.
     - *Feedback Trigger*: If the Implementer flags an ambiguity, architecture gap, or missing requirement, execution halts and returns to step 1 (**Planning Agent**).
  4. Pass written code and tests to **Code Reviewer Agent**.
     - If changes are requested, route back to **Code Implementer Agent**.
  5. Once approved, send artifacts to **Git Agent** for branch management, commit, push, and PR creation.


┌───────────────────────────────┐
│      Main Orchestrator        │
└──────────────┬────────────────┘
▼
┌───────────────────────────┐
│       Plan & Review       │◄────────┐
└────────────┬──────────────┘         │
▼                        │
┌───────────────────────────┐         │ (Re-plan needed)
│     Test Case Writer      │         │
└────────────┬──────────────┘         │
▼                        │
┌───────────────────────────┐         │
│      Code Implementer     │─────────┘
└────────────┬──────────────┘
▼
┌───────────────────────────┐
│       Code Reviewer       │──(Revisions)──► [Implementer]
└────────────┬──────────────┘
▼ (Approved)
┌───────────────────────────┐
│         Git Agent         │
└───────────────────────────┘



---

## 2. Sub-Agent Definitions

### Agent A: Plan & Review Agent
- **Responsibilities**:
  - Break project requirements into distinct technical milestones and file-level tasks.
  - Review proposed changes against macOS architectural best practices.
  - Revise existing task plans whenever the Code Implementer encounters technical dead-ends or unhandled edge cases.
- **Output Deliverables**: Structured milestone specifications, updated task checklists, and architectural notes.

### Agent B: Test Case Writer Agent
- **Responsibilities**:
  - Author `XCTest` suites before or in tandem with implementation (TDD).
  - Mock Launch Services queries and `NSWorkspace` event streams.
  - Cover edge cases: rapid app switching, bundle ID changes, closed running instances, and uninstalled browsers.
- **Output Deliverables**: Complete `Tests/ActiveBrowserRouterTests/*.swift` files.

### Agent C: Code Implementer Agent
- **Responsibilities**:
  - Implement production Swift code adhering precisely to the active plan.
  - Run local builds (`swift build`) and test execution (`swift test`).
  - **Self-Evaluation Hook**: If a design flaw, missing API capability, or platform incompatibility is discovered, produce a `[RE-PLAN REQUEST]` message detailing the obstacle, and yield back to the Main Orchestrator.
- **Output Deliverables**: Swift source code, `Package.swift`, `Info.plist`, and `Makefile`.

### Agent D: Code Reviewer Agent
- **Responsibilities**:
  - Verify memory management (avoid retain cycles in notification observers).
  - Audit thread safety (locking strategies, actor isolations, concurrent read/write queues).
  - Check compliance with the zero-external-dependency rule.
  - Ensure guardrails are satisfied.
- **Output Deliverables**: Code review verdict (`APPROVED` or `CHANGES_REQUESTED`) with specific file and line diff requests.

### Agent E: Git Agent
- **Responsibilities**:
  - Manage feature branches (`feature/<milestone-name>`).
  - Stage changes, generate conventional commit messages (`feat:`, `fix:`, `refactor:`).
  - Push branches and create clean Pull Requests with summary checklists.
- **Output Deliverables**: Git CLI commands, commit hashes, and PR markdown descriptions.
