<#
.SYNOPSIS
  Builds the Flutter web UI and points it at the website API.

.DESCRIPTION
  Mirrors tool/build_apk.ps1: resolves the Flutter/Dart SDK, validates
  SB_API_BASE_URL, regenerates the sqlite wasm assets, and emits build/web.

  Web is a UI-only target (no dart:io / dart:ffi), so Python never executes in
  the browser - see docs/BUILD_AND_RELEASE.md and docs/KNOWN_LIMITATIONS.md.

  The website embeds this build in /learn, so after hosting it set
  NEXT_PUBLIC_LEARN_URL and FLUTTER_APP_ORIGIN on the Vercel project to the
  origin it is served from.

.PARAMETER SiteOrigin
  Website origin serving /api (defaults to the production site, or
  $env:SB_API_BASE_URL when set).
#>
[CmdletBinding()]
param(
  [string]$SiteOrigin = ''
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Flutter = if ($env:FLUTTER_BIN) { $env:FLUTTER_BIN } else { 'C:\src\flutter\bin\flutter.bat' }
$Dart = if ($env:DART_BIN) { $env:DART_BIN } else { Join-Path (Split-Path $Flutter -Parent) 'dart.bat' }

if (-not $SiteOrigin) {
  $SiteOrigin = if ($env:SB_API_BASE_URL) {
    $env:SB_API_BASE_URL.TrimEnd('/')
  } else {
    'https://academy-skillshare.vercel.app'
  }
}

# Fail loudly: without a valid origin the web build cannot sign in or reach the
# tutor, exactly like the Android build.
$SiteOriginUri = $null
if (-not [System.Uri]::TryCreate($SiteOrigin, [System.UriKind]::Absolute, [ref]$SiteOriginUri) -or
    $SiteOriginUri.Scheme -notin @('http', 'https')) {
  throw "SB_API_BASE_URL must be an absolute http(s) URL; got '$SiteOrigin'."
}

if (-not (Test-Path $Flutter)) { throw "Flutter SDK not found at '$Flutter'. Set FLUTTER_BIN to flutter.bat." }
if (-not (Test-Path $Dart)) { throw "Dart SDK not found at '$Dart'. Set DART_BIN to dart.bat." }

$env:PATH = "$(Split-Path $Flutter -Parent);$env:PATH"
Push-Location $ProjectRoot
try {
  # Regenerate the SQLite wasm + shared worker that web/ needs (git-ignored).
  & $Dart run sqflite_common_ffi_web:setup
  if ($LASTEXITCODE -ne 0) { throw "sqflite_common_ffi_web:setup failed with exit code $LASTEXITCODE." }

  & $Flutter build web --release "--dart-define=SB_API_BASE_URL=$SiteOrigin"
  if ($LASTEXITCODE -ne 0) { throw "flutter build web failed with exit code $LASTEXITCODE." }

  $Built = Join-Path $ProjectRoot 'build\web'
  if (-not (Test-Path (Join-Path $Built 'index.html'))) {
    throw "Flutter reported success but build\web\index.html is missing."
  }
  Write-Output "Web build: $Built"
  Write-Output "Host build\web, then set NEXT_PUBLIC_LEARN_URL and FLUTTER_APP_ORIGIN to its origin."
} finally {
  Pop-Location
}
