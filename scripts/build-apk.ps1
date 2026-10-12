# Builds IslandAds with the right dart-defines loaded from .env.
#
# Exists because the defines are easy to forget and forgetting them silently
# produces a build with mock auth instead of Supabase, which is a confusing
# thing to debug on a device.
#
#   .\scripts\build-apk.ps1                  debug build to builds\
#   .\scripts\build-apk.ps1 -Release         release build (needs key.properties)
#   .\scripts\build-apk.ps1 -Install          build, then install on the emulator
#
# Requires PUB_CACHE set to a path with no spaces. See docs/build-environment.md.

param(
  [switch]$Release,
  [switch]$Install
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root '.env'

if (-not (Test-Path $envFile)) {
  Write-Error "No .env found. Copy .env.example and fill it in."
}

# Read .env, ignoring comments and blank lines.
$defines = @{}
foreach ($line in Get-Content $envFile) {
  $trimmed = $line.Trim()
  if ($trimmed -and -not $trimmed.StartsWith('#') -and $trimmed.Contains('=')) {
    $key, $value = $trimmed -split '=', 2
    if ($value.Trim()) { $defines[$key.Trim()] = $value.Trim() }
  }
}

$required = @('SUPABASE_URL', 'SUPABASE_ANON_KEY')
foreach ($key in $required) {
  if (-not $defines.ContainsKey($key)) {
    Write-Error "$key is missing from .env"
  }
}

$args = @('build', 'apk')
if ($Release) { $args += '--release' } else { $args += '--debug' }

foreach ($key in $defines.Keys) {
  if ($key -eq 'SUPABASE_DB_PASSWORD' -or $key -eq 'GOOGLE_SERVICE_ACCOUNT_JSON') {
    continue
  }
  $args += "--dart-define=$key=$($defines[$key])"
}

Set-Location (Join-Path $root 'app')

Write-Host "Building IslandAds..."
& flutter @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$mode = if ($Release) { 'release' } else { 'debug' }
$apk = Join-Path $root "app\build\app\outputs\flutter-apk\app-$mode.apk"
$dest = Join-Path $root 'builds'
New-Item -ItemType Directory -Path $dest -Force | Out-Null
Copy-Item $apk (Join-Path $dest 'islandads-$mode.apk') -Force

Write-Host "APK: $dest\islandads-$mode.apk"

if ($Install) {
  $built = Join-Path $dest "islandads-$mode.apk"
  & adb install -r $built
}