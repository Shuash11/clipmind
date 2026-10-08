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
| `data` | 43 | 7,723 | `docs/codegraph/data.md` |
| `domain` | 24 | 7,288 | `docs/codegraph/domain.md` |
| `features` | 125 | 14,584 | `docs/codegraph/features.md` |
| `lib` | 2 | 81 | `docs/codegraph/lib.md` |
| `presentation` | 35 | 8,987 | `docs/codegraph/presentation.md` |
| `state` | 15 | 2,960 | `docs/codegraph/state.md` |
| `test` | 168 | 43,991 | `docs/codegraph/test.md` |
| `tool` | 2 | 621 | `docs/codegraph/tool.md` |

_Total: 428 files, 87,413 lines indexed._
