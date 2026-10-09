# Changelog

All notable changes to ClipMind are documented here.

## 1.42.6

### Text-overlay escaping fix
- Overlay text containing apostrophes, colons, brackets, commas, semicolons or backslashes now parses and renders exactly as typed, and leading/trailing whitespace is preserved (previously some forms failed to parse or silently mis-rendered).
- Text containing `%` no longer renders blank: overlay text uses verbatim expansion, so percent signs and every other character print literally.

## 1.42.5

### Text-overlay export fix
- Text-overlay export is fixed: Windows font paths are now correctly escaped at both filtergraph levels, so FFmpeg parses the unquoted `fontfile` option even when the path contains a drive colon, spaces, apostrophes, brackets, commas or semicolons (previously failed with `No option name near ...`).

## 1.42.4

### Keyboard-operable save retry
- The status bar's "Changes not saved" pill is fully keyboard-operable: Tab focuses it, Enter or Space retries the save, and a visible focus ring marks the focused state (WCAG 2.4.7; the accent ring holds at least 3:1 contrast against both adjacent surfaces).
- The failure reason is exposed to assistive tech as the button's value alongside the tooltip, so screen-reader users hear why the save failed.
- A failed retry keeps the pill visible with the refreshed reason, and the keyboard retry paths (success and failure) are locked by widget tests.

## 1.42.3

### YouTube import safety
- YouTube downloads now land in a unique per-import folder under the imports directory, so two imports can never share a filename.
- A different video with the same title can no longer resolve to an earlier import's file, and a re-import never silently reuses an old file — yt-dlp always downloads into a spotless folder.
- Failed, stalled, or cancelled imports leave no partial file or leftover folder behind.

## 1.42.2

### Direct-URL import safety
- Direct-URL imports now land in a unique per-import folder and keep the server's real filename (Content-Disposition or URL, sanitized), so the project and clip show the actual media name instead of `direct_download.mp4`.
- Two direct imports can no longer share a file: a second import never overwrites a previous project's source media.
- Links that serve a web page instead of a video (login walls, preview pages, error documents) are rejected with a clear message and leave no partial file behind; cancelled and failed downloads clean up after themselves.

## 1.42.1

### Project-save durability
- Project documents are now written safely (temp file + same-volume rename) and saves fail loudly instead of being swallowed; a failed write never leaves a phantom recent-project row, so a restart can no longer open an empty timeline for a project whose document is missing.
- A failed save surfaces a "Changes not saved" pill in the editor status bar with the reason in its tooltip; clicking it retries the save, and the next successful save clears it. A successful project load clears stale failures too.
- Creating or importing into a project from the hub now distinguishes a failed disk write ("Could not save the project to disk.") from an import failure, instead of showing generic copy for every error.

## 1.42.0

### Agent tagging and markers
- The agent can now create, rename, recolor and delete tags; assign and unassign tags to assets or clips; and create, update and delete timeline markers. These edits run through the same undoable, revision-guarded transactions as manual tagging edits and persist with agent-sourced history records.
- A new core read tool (`list_tags_and_markers`) exposes tag, marker and asset IDs plus existing tag assignments, so the agent can discover what to edit before touching it.
- The eight tag/marker commands are deferred tools: the agent unlocks them on demand with `load_tools`, keeping the per-round tool payload bounded.

Note: the document-based tagging layer is still being wired into the editor; until that composition lands, these agent tools return an actionable "tagging unavailable" error rather than modifying state.

## 1.41.0

### On-demand tool loading
- The agent now loads specialized tools on demand; initial tool exposure is curated. Each round offers the 14 core tools plus any deferred tools already loaded, instead of all 20 at once.
- A new reserved `load_tools` meta-tool unlocks deferred tools for the next round. Core: the six ground-truth read tools and the eight most-used edits (trim, cut, merge, speed, mute, overlay text, volume, brightness). Deferred: resize, rotate, extract audio, burn captions, add transition, apply effect.
- Load requests are validated: unknown, already-available and core names return actionable errors listing the valid deferred names. Loads are bounded to two per run, and a load round does not consume one of the four operation rounds (total model rounds stay ≤ 6).
- The system prompt now renders its tool list from the catalog (no hard-coded list) and documents the loader rule.

## 1.40.1

### Security hardening
- Gen A provider `400` error messages (Anthropic, Gemini) now redact the resolved API key when a provider response body echoes it back, so keys remain impossible to leak through error strings.
- New key-egress canary suite pins every key path across both provider stacks (Gen B profiles/adapters/redactor and the Gen A legacy bridge): the canary sentinel must appear only in the intended request header/query and never in persisted metadata, failures, migrations, `toString()` output, or UI.

## 1.40.0

### Model picker search
- The agent chat's model picker gains a search field under the profile header. Typing filters discovered and manual models immediately — case-insensitive, matching model ID, display name, or org group — while preserving group ordering and omitting empty groups.
- A clear button on the field restores the full list, a "No models match" state appears when nothing matches, and the manual model ID entry stays usable throughout.

### Anthropic model discovery
- Anthropic dedicated profiles can now discover models via `/v1/models`; the picker's auto-discovery path includes them, so opening the picker lists the account's available Claude models without manual entry.

## 1.39.0

### YouTube import experience
- Determinate download progress in the hub's URL bar (live bar + percentage) for both YouTube (yt-dlp) and direct-link downloads, driven by the services' progress streams.
- Cancel an in-flight download from the URL bar; the bar returns to idle with a single "Download cancelled" notice.
- yt-dlp availability preflight for YouTube links: when the binary is missing, a guidance dialog explains the official standalone install (`yt-dlp.exe` on Windows, `yt-dlp_macos` on macOS), notes that pip installs may also need a JavaScript runtime (deno recommended), and links to the official releases page.
- Host-based URL routing (`youtube.com`/`youtu.be` plus subdomains) replaces substring matching, so look-alike domains take the direct-download path.
- The runtime "yt-dlp not found" message now matches the dialog guidance (standalone build on PATH; no settings reference and no winget assumption).

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
