# Consolidated Manual Test Plan

Append-only, in merge order. Each entry is the `user` rows from that task's Test Steps. Run top to bottom after merging the corresponding PRs; reset steps at the end of each block.

<!-- entries added by the main session when each PR opens -->

---

## PR #3 — Task 01: Core model (`feature/core-model`, base `main`)

No `user` steps. Phase 1 is build-and-inspection only; all 8 test steps were `ai` and ran green before the PR opened. Nothing for you to run here.

---

## PR #4 — Task 02: Events & routing (`feature/events-routing`, base `feature/core-model`)

No `user` steps. Phase 2 is still build-and-inspection only — there is no `.app` bundle until task 03, so nothing is clickable. All 12 test steps were `ai` and ran green before the PR opened.

Worth knowing when you review this PR: review round 1 caught a blocking runtime defect — `@main` on an `NSApplicationDelegate` compiles but never installs the delegate, so `application(_:open:)` would never have fired and every URL would have been dropped. Fixed with an explicit `static func main()`; verified by disassembling the binary and by launching a throwaway probe bundle.
