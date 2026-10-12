# Previewing the UI

## The short version

```powershell
# 1. Free disk space first. See docs/disk-space.md
Get-PSDrive C | Select-Object @{n='FreeGB';e={[math]::Round($_.Free/1GB,1)}}

# 2. Build from a space-free mirror (the space in "wilheim leeshu" breaks builds)
$env:PUB_CACHE="C:\pubcache"
$src="C:\Users\wilheim leeshu\Documents\advertizing ap\app"; $dst="C:\antigua-app"
if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
robocopy $src $dst /E /XD build .dart_tool .idea /NFL /NDL /NJH /NJS /NP

# 3. Run on the Android emulator
Set-Location $dst
flutter emulators --launch antigua_api35
flutter run
```

Edit in `$src`, re-mirror, run in `$dst`. Press `r` for hot reload.

## What works and what does not

Tested on this machine:

| Target | Status |
| --- | --- |
| `flutter analyze` | Works from the project directory |
| `dart format` | Works from the project directory |
| Android APK build | Works, from the mirror only |
| Android emulator | AVD created, launches, boots slowly |
| Windows desktop | **Fails.** Firebase C++ SDK archive extraction breaks on the space in the path |
| Web / Chrome | **Fails.** Same native-assets path bug |
| Android Studio | **Fails.** Same cause, plus it must be opened at `app/` not `app/android/` |

## Why the mirror is necessary

The Windows username contains a space: `wilheim leeshu`. Flutter's native
assets hook and CMake both pass those paths to subprocesses without quoting, so
anything that compiles native code fails with a misleading error.

It affects every target that compiles native code. `flutter analyze` is pure
Dart, so it survives.

`PUB_CACHE` has been moved to `C:\pubcache`, which removes one of the two
space-bearing paths. The project path still has a space, which is why the
mirror is needed.

## The Android Studio Gradle error

`Gradle build script not found` is a symptom of the same problem, not a broken
project. `flutter build apk` succeeds from the mirror.

If Android Studio does work for you:
- Open `app/`, not `app/android/`
- Install the Flutter plugin (`Settings > Plugins > Marketplace`)
- Set the SDK path to `C:\Users\wilheim leeshu\develop\flutter`

**Recommendation: do not use Android Studio for building.** Use the command
line. Editor features are fine, but the Gradle sync will hit the path problem.

## Emulator

Created: `antigua_api35` — Pixel 6, Android 15, Google APIs, at
`C:\Users\wilheim leeshu\.android\avd\antigua_api35.avd`.

```powershell
flutter emulators                      # confirm it is listed
flutter emulators --launch antigua_api35
```

It takes several minutes to boot. `flutter devices` shows nothing until it
finishes. The first boot is slower than later ones.

Requires hardware acceleration. If it stalls, check that Hyper-V or WHPX is
enabled in Windows features.

## Hot reload keys

| Key | Action |
| --- | --- |
| `r` | Hot reload, about a second |
| `R` | Hot restart, needed after state or provider changes |
| `q` | Quit |

## If the emulator is too slow

A physical Android phone over USB is faster and tests real hardware, which
matters for a map app anyway.

Enable Developer options and USB debugging on the phone, plug it in, then:

```powershell
adb devices
flutter run
```

This is the better long-term setup. The emulator is mainly useful for testing
when no phone is handy.

## Disk space warning

The machine ran out of disk during this setup. Builds failed with errors that
did not mention disk. Keep 15 GB free. See `docs/disk-space.md`.

Note the Windows desktop build pulls in several GB of Firebase C++ SDK. If disk
is tight, skip it and use Android only.