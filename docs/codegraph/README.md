# ClipMind Code Graph (DO NOT EDIT)

Per-layer navigation slices — load only what you need (~1–4k tokens
each vs ~10–25k for reading the layer's files). Generated files
(`*.g.dart`, `*.freezed.dart`) are excluded from every slice.

Regenerate with `dart run tool/grapify.dart` after any structural
change (new files, renames, API moves). Output is fully deterministic,
so `git diff --exit-code -- docs/codegraph` detects staleness.

| Layer | Files | Lines | Slice |
| --- | --- | --- | --- |
| `core` | 14 | 1,168 | `docs/codegraph/core.md` |
| `data` | 41 | 6,618 | `docs/codegraph/data.md` |
| `domain` | 22 | 6,081 | `docs/codegraph/domain.md` |
| `features` | 124 | 14,332 | `docs/codegraph/features.md` |
| `lib` | 2 | 81 | `docs/codegraph/lib.md` |
| `presentation` | 34 | 8,512 | `docs/codegraph/presentation.md` |
| `state` | 13 | 2,762 | `docs/codegraph/state.md` |
| `test` | 149 | 35,972 | `docs/codegraph/test.md` |
| `tool` | 2 | 621 | `docs/codegraph/tool.md` |

_Total: 401 files, 76,147 lines indexed._
