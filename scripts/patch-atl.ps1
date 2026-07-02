param([string]$PluginVersion = "3.1.2")

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
