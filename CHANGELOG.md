# Changelog

All notable changes to ClipMind are documented here.

## 1.37.0

### Dependency platform upgrade
- Drift 2.25 → 2.35.1; SQLite is now bundled by `package:sqlite3` 3.7.0 through Dart build hooks, replacing the EOL `sqlite3_flutter_libs` package.
- Freezed 2.5.8 → 4.0.2 (all 19 `@freezed` models migrated to `abstract` classes); json_serializable 6.9 → 6.14.1; json_annotation 4.9 → 4.12.0; build_runner 2.4 → 2.16.1.

### No behavior changes
- No API, JSON, or data-format changes; the database schema stays at v4.

### Build note
- The first `flutter build`/`flutter test` downloads the prebuilt, sha256-verified SQLite library from the `sqlite3` package's GitHub releases and caches it under `.dart_tool/hooks_runner/`; subsequent builds reuse the cache. Offline and mirror options are documented in `docs/RELEASE.md`.

## 1.36.4

### Update-flow fix
- Per-user installer: `PrivilegesRequired=lowest` — no UAC prompt; installs to `%LOCALAPPDATA%\Programs\ClipMind`.
- Started-marker handoff: the app exits only after the update script confirms it started; timeout surfaces an `UpdateStartException` dialog error instead of a silent failure.
- Observable scripts: PowerShell update steps log to `update.log` and write a result JSON (`success`/`failed` + reason + expectedVersion) to `{appSupport}\updates\`.
- Relaunch via HKCU registry (`InstallLocation`, with fallback to the old app directory) and temp-dir cleanup.
- New `update_result_reader.dart` surfaces failed-update SnackBar at startup; the update dialog passes `targetVersion`.

### Drive import removal
- Removed `googleapis`/`google_sign_in` dependencies; the import service is renamed to `UrlImportService` with Drive-link guidance and errors wired into the hub UI.

### Notes
- If you previously installed ClipMind to Program Files (administrator install), uninstall that old copy once via Windows Settings after updating — the new version installs per-user.
