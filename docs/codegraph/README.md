# ClipMind Code Graph (DO NOT EDIT)

Per-layer navigation slices — load only what you need (~1–4k tokens
each vs ~10–25k for reading the layer's files). Generated files
(`*.g.dart`, `*.freezed.dart`) are excluded from every slice.

Regenerate with `dart run tool/grapify.dart` after any structural
change (new files, renames, API moves). Output is fully deterministic,
so `git diff --exit-code -- docs/codegraph` detects staleness.

| Layer | Files | Lines | Slice |
| --- | --- | --- | --- |
| `core` | 14 | 1,178 | `docs/codegraph/core.md` |
| `data` | 41 | 6,656 | `docs/codegraph/data.md` |
| `domain` | 22 | 6,081 | `docs/codegraph/domain.md` |
| `features` | 124 | 14,332 | `docs/codegraph/features.md` |
| `lib` | 2 | 81 | `docs/codegraph/lib.md` |
| `presentation` | 34 | 8,538 | `docs/codegraph/presentation.md` |
| `state` | 13 | 2,762 | `docs/codegraph/state.md` |
| `test` | 150 | 36,292 | `docs/codegraph/test.md` |
| `tool` | 2 | 621 | `docs/codegraph/tool.md` |

_Total: 402 files, 76,541 lines indexed._
