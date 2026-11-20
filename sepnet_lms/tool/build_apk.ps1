# Builds the Android APK and points it at the website API.
#
# Pass -Release to build the distributable APK that the website serves at
# /downloads. Without the SB_API_BASE_URL baked in, cloudAuthEnabled is a
# compile-time false, the whole cloud sign-in path is tree-shaken out of the
# binary, and a release APK can neither register nor sign in - only guest mode.
[CmdletBinding()]
param(
  [switch]$Release
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Flutter = if ($env:FLUTTER_BIN) { $env:FLUTTER_BIN } else { 'C:\src\flutter\bin\flutter.bat' }
$Dart = if ($env:DART_BIN) { $env:DART_BIN } else { Join-Path (Split-Path $Flutter -Parent) 'dart.bat' }
# Resolve the Android SDK without hard-coding a user name: honour ANDROID_SDK_ROOT
# / ANDROID_HOME first, then fall back to the standard per-user location.
$AndroidSdk = if ($env:ANDROID_SDK_ROOT) {
  $env:ANDROID_SDK_ROOT
} elseif ($env:ANDROID_HOME) {
  $env:ANDROID_HOME
} elseif ($env:LOCALAPPDATA) {
  Join-Path $env:LOCALAPPDATA 'Android\Sdk'
} else {
  ''
}
$Output = if ($Release) {
  Join-Path $ProjectRoot 'outputs\skillbridge-python-lab-release.apk'
} else {
  Join-Path $ProjectRoot 'outputs\skillbridge-python-lab-debug.apk'
}
$SiteOrigin = if ($env:SB_API_BASE_URL) {
  $env:SB_API_BASE_URL.TrimEnd('/')
} else {
  'https://www.skillbridgeacademy.tech'
}
$LeaderboardUrl = if ($env:SB_LEADERBOARD_URL) {
  $env:SB_LEADERBOARD_URL.TrimEnd('/')
} else {
  $SiteOrigin
}
$GuardianReportUrl = if ($env:SB_GUARDIAN_REPORT_URL) {
  $env:SB_GUARDIAN_REPORT_URL.TrimEnd('/')
} else {
  'https://skillbridge-tutor.skillsbridg-academy.workers.dev/guardian-report'
}

# Fail loudly. A build whose SB_API_BASE_URL is empty or malformed silently runs
# in guest/offline mode: no cloud sign-in, no JWT, and every tutor answer comes
# from the offline brain instead of Cloudflare AI. Catch it here rather than
# shipping an APK that looks fine but cannot reach the tutor.
$SiteOriginUri = $null
if (-not [System.Uri]::TryCreate($SiteOrigin, [System.UriKind]::Absolute, [ref]$SiteOriginUri) -or
    $SiteOriginUri.Scheme -notin @('http', 'https')) {
  throw "SB_API_BASE_URL must be an absolute http(s) URL; got '$SiteOrigin'. Set SB_API_BASE_URL (or edit the default in this script)."
}

if (-not (Test-Path $Flutter)) {
  throw "Flutter SDK not found at '$Flutter'. Set FLUTTER_BIN to flutter.bat."
}
if (-not (Test-Path $Dart)) {
  throw "Dart SDK not found at '$Dart'. Set DART_BIN to dart.bat."
}

try {
  $sdkAccessible = Test-Path $AndroidSdk
} catch {
  throw "Android SDK exists but is not accessible to this user: '$AndroidSdk'. Grant read/execute access or set ANDROID_SDK_ROOT to an accessible SDK."
}
if (-not $sdkAccessible) {
  throw "Android SDK not found at '$AndroidSdk'. Set ANDROID_SDK_ROOT to an accessible SDK."
}

$env:FLUTTER_ROOT = Split-Path (Split-Path $Flutter -Parent) -Parent
$env:ANDROID_HOME = $AndroidSdk
$env:ANDROID_SDK_ROOT = $AndroidSdk
$env:PATH = "$(Split-Path $Flutter -Parent);$env:PATH"
$PythonApp = Join-Path $ProjectRoot 'build\python-app'
$PythonSitePackages = Join-Path $ProjectRoot 'build\python-site-packages'
$env:SERIOUS_PYTHON_APP = $PythonApp
$env:SERIOUS_PYTHON_SITE_PACKAGES = $PythonSitePackages

New-Item -ItemType Directory -Force -Path (Split-Path $Output -Parent) | Out-Null
Push-Location $ProjectRoot
try {
  New-Item -ItemType Directory -Force -Path $PythonApp, $PythonSitePackages | Out-Null
  # --cleanup-app strips junk (notably __pycache__/.pyc) from the staged app.
  # Without it a stale .pyc from a different interpreter version can ship inside
  # app.zip and make the embedded CPython fail to import main.py at startup,
  # which surfaces as "the embedded Python runtime did not start in time".
  & $Dart run serious_python:main package python_app -p Android --cleanup-app
  if ($LASTEXITCODE -ne 0) { throw "Serious Python packaging failed with exit code $LASTEXITCODE." }
  # SB_API_BASE_URL is what enables cloud sign-in and the AI tutor proxy: without
  # it the app runs in guest/offline mode and every tutor answer comes from the
  # offline brain, because there is no JWT for the Worker to verify.
  $mode = if ($Release) { '--release' } else { '--debug' }
  & $Flutter build apk $mode --no-pub `
    "--dart-define=SB_API_BASE_URL=$SiteOrigin" `
    "--dart-define=SB_LEADERBOARD_URL=$LeaderboardUrl" `
    "--dart-define=SB_GUARDIAN_REPORT_URL=$GuardianReportUrl"
  if ($LASTEXITCODE -ne 0) { throw "Flutter build failed with exit code $LASTEXITCODE." }
  $Built = Join-Path $ProjectRoot `
    "build\app\outputs\flutter-apk\app-$(if ($Release) { 'release' } else { 'debug' }).apk"
  if (-not (Test-Path $Built)) { throw "Flutter reported success but no APK was found at '$Built'." }
  Copy-Item $Built $Output -Force
  Write-Output "APK: $Output"
  Get-Item $Output | Select-Object FullName, Length, LastWriteTime
} finally {
  Pop-Location
}
