# Verifies that the Windows release output contains the runtime-critical files
# that the installer and portable ZIP packaging rely on (see
# installer/clipmind.iss and .github/workflows/release.yml).
#
# Called from .github/workflows/build.yml and .github/workflows/release.yml
# after `flutter build windows --release`, before any artifact is uploaded or
# packaged. Windows-only; uses Write-Output for diagnostics (never Write-Error,
# so that a CI shell with $ErrorActionPreference='Stop' cannot abort the
# diagnostic listing). Exits 1 when a required file is missing or zero-byte.

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
exit 0
