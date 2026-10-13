# Builds the submission APK against the public HTTPS API.
# Usage (from repo root):  .\scripts\build-release-apk.ps1
[CmdletBinding()]
param(
    [string]$ApiBaseUrl = "https://field-notes-api.onrender.com"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$mobile = Join-Path $root "mobile"
$outDir = Join-Path $mobile "build\app\outputs\flutter-apk"
$apk = Join-Path $outDir "app-release.apk"
$named = Join-Path $outDir "FieldNotes-v1.0.apk"

Set-Location $mobile
flutter pub get
flutter build apk --release --dart-define="API_BASE_URL=$ApiBaseUrl"

if (-not (Test-Path -LiteralPath $apk)) {
    throw "APK was not produced at $apk"
}

Copy-Item -LiteralPath $apk -Destination $named -Force
Write-Host "Built $named"
Write-Host "API_BASE_URL=$ApiBaseUrl"
