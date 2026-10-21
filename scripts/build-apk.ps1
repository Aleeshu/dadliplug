# Builds IslandAds with the right dart-defines loaded from .env.
#
# Exists because the defines are easy to forget and forgetting them silently
# produces a build with mock auth instead of Supabase, which is a confusing
# thing to debug on a device.
#
#   .\scripts\build-apk.ps1                  debug build to builds\
#   .\scripts\build-apk.ps1 -Release         release build (needs key.properties)
#   .\scripts\build-apk.ps1 -Install          build, then install on the emulator
#   .\scripts\build-apk.ps1 -Mirror C:\antigua-app   build via a space-free path
#
# Requires PUB_CACHE set to a path with no spaces. See docs/build-environment.md.
#
# Always use this script rather than calling `flutter build` directly. The
# dart-defines come from .env and nothing tells you they are missing: a build
# without them compiles cleanly, runs, and silently falls back to mock auth and
# a dead business repository. That produced a day of debugging a build that was
# never talking to Supabase at all. See the mirror warning below.

param(
  [switch]$Release,
  [switch]$Install,
  [string]$Mirror = ''
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

# Gradle and the Dart native toolchain fail on the spaces in this repo's path.
# So when a space-free mirror is given, mirror the app source there and build
# there instead. The dart-defines are passed on the command line, so the mirror
# deliberately does not receive .env — it is a build directory, not a second
# checkout, and copying keys into it would only widen where they live.
$buildRoot = Join-Path $root 'app'
if ($Mirror) {
  $appDir = Join-Path $root 'app'
  New-Item -ItemType Directory -Path $Mirror -Force | Out-Null
  Write-Host "Mirroring app/ -> $Mirror ..."
  & robocopy $appDir $Mirror /MIR /NFL /NDL /NJH /NJS /NP /XD build .dart_tool /XF '*.lock' | Out-Null
  if ($LASTEXITCODE -ge 8) {
    Write-Error "robocopy failed with exit code $LASTEXITCODE"
  }
  $buildRoot = $Mirror
}

Set-Location $buildRoot

Write-Host "Building IslandAds in $buildRoot ..."
# Gradle's JDK prints warnings on stderr ("A restricted method in
# java.lang.System has been called"). Under 'Stop', Windows PowerShell turns
# any stderr line from a native command into a terminating error, so the
# build died on a warning. The exit code is the real verdict.
$ErrorActionPreference = 'Continue'
& flutter @args
$ErrorActionPreference = 'Stop'
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$mode = if ($Release) { 'release' } else { 'debug' }
$apk = Join-Path $buildRoot "build\app\outputs\flutter-apk\app-$mode.apk"
$dest = Join-Path $root 'builds'
New-Item -ItemType Directory -Path $dest -Force | Out-Null
Copy-Item $apk (Join-Path $dest "islandads-$mode.apk") -Force

Write-Host "APK: $dest\islandads-$mode.apk"

if ($Install) {
  $built = Join-Path $dest "islandads-$mode.apk"
  & adb install -r $built
}