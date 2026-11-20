<#
.SYNOPSIS
  Builds the Flutter web UI and points it at the website API.

.DESCRIPTION
  Mirrors tool/build_apk.ps1: resolves the Flutter/Dart SDK, validates
  SB_API_BASE_URL, regenerates the sqlite wasm assets, and emits build/web.

  The output is built with --base-href=/app/ because the website ships it at
  public/app and frames it from /learn on its own origin. Same-origin is what
  lets the browser send its Neon Auth cookie straight into the app, so a
  learner who signed in on the website is already signed in inside the app,
  reading and writing the same Neon Postgres as the Android build.

  Web executes real Python through Pyodide (CPython compiled to WebAssembly),
  so unlike the Android host it needs no trip through the store.

  Copy build\web into website\public\app after a successful build - see
  docs/BUILD_AND_RELEASE.md.

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
    'https://www.skillbridgeacademy.tech'
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

  # --base-href=/app/ keeps every asset URL on /app/ no matter which document
  # URL loads the bundle, which is what lets the site serve it from public/app.
  #
  # --no-web-resources-cdn keeps the Skia engine (canvaskit) in build/web/canvaskit
  # instead of www.gstatic.com. The website's CSP allows only 'self' and
  # cdn.jsdelivr.net, so a CDN canvaskit is refused and the app renders a blank
  # page — and a self-hosted engine also means no third-party origin at all.
  & $Flutter build web --release --no-web-resources-cdn --base-href=/app/ `
    "--dart-define=SB_API_BASE_URL=$SiteOrigin"
  if ($LASTEXITCODE -ne 0) { throw "flutter build web failed with exit code $LASTEXITCODE." }

  $Built = Join-Path $ProjectRoot 'build\web'
  if (-not (Test-Path (Join-Path $Built 'index.html'))) {
    throw "Flutter reported success but build\web\index.html is missing."
  }
  Write-Output "Web build: $Built"
  Write-Output "Copy build\web\* into website\public\app (dropping *.js.symbols), commit, and deploy."
} finally {
  Pop-Location
}
