---
name: acm-tools
description: Use when managing opencode session context during any workflow — context growth, recalling forgotten earlier messages, protecting critical state from compaction, loading reference docs, session errors, or aborted tool calls. Maps each ACM tool to the situation that triggers it.
---

# ACM Context Tools

The session has ACM (Agent Context Manager) tools for monitoring, compacting, protecting, and repairing conversation context. Invoke them situationally — never run them blindly. Always check `acm_info` first when unsure.

## Situation → tool

| Situation | Tool(s) | What it does |
| --- | --- | --- |
| Don't know how full context is, or what's using tokens | `acm_info` | Status dashboard: token usage %, message counts, structural breakdown (system prompt vs messages vs skills vs tool defs) |
| Context feels bloated; need to know *where* the bulk is | `acm_map`, then `acm_scan` | `acm_map`: message size distribution over time buckets. `acm_scan`: lists the heaviest messages, sorted, as prune candidates |
| Context is high (approaching ~60%+) and old history is no longer needed | `acm_info` → `acm_compact` | Sliding-window prune: keeps only the last N minutes/messages, drops the rest |
| Only specific messages are bloat (found via `acm_scan`) | `acm_prune` | Surgically compacts exactly those message IDs; leaves everything else intact |
| Idle/dormancy noise ("en veille" noop pairs) accumulated | `acm_prune_noops` | Auto-detects and prunes system idle-pairs older than 5 min; keeps 1 as evidence |
| Critical state must survive compaction (adviser audits, phase plans, contracts, user decisions) | `acm_pin` | Marks a message as permanent bedrock memory, re-injected after every compaction |
| A pinned message is no longer critical | `acm_unpin` | Removes protection so it can be compacted normally |
| Mark messages for later pin/compact without acting yet | `acm_mark` | Tags messages as `pinned` (protect) or `prune` (compact-ready) |
| Need external reference material in active context (API contract, ARCH.md, style rules) | `acm_load` | Loads a file or raw text as a pinned knowledge package that survives compaction |
| A loaded knowledge package is no longer needed | `acm_unload` | Unloads it by name/ID, freeing context |
| Need something from earlier in the session — especially *before* a compaction boundary | `acm_search` | Full-history search (substring or regex, filter by role); a wayback machine for forgotten context |
| Need the exact content of a specific earlier message | `acm_fetch` | Fetches a message by (partial) ID, with full parts |
| Something is broken: aborted tool calls, incomplete executions, weird session behavior | `acm_diagnose` | Detects session corruption and health issues; returns offending message IDs |
| A subagent (or your own) response is gibberish, garbled, cut-off, empty, or looped thinking-mode output | `acm_diagnose` → `acm_repair` (dry-run, then commit) → re-delegate — **do not stop the session** | Auto-fix flow (below): remove the corrupted message and continue as if it never happened |
| Corruption confirmed by diagnosis | `acm_repair` | Deletes the bad message IDs (dry-run by default — preview first, then commit) |
| Debugging what the model is actually seeing right now | `acm_snapshot` | Dumps the full current context payload to a JSON file |

## Rules

- **Check before acting**: run `acm_info` (and `acm_scan`/`acm_map` if unclear) before any compaction — never compact blind.
- **Protect before compacting**: `acm_pin` any critical context (current audit, phase plan, API contracts, adviser decisions) *before* running `acm_compact`.
- **Diagnose before repairing**: always `acm_diagnose` first; use `acm_repair` dry-run before deleting anything.
- **Prune surgically when possible**: prefer `acm_prune` on identified heavy messages over broad `acm_compact` when only a few messages are the problem.
- **Do not over-compact**: keep the most recent turns and the current task's delegation chain intact.
- **Report**: after a significant context operation (compact/repair), briefly report what was removed and the new context percentage to the user.
- **Never halt on gibberish**: a corrupted subagent response triggers the gibberish auto-fix flow automatically — repair and re-delegate without stopping the session or seeking approval.

## Gibberish auto-fix (never stop the session)

A gibberish/garbled/empty/aborted subagent response is a session-health issue, not a reason to halt. The orchestrator checks every subagent response automatically and heals it in place:

1. **Detect** — after each subagent response, sanity-check it: empty body, mojibake/encoding garbage, truncated mid-thought, **degenerate repetition loops (the same token/word repeated many times, e.g. `locklocklocklock…` — common with NVIDIA-hosted providers whose endpoints lock sampling params like frequency/presence penalty, making loops unbreakable client-side)**, or thinking-mode output that never resolves into a real answer. A response failing any of these checks is corrupted.
2. **Diagnose** — run `acm_diagnose`; expect an `aborted_message` (or similar) for the corrupted response.
3. **Repair** — run `acm_repair` with the diagnosed IDs, `dry_run: true` first to preview, then `dry_run: false` to commit.
4. **Verify** — re-run `acm_diagnose` until clean (0 errors).
5. **Continue** — re-delegate the same task to the same subagent (continue its session) with the same context-full prompt. Do not stop the session, do not ask the user, do not restart — just resume.

If gibberish persists after two repair cycles, report the recurring pattern to the user with the diagnosis evidence — that is the only case where escalation is allowed.

## Typical flows

- **Context creeping up mid-workflow**: `acm_info` → `acm_pin` (protect current audit/plan) → `acm_compact` (keep recent) → report new %.
- **Recalling a forgotten earlier decision**: `acm_search` (keyword/regex) → `acm_fetch` (full message).
- **Session misbehaving**: `acm_diagnose` → review IDs → `acm_repair` dry-run → `acm_repair` commit → re-run `acm_diagnose` to confirm clean.
- **Starting a long phase**: `acm_load` the phase's reference docs so they survive compaction through the phase.
