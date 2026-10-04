---
name: grapify
description: Use when navigating, auditing, or planning changes to the ClipMind codebase: load the generated code-graph slices (docs/codegraph/) instead of scanning; read specific files only for details; regenerate with `dart run tool/grapify.dart` after structural changes; check the timestamp for staleness.
---

# Grapify

Navigate the ClipMind codebase by function instead of scanning it. The committed code-graph slices under `docs/codegraph/` index every layer at ~1 line per symbol with line refs — load the slices you need, then read specific files only for details.

## Rules

- Start navigation at `docs/codegraph/README.md` (per-layer file/line counts), then load only the slices you need (`core`, `data`, `domain`, `state`, `presentation`, `features`, `test`, `tool`).
- Never edit the slices — they carry a generated timestamp and DO NOT EDIT marker. Change the source, then regenerate.
- Regenerate with `dart run tool/grapify.dart` after any structural change (new files, renames, API moves).
- Check the README timestamp for staleness before trusting line refs.
- Relationships in the slices are `extends`/`implements`/`with` hints plus member line refs — a navigation aid, not a resolved call graph.
- Generated files (`*.g.dart`, `*.freezed.dart`) are excluded from every slice by design.
