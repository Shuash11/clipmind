# Changelog

All notable changes to ClipMind are documented here.

## 1.38.1

### Export failure feedback
- A failed export now surfaces a message with the reason and a warning that the output file may be empty or incomplete, instead of silently returning to the export options. Cancelling an export stays silent (user-initiated).

### Note
- With file_picker 12+, choosing an export destination creates an empty placeholder at that path; the export replaces it with the final content on success.

## 1.38.0

### Dependency upgrade
- `flutter_secure_storage` 9.2.4 → 11.2.0 (Windows plugin 3.1.2 → 4.2.2, macOS/web platforms now via `flutter_secure_storage_darwin` and `flutter_secure_storage_web` 2.1.1). Retires the discontinued `flutter_secure_storage_macos` and `js` packages.
- The Windows plugin requires `win32` 6, so the win32-consuming packages moved in lockstep: `file_picker` 8.3.7 → 13.1.0 (federated rewrite: `pickFiles`/`pickFile`/`saveFile` call sites updated), `package_info_plus` 8.3.1 → 10.2.2, `wakelock_plus` 1.3.3 → 1.8.1 (transitive), `win32` 5.15.0 → 6.4.0.
- The Windows ATL workaround (`scripts/patch-atl.ps1`) now derives the plugin version from `pubspec.lock` instead of a hard-coded pin, so it follows future upgrades automatically.

### File picker note
- file_picker 12+ `saveFile` writes the given bytes to the chosen path; the export flow passes an empty payload and ffmpeg overwrites that placeholder with `-y`. Picking files and the app-version display are otherwise unchanged.

### No behavior changes
- The secure-storage API subset in use (`read`/`write`/`delete`/`deleteAll`) is unchanged; Windows storage keeps using the same DPAPI-encrypted `flutter_secure_storage.dat`, so existing stored credentials remain readable — no migration needed.

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
