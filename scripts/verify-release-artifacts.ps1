# Verifies that the Windows release output contains the runtime-critical files
# that the installer and portable ZIP packaging rely on (see
# installer/clipmind.iss and .github/workflows/release.yml).
#
# Called from .github/workflows/build.yml and .github/workflows/release.yml
# after `flutter build windows --release`, before any artifact is uploaded or
# packaged. Windows-only; uses Write-Output for diagnostics (never Write-Error,
# so that a CI shell with $ErrorActionPreference='Stop' cannot abort the
# diagnostic listing). Exits 1 when a required file is missing or zero-byte.
#
# An optional first positional argument is the expected release tag (e.g.
# `verify-release-artifacts.ps1 v1.37.0`, passed by release.yml): the built
# clipmind.exe's Major.Minor.Build version parts must then match that tag.

param([string]$ExpectedVersion = '')

$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseDir = Join-Path $repoRoot 'build\windows\x64\runner\Release'
$requiredFiles = @('clipmind.exe', 'sqlite3.dll')

if (-not (Test-Path -LiteralPath $releaseDir -PathType Container)) {
    Write-Output "Release output not found: $releaseDir"
    Write-Output "Run 'flutter build windows --release' first."
    exit 1
}

$problems = @()
foreach ($name in $requiredFiles) {
    $path = Join-Path $releaseDir $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $problems += "MISSING: $name (expected at $path)"
    } elseif ((Get-Item -LiteralPath $path).Length -le 0) {
        $problems += "EMPTY (0 bytes): $name (expected at $path)"
    }
}

if ($problems.Count -gt 0) {
    Write-Output "Release artifact verification FAILED ($($problems.Count) problem(s)):"
    foreach ($problem in $problems) {
        Write-Output "  $problem"
    }
    Write-Output ""
    Write-Output "Contents of ${releaseDir}:"
    $entries = @(Get-ChildItem -LiteralPath $releaseDir -File -ErrorAction SilentlyContinue)
    if ($entries.Count -eq 0) {
        Write-Output "  (no files)"
    } else {
        foreach ($entry in ($entries | Sort-Object Name)) {
            Write-Output "  $($entry.Name) ($($entry.Length) bytes)"
        }
    }
    exit 1
}

foreach ($name in $requiredFiles) {
    $item = Get-Item -LiteralPath (Join-Path $releaseDir $name)
    Write-Output "OK: $($item.Name) ($($item.Length) bytes)"
}

if ($ExpectedVersion -ne '') {
    $tagVersion = $ExpectedVersion.TrimStart('v')
    if ($tagVersion -notmatch '^\d+\.\d+\.\d+$') {
        Write-Output "Release version verification FAILED: tag '$ExpectedVersion' is not in vX.Y.Z form (see docs/RELEASE.md tag convention)."
        exit 1
    }

    $vi = (Get-Item -LiteralPath (Join-Path $releaseDir 'clipmind.exe')).VersionInfo
    $exeVersion = "$($vi.FileMajorPart).$($vi.FileMinorPart).$($vi.FileBuildPart)"

    if ($exeVersion -ne $tagVersion) {
        Write-Output "Release version verification FAILED:"
        Write-Output "  Tag version: $tagVersion (from '$ExpectedVersion')"
        Write-Output "  Raw exe FileVersion: $($vi.FileVersion)"
        Write-Output "  Exe version (Major.Minor.Build): $exeVersion"
        exit 1
    }

    Write-Output "OK: exe version $exeVersion matches tag $ExpectedVersion"
}

exit 0
