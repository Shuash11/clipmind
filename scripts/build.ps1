<#
.SYNOPSIS
  ClipMind release build verification script.
  Checks prerequisites, runs analysis, runs tests, builds for Windows and macOS.

.DESCRIPTION
  This script validates the project is ready for release by:
    1. Checking prerequisites (flutter, ffmpeg, dart)
    2. Running flutter analyze
    3. Running flutter test
    4. Building for Windows (--release)
    5. Building for macOS (--release, gracefully handled if no macOS SDK)

.PARAMETER SkipBuild
  Skip the build steps (analysis + tests only).

.PARAMETER SkipMacOS
  Skip macOS build step entirely.

.EXAMPLE
  .\scripts\build.ps1           # Full release verification
  .\scripts\build.ps1 -SkipBuild # Lint and test only
#>

param(
  [switch]$SkipBuild,
  [switch]$SkipMacOS
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$ExitCode = 0

function Write-Step($Title) {
  Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
  Write-Host "  $Title" -ForegroundColor Cyan
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
}

function Check-Command($Name) {
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $cmd) {
    Write-Host "✖ $Name not found. Please install it and ensure it is on your PATH." -ForegroundColor Red
    return $false
  }
  Write-Host "✔ $Name found at $($cmd.Source)" -ForegroundColor Green
  return $true
}

function Invoke-Step($Command, $Label) {
  Write-Host "→ $Label..." -ForegroundColor Yellow
  try {
    $output = Invoke-Expression $Command
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
      Write-Host "✖ $Label FAILED (exit code: $LASTEXITCODE)" -ForegroundColor Red
      Write-Host $output -ForegroundColor Red
      return $false
    }
    Write-Host "✔ $Label passed" -ForegroundColor Green
    return $true
  } catch {
    Write-Host "✖ $Label FAILED with error: $_" -ForegroundColor Red
    return $false
  }
}

# ── Step 0: Prerequisites ──────────────────────────────────
Write-Step "Phase 0 — Prerequisites"

$allOk = $true
$allOk = (Check-Command "flutter") -and $allOk
$allOk = (Check-Command "dart") -and $allOk
# ffmpeg is optional — only needed for integration tests
$null = Check-Command "ffmpeg"

if (-not $allOk) {
  Write-Host "`n✖ Prerequisites missing. Aborting." -ForegroundColor Red
  exit 1
}

# ── Step 1: Flutter Analyze ────────────────────────────────
Write-Step "Phase 1 — Static Analysis"
Push-Location $ProjectRoot
try {
  $analyzeOk = Invoke-Step "flutter analyze" "flutter analyze"
  if (-not $analyzeOk) { $ExitCode = 1 }
} finally { Pop-Location }

# ── Step 2: Flutter Test ───────────────────────────────────
Write-Step "Phase 2 — Unit & Widget Tests"
Push-Location $ProjectRoot
try {
  $testOk = Invoke-Step "flutter test" "flutter test"
  if (-not $testOk) { $ExitCode = 1 }
} finally { Pop-Location }

if ($SkipBuild) {
  Write-Host "`n⏭ Build skipped (--SkipBuild)." -ForegroundColor Yellow
  goto :summary
}

# ── Step 3: Build Windows Release ──────────────────────────
Write-Step "Phase 3 — Windows Release Build"
Push-Location $ProjectRoot
try {
  $winOk = Invoke-Step "flutter build windows --release" "flutter build windows --release"
  if (-not $winOk) { $ExitCode = 1 }
} finally { Pop-Location }

# ── Step 4: Build macOS Release (optional) ─────────────────
if (-not $SkipMacOS) {
  Write-Step "Phase 4 — macOS Release Build"
  # Check if we're on macOS with Xcode available
  $isMac = $IsMacOS -or (Get-Command "xcrun" -ErrorAction SilentlyContinue)
  if ($isMac) {
    Push-Location $ProjectRoot
    try {
      $macOk = Invoke-Step "flutter build macos --release" "flutter build macos --release"
      if (-not $macOk) { $ExitCode = 1 }
    } finally { Pop-Location }
  } else {
    Write-Host "⏭ Not on macOS — skipping macOS build." -ForegroundColor Yellow
  }
} else {
  Write-Host "⏭ macOS build skipped (--SkipMacOS)." -ForegroundColor Yellow
}

# ── Summary ─────────────────────────────────────────────────
:summary
Write-Step "Build Summary"
if ($ExitCode -eq 0) {
  Write-Host "✔ All phases completed successfully." -ForegroundColor Green
} else {
  Write-Host "✖ Some phases have failures. Review output above." -ForegroundColor Red
}
exit $ExitCode
