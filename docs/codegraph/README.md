# ClipMind Code Graph (DO NOT EDIT)

Per-layer navigation slices — load only what you need (~1–4k tokens
each vs ~10–25k for reading the layer's files). Generated files
(`*.g.dart`, `*.freezed.dart`) are excluded from every slice.

Regenerate with `dart run tool/grapify.dart` after any structural
change (new files, renames, API moves). Output is fully deterministic,
so `git diff --exit-code -- docs/codegraph` detects staleness.

| Layer | Files | Lines | Slice |
| --- | --- | --- | --- |
| `core` | 13 | 1,016 | `docs/codegraph/core.md` |
| `data` | 40 | 6,412 | `docs/codegraph/data.md` |
| `domain` | 22 | 5,961 | `docs/codegraph/domain.md` |
| `features` | 124 | 14,332 | `docs/codegraph/features.md` |
| `lib` | 2 | 81 | `docs/codegraph/lib.md` |
| `presentation` | 32 | 7,973 | `docs/codegraph/presentation.md` |
| `state` | 13 | 2,266 | `docs/codegraph/state.md` |
| `test` | 138 | 32,561 | `docs/codegraph/test.md` |
| `tool` | 2 | 621 | `docs/codegraph/tool.md` |

_Total: 386 files, 71,223 lines indexed._
