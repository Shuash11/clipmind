# ClipMind logo generator.
#
# Generates all branded image assets from one embedded SVG design:
#   - windows\runner\resources\app_icon.ico      (EXE icon + Inno SetupIconFile)
#   - windows\runner\resources\wizard_image.png  (Inno Setup large wizard image, 480x918)
#   - windows\runner\resources\wizard_small.png  (Inno Setup small wizard image, 116x116)
#   - assets\icons\clipmind_logo.png             (1024x1024 master logo asset)
#
# Design: ClipMindColors.accentPrimary violet (#7C6CF6) rounded square with a
# white clapperboard glyph (Material Icons 'movie' path, Apache 2.0), matching
# the hub tile design language (rounded square + movie glyph).
#
# Requires ImageMagick 7 (magick) with the rsvg and freetype delegates, and
# assets\fonts\montserrat_regular.ttf for the wizard wordmark.
#
# Usage: powershell -ExecutionPolicy Bypass -File tool\generate_logo.ps1

$ErrorActionPreference = 'Stop'

# --- Brand constants ---------------------------------------------------------
$accentColor = '#7C6CF6'   # ClipMindColors.accentPrimary
$glyphColor  = '#FFFFFF'
# Clapperboard glyph path (Material Icons 'movie', filled, 24x24 viewBox).
$glyphPath   = 'M18 4l2 4h-3l-2-4h-2l2 4h-3l-2-4H8l2 4H7L6 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V4h-4z'

# --- SVG builders -------------------------------------------------------------

function New-IconSvg {
  # Violet rounded square with the white film mark centered.
  # Corner radius ~22% of the side; the glyph fills ~55% of the canvas width.
  param([int]$Size)

  # Glyph metrics inside the 24x24 viewBox: bbox x 2..22 (w 20), y 4..20 (h 16).
  # Centering the glyph therefore needs translate = Size/2 - 12 * scale.
  $s      = $Size * (28.0 / 1024.0)
  $offset = $Size / 2.0 - 12.0 * $s
  $radius = [Math]::Round($Size * 0.22)

  return @"
<svg xmlns="http://www.w3.org/2000/svg" width="$Size" height="$Size" viewBox="0 0 $Size $Size">
  <rect width="$Size" height="$Size" rx="$radius" fill="$accentColor"/>
  <g transform="translate($offset,$offset) scale($s)" fill="$glyphColor">
    <path d="$glyphPath"/>
  </g>
</svg>
"@
}

function New-WizardSvg {
  # 480x918 full-bleed violet background; the mark sits centered in the upper
  # half. The "ClipMind" wordmark is composited separately with magick -font.
  param()

  # Glyph 220x176 px, horizontally centered (x 130..350), y 310..486.
  $s  = 11.0
  $tx = 240.0 - 12.0 * $s   # 108
  $ty = 266.0               # glyph top lands at ty + 4s = 310

  return @"
<svg xmlns="http://www.w3.org/2000/svg" width="480" height="918" viewBox="0 0 480 918">
  <rect width="480" height="918" fill="$accentColor"/>
  <g transform="translate($tx,$ty) scale($s)" fill="$glyphColor">
    <path d="$glyphPath"/>
  </g>
</svg>
"@
}

# --- Paths and preconditions ---------------------------------------------------
$repoRoot     = Split-Path -Parent $PSScriptRoot
$resourcesDir = Join-Path $repoRoot 'windows\runner\resources'
$iconsDir     = Join-Path $repoRoot 'assets\icons'
# Forward slashes: ImageMagick eats backslashes as escape characters in -font.
$fontPath     = (Join-Path $repoRoot 'assets\fonts\montserrat_regular.ttf') -replace '\\', '/'

if (-not (Get-Command magick -ErrorAction SilentlyContinue)) { throw 'ImageMagick (magick) not found on PATH.' }
if (-not (Test-Path -LiteralPath $fontPath)) { throw "Font not found: $fontPath" }

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) 'clipmind-logo-gen'
if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
New-Item -ItemType Directory -Path $resourcesDir -Force | Out-Null
New-Item -ItemType Directory -Path $iconsDir -Force | Out-Null

function Invoke-Magick {
  # Run magick and fail loudly on a non-zero exit code.
  param([string]$Description, [string[]]$MagickArgs)
  magick @MagickArgs
  if ($LASTEXITCODE -ne 0) { throw $Description }
}

# --- Main -----------------------------------------------------------------------

# 1. Master PNG (1024x1024) from the embedded SVG.
$iconSvg = Join-Path $tempDir 'icon.svg'
[System.IO.File]::WriteAllText($iconSvg, (New-IconSvg -Size 1024))
$masterPng = Join-Path $tempDir 'master.png'
Invoke-Magick -Description 'Failed to render the 1024x1024 master PNG.' -MagickArgs @($iconSvg, $masterPng)

# 2. App icon: multi-size .ico (256/64/48/32/16). icon:auto-resize was verified
#    empirically with ImageMagick 7.1.2-21 (produces all 5 sizes).
$appIco = Join-Path $resourcesDir 'app_icon.ico'
Invoke-Magick -Description 'Failed to generate app_icon.ico.' -MagickArgs @($masterPng, '-define', 'icon:auto-resize=256,64,48,32,16', $appIco)

# 3. Large wizard image: violet background + mark, then the wordmark
#    (Montserrat via magick -font, top edge at y=556 so the mark + wordmark
#    block sits vertically centered in the 918 px tall image).
$wizardSvg = Join-Path $tempDir 'wizard.svg'
[System.IO.File]::WriteAllText($wizardSvg, (New-WizardSvg))
$wizardBase = Join-Path $tempDir 'wizard_base.png'
Invoke-Magick -Description 'Failed to render the wizard base image.' -MagickArgs @($wizardSvg, $wizardBase)

$wizardImage = Join-Path $resourcesDir 'wizard_image.png'
Invoke-Magick -Description 'Failed to render wizard_image.png.' -MagickArgs @(
  $wizardBase, '-font', $fontPath, '-pointsize', '48', '-fill', $glyphColor,
  '-gravity', 'North', '-annotate', '+0+556', 'ClipMind', $wizardImage)

# Verify the wordmark actually rendered (magick only warns and exits 0 when a
# font cannot be read, which would silently skip the text). compare exits 0
# when the images are identical (nothing drawn) and 1 when they differ.
# Temporarily relax the error preference: magick writes its metric to stderr.
$ErrorActionPreference = 'Continue'
magick compare -metric AE $wizardBase $wizardImage null: 2>$null
$compareExitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($compareExitCode -eq 0) { throw "Wordmark did not render - font could not be read: $fontPath" }

# 4. Small wizard image: the logo mark downscaled from the master.
$wizardSmall = Join-Path $resourcesDir 'wizard_small.png'
Invoke-Magick -Description 'Failed to render wizard_small.png.' -MagickArgs @($masterPng, '-resize', '116x116', $wizardSmall)

# 5. Logo asset: copy of the master.
Copy-Item -LiteralPath $masterPng -Destination (Join-Path $iconsDir 'clipmind_logo.png') -Force

# --- Verify ----------------------------------------------------------------------
Write-Host 'Generated branding assets:'
magick identify $appIco $wizardImage $wizardSmall (Join-Path $iconsDir 'clipmind_logo.png')
if ($LASTEXITCODE -ne 0) { throw 'Failed to identify the generated assets.' }
