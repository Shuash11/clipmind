<#
.SYNOPSIS
    Patches flutter_secure_storage_windows to build without the ATL
    (atlstr.h) dependency.

.DESCRIPTION
    The plugin (verified through 4.2.2) includes <atlstr.h> for its CA2W/CW2A
    string conversions. ATL is not available in the GitHub Actions
    windows-latest image, so the build fails there. This patch:
        1. removes the <atlstr.h> include,
        2. injects CA2W/CW2A replacements built on MultiByteToWideChar /
           WideCharToMultiByte,
        3. adds the missing const_cast for cred.TargetName (LPCWSTR -> LPWSTR).

    The plugin version is derived from pubspec.lock (the resolved
    flutter_secure_storage_windows entry) so the patch follows dependency
    upgrades automatically instead of drifting behind a hard-coded pin.
    Idempotent: re-running against an already patched copy is a no-op.

.PARAMETER PluginVersion
    Explicit flutter_secure_storage_windows version to patch. When omitted,
    the version resolved in pubspec.lock is used.
#>
param([string]$PluginVersion = '')

function Get-LockedPluginVersion {
    param([string]$LockPath)

    if (-not (Test-Path -LiteralPath $LockPath)) { return $null }

    $inEntry = $false
    foreach ($line in Get-Content -LiteralPath $LockPath) {
        if ($line -match '^  flutter_secure_storage_windows:\s*$') {
            $inEntry = $true
            continue
        }
        if (-not $inEntry) { continue }
        if ($line -match '^  \S') { break }  # next lock entry
        $match = [regex]::Match($line, '^    version:\s*"?([^"\s]+)"?\s*$')
        if ($match.Success) { return $match.Groups[1].Value }
    }
    return $null
}

if (-not $PluginVersion) {
    $lockFile = Join-Path $PSScriptRoot '..\pubspec.lock'
    $PluginVersion = Get-LockedPluginVersion -LockPath $lockFile
    if (-not $PluginVersion) {
        Write-Error "Could not resolve flutter_secure_storage_windows version from $lockFile. Run 'flutter pub get' first, or pass -PluginVersion."
        exit 1
    }
}

Write-Output "Resolved flutter_secure_storage_windows version: $PluginVersion"

$base = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev"
$cppFile = "$base\flutter_secure_storage_windows-$PluginVersion\windows\flutter_secure_storage_windows_plugin.cpp"

if (-not (Test-Path $cppFile)) {
    Write-Error "Not found: $cppFile"
    exit 1
}

$content = Get-Content $cppFile -Raw

if ($content -match '// ATL string conversion replacements') {
    Write-Output "Already patched, skipping."
    exit 0
}

# 1) Remove atlstr.h include
$content = $content -replace '#include <atlstr.h>\r?\n', ''

# 2) Insert #include <string> after bcrypt.h
$content = $content -replace '(#include <bcrypt\.h>\r?\n)', "`$1#include <string>`r`n"

# 3) Inject CA2W / CW2A replacement classes before VersionHelpers include
$classes = @"
// ATL string conversion replacements (avoid atlstr.h dependency)
class CA2W {
private:
    std::wstring wide_;
public:
    CA2W(const char* psz) {
        if (psz && *psz) {
            int len = MultiByteToWideChar(CP_ACP, 0, psz, -1, nullptr, 0);
            if (len > 0) { wide_.resize(len - 1); MultiByteToWideChar(CP_ACP, 0, psz, -1, &wide_[0], len); }
        }
        m_psz = wide_.c_str();
    }
    operator LPCWSTR() const { return m_psz; }
    LPCWSTR m_psz;
};
class CW2A {
private:
    std::string ansi_;
public:
    CW2A(LPCWSTR pwsz) {
        if (pwsz && *pwsz) {
            int len = WideCharToMultiByte(CP_ACP, 0, pwsz, -1, nullptr, 0, nullptr, nullptr);
            if (len > 0) { ansi_.resize(len - 1); WideCharToMultiByte(CP_ACP, 0, pwsz, -1, &ansi_[0], len, nullptr, nullptr); }
        }
    }
    operator const char*() const { return ansi_.c_str(); }
};

"@

$content = $content -replace '(// For getPlatformVersion)', "$classes`$1"

# 4) const_cast for cred.TargetName (LPCWSTR → LPWSTR)
$content = $content -replace '(cred\.TargetName = )target_name\.m_psz;', "`$1const_cast<LPWSTR>(target_name.m_psz);"

Set-Content -Path $cppFile -Value $content -NoNewline
Write-Output "Patched."
