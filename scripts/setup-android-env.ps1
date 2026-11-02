# Sets Android SDK env vars for the current PowerShell session.
# Run before flutter/adb if ANDROID_HOME is not permanently configured:
#   . .\scripts\setup-android-env.ps1

$sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"

if (-not (Test-Path $sdk)) {
    Write-Error "Android SDK not found at $sdk"
    exit 1
}

$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk
$env:Path = "$sdk\platform-tools;$sdk\emulator;$sdk\cmdline-tools\latest\bin;$env:Path"

Write-Host "ANDROID_HOME=$env:ANDROID_HOME"
& "$sdk\platform-tools\adb.exe" version
Write-Host "Tip: set ANDROID_HOME permanently in Windows Environment Variables for new terminals."
