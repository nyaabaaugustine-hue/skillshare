<#
.SYNOPSIS
  On-device smoke test for the embedded Python runtime.

.DESCRIPTION
  Proves the embedded CPython actually runs on a real device - which
  "the APK contains libpython3.14.so" does not.

  The packaged python_app/main.py starts a loopback-only HTTP server
  (127.0.0.1:8791) exposing /health and /execute. This script forwards that port
  to the host, installs and launches the debug APK, waits for the runtime to
  answer, then runs a tiny program through /execute.

  The runtime starts lazily on the first Run, so when prompted, open a lesson in
  the app and tap Run once. Requires adb on PATH and a device/emulator attached.

.PARAMETER Apk
  APK to install. Defaults to build\app\outputs\flutter-apk\app-debug.apk.

.PARAMETER TimeoutSeconds
  How long to wait for the runtime to answer. Default 120.
#>
[CmdletBinding()]
param(
  [string]$Apk = '',
  [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $Apk) {
  $Apk = Join-Path $ProjectRoot 'build\app\outputs\flutter-apk\app-debug.apk'
}
$Package = 'com.skillbridge.skillbridge_python_lab'
$Port = 8791
$Base = "http://127.0.0.1:$Port"

function Fail($message) {
  Write-Host "FAIL: $message" -ForegroundColor Red
  exit 1
}

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
  Fail "adb not found on PATH. Add %LOCALAPPDATA%\Android\Sdk\platform-tools to PATH."
}
if (-not (Test-Path $Apk)) {
  Fail "APK not found at '$Apk'. Run tool\build_apk.ps1 first."
}
$deviceCount = @(adb devices | Select-String -Pattern "\sdevice$").Count
if ($deviceCount -lt 1) {
  Fail "No device or emulator is connected (check 'adb devices')."
}

Write-Host "Forwarding device port $Port to the host..."
adb forward "tcp:$Port" "tcp:$Port" | Out-Null

Write-Host "Installing $Apk ..."
& adb install -r $Apk | Out-Null
if ($LASTEXITCODE -ne 0) { Fail "adb install failed." }

adb logcat -c | Out-Null
Write-Host "Launching $Package ..."
& adb shell monkey -p $Package -c android.intent.category.LAUNCHER 1 | Out-Null

Write-Host ''
Write-Host 'ACTION REQUIRED: in the app, open a lesson and tap Run once.' -ForegroundColor Yellow
Write-Host "Waiting up to $TimeoutSeconds s for the embedded runtime on $Base ..."
Write-Host ''

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$healthy = $false
while ((Get-Date) -lt $deadline) {
  if ((adb logcat -d) -match 'embedded Python runtime did not start in time') {
    Fail 'The embedded Python runtime did not start. Re-run the serious_python packaging step (docs\BUILD_AND_RELEASE.md), then rebuild.'
  }
  try {
    $health = Invoke-RestMethod -Uri "$Base/health" -TimeoutSec 2
    if ($health.ok -eq $true) { $healthy = $true; break }
  } catch {
    # Not up yet; keep polling.
  }
  Start-Sleep -Seconds 2
}

if (-not $healthy) {
  Fail "The runtime never answered on $Base. Did you tap Run in the app?"
}
Write-Host 'Runtime health OK.' -ForegroundColor Green

$payload = @{
  code          = 'print(6 * 7)'
  stdin         = @()
  maxOutputChars = 2000
} | ConvertTo-Json

try {
  $response = Invoke-WebRequest -Uri "$Base/execute" -Method Post `
    -ContentType 'application/json' -Body $payload -TimeoutSec 15
} catch {
  Fail "POST /execute failed: $_"
}

if ($response.Content -match '42') {
  Write-Host 'PASS: embedded CPython executed code end to end.' -ForegroundColor Green
  exit 0
}
Fail "Python ran but the output did not contain the expected result: $($response.Content)"
