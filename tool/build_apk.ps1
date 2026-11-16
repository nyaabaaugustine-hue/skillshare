$ErrorActionPreference = 'Stop'

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Flutter = if ($env:FLUTTER_BIN) { $env:FLUTTER_BIN } else { 'C:\src\flutter\bin\flutter.bat' }
$Dart = if ($env:DART_BIN) { $env:DART_BIN } else { Join-Path (Split-Path $Flutter -Parent) 'dart.bat' }
$AndroidSdk = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { 'C:\Users\HP\AppData\Local\Android\Sdk' }
$Output = Join-Path $ProjectRoot 'outputs\skillbridge-python-lab-debug.apk'
$LeaderboardUrl = if ($env:SB_LEADERBOARD_URL) {
  $env:SB_LEADERBOARD_URL.TrimEnd('/')
} else {
  'https://academy-skillshare.vercel.app'
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
  & $Flutter build apk --debug --no-pub "--dart-define=SB_LEADERBOARD_URL=$LeaderboardUrl"
  if ($LASTEXITCODE -ne 0) { throw "Flutter build failed with exit code $LASTEXITCODE." }
  $Built = Join-Path $ProjectRoot 'build\app\outputs\flutter-apk\app-debug.apk'
  if (-not (Test-Path $Built)) { throw "Flutter reported success but no APK was found at '$Built'." }
  Copy-Item $Built $Output -Force
  Write-Output "APK: $Output"
  Get-Item $Output | Select-Object FullName, Length, LastWriteTime
} finally {
  Pop-Location
}
