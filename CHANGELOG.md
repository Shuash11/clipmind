# Changelog

All notable changes to ClipMind are documented here.

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
