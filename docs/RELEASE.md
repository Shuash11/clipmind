# Release Procedure

How to publish a ClipMind release. The Release workflow (`.github/workflows/release.yml`) does the heavy lifting — it triggers only on a tag push matching `v*`.

## Steps (in order)

1. **Bump pubspec** — set `version: X.Y.Z+<build>` in `pubspec.yaml` (per-push patch bump convention), then commit and push the app work.
2. **Tag the release** — `git tag vX.Y.Z` on the release commit and `git push origin vX.Y.Z`. Use the pubspec version **without** the build suffix (e.g., pubspec `1.36.4+2` → tag `v1.36.4`).
3. **Release workflow runs** — on `windows-latest` it: sets up Flutter, installs deps, applies the ATL patch, runs `flutter analyze` + `flutter test`, builds the Windows release, packages the portable ZIP, installs Inno Setup via choco and compiles `installer\clipmind.iss` (with `MyAppVersion` rewritten from the tag name), then creates the GitHub release with the installer `ClipMind-Setup-<ver>.exe` + ZIP `clipmind-windows-v<ver>.zip` as assets.
4. **Verify** — check the Release run is green and both assets are present. Each asset's `sha256` digest is populated server-side by GitHub on upload (no emission step needed); the verifier contract is pinned by `test/unit/updates/release_digest_live_gate_test.dart`.

## Tag convention (evolved)

- Release tags match the pubspec version with the build number excluded: `vX.Y.Z` for pubspec `X.Y.Z+<build>`.
- Early repo history used minor-only tags (`vX.Y.0`); current convention tags every release version, including patch releases (first patch tag: `v1.36.4`).

## Update-gate coupling

The in-app update checker (`github_release_checker.dart`) fetches `releases/latest`, uses the first asset ending in `.exe` as the setup asset, and compares versions with the `+build` suffix stripped. Because the tag must equal the built exe's version resource (which comes from pubspec), tagging a version that does not match the pubspec version breaks both update gates (the `isNewer` comparison and the result reader's `expectedVersion` match) and can re-create an update loop. Always tag the pubspec version.

## Native SQLite build hook (since 1.37.0)

Since 1.37.0 the app gets SQLite from `package:sqlite3` 3.x, which bundles a native SQLite through Dart build hooks — the EOL `sqlite3_flutter_libs` platform package is gone. On the first `flutter build`/`flutter test` after a fresh checkout or `flutter clean`, the hook downloads a prebuilt, sha256-verified `sqlite3.dll` from the `sqlite3` package's GitHub releases and caches it in `.dart_tool/hooks_runner/shared/sqlite3/build/download-<hash>/`. Later builds and tests reuse that cache, so only a fresh checkout or a clean build needs network access.

For air-gapped builds or an internal mirror, point the hook at another artifact host with the `url_pattern` user define in `pubspec.yaml` (or use a system SQLite via `source: system`):

```yaml
hooks:
  user_defines:
    sqlite3:
      source: sqlite3
      url_pattern: "https://artifacts.example.org/$RELEASE_TAG/$FILENAME"
```

Upstream hook documentation: https://github.com/simolus3/sqlite3.dart/blob/main/sqlite3/doc/hook.md

No packaging change is needed: the hook output lands in `build\windows\x64\runner\Release\` next to `clipmind.exe`, and the installer (`installer\clipmind.iss` packages `Release\*` with `recursesubdirs`) plus the release ZIP (`Compress-Archive Release\*`) pick it up automatically.

## Exceptions

- Do **not** bump pubspec when tagging an already-pushed version state (e.g., docs-only release commits) — the tag must match the version the exe will actually be built with.
