---
name: self-improvement
description: Use when the user manually invokes the self-improvement workflow. A continuous improvement loop — the Adviser audits the app or system, improvements are implemented, reviewed, and pushed, then the Adviser runs again. The loop does not stop until the user stops it.
---

# Self Improvement

A continuous improvement loop for the app or system. The Orchestrator runs this workflow only when the user manually invokes it.

## Loop

1. **Audit** — The Adviser runs first and scans the project for improvement opportunities: features, UI/UX, security, data structure, logic, performance, API contracts, tests, and maintainability. It returns a ranked audit.
2. **Focus** — The Adviser picks the single highest-impact improvement as one task and plans it into phases. It gives the Orchestrator one task at a time; never many tasks.
3. **Delegate** — The Orchestrator delegates the current phase to the appropriate subagent (frontend, middle-end, backend). The next phase starts only after the current one passes.
4. **Review gate** — The Reviewer reviews the completed phase and returns PASS or FAIL. The Reviewer must run the web searches the Adviser specified for the phase and cite sources in its findings. FAIL enters a fix-review cycle until PASS.
5. **Push confirmation** — After PASS, the Orchestrator delegates the reviewed work back to the Adviser for confirmation. The Adviser decides whether it is pushable; only an Adviser approval allows the push. A rejection returns to the fix-review cycle or the current phase.
6. **Push** — After the Adviser's approval, the Orchestrator delegates the push to the `agent-push` agent, which applies the `git-push` skill (app-only files, no secrets) and triggers all GitHub workflows if any.
7. **Next phase or new audit** — After the phase passes (and is pushed), the Adviser delivers the next phase. When all phases of the task are done, the Adviser runs again and looks for new improvements. The loop continues and does not stop on its own.

## Rules

- The Orchestrator delegates only and reports progress to the user after every cycle.
- Follow adviser audits exactly; do not invent improvements on your own.
- Never skip the review gate; do not push work that has not passed.
- Never skip the Adviser's push confirmation; do not push work the Adviser has not approved.
- Every Adviser decision is supreme. The user may only suggest; never ask the user for approval — all approvals come from the Adviser on the user's behalf. Apply user suggestions only where the Adviser agrees.
- Do not stop the loop on your own; only the user stops the workflow.
- Track each cycle with the todo tool: audit items in progress, done, and remaining.
