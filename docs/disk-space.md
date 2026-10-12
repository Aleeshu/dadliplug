# Disk space

**This machine has run out of disk at least once while working on this project,
and it silently broke builds.** Worth knowing about before it happens again.

## Symptom

Builds fail partway through with something that looks like a code problem:

```
Error: Flutter failed to write to a file at "...\.dart_tool\flutter_build\...\.filecache".
The target device is full.
FileSystemException: writeFrom failed (OS Error: There is not enough space on the
disk, errno = 112)
```

Or CMake fails extracting a plugin archive:

```
CMake Error: Problem with archive_write_finish_entry(): File size could not be restored
CMake Error at firebase_core/windows/CMakeLists.txt:46 (file):
  file failed to extract
```

Neither mentions disk space directly. Both are out-of-space.

## Check first

```powershell
Get-PSDrive C | Select-Object @{n='FreeGB';e={[math]::Round($_.Free/1GB,2)}}
```

**Keep at least 15 GB free.** A full Android debug build tree is 5-6 GB on its
own, and the emulator system image is 3.5 GB.

## Where the space goes

Roughly, as of the last check:

| Location | Size | Notes |
| --- | --- | --- |
| `Downloads` | 22 GB | The user's files. **Do not touch without asking.** |
| `Documents` | 9 GB | Mostly this project |
| `~/.gradle` | 6.6 GB | Gradle caches |
| `Temp` | 3.3 GB | Flutter and MSVC build temp |
| `~/.android` | 0.2 GB | AVDs |
| `AppData\Local\Pub` | 0.9 GB | Old pub cache, superseded by `C:\pubcache` |

## What is safe to delete

```powershell
# Flutter build output. Regenerated on every build. ~5 GB
Remove-Item "<project>\app\build" -Recurse -Force

# Compiled APKs
Remove-Item "<project>\builds" -Recurse -Force

# The space-free build mirror
Remove-Item "C:\antigua-app-build" -Recurse -Force

# Stale Flutter/MSVC temp dirs
Get-ChildItem "$env:TEMP" -Directory -Filter "flutter_tools.*" | Remove-Item -Recurse -Force
```

## What is NOT safe to delete without asking

- `Downloads` — 22 GB, but these are the user's files
- `~/.gradle/caches` — regenerates, but forces a long re-download on the next build
- Android SDK system images — the emulator needs them

## If still short

Ask before deleting anything large. Options, roughly in order of preference:

1. Clear `Temp` fully
2. `flutter clean` plus deleting `app/build`
3. Uninstall unused Android system images (`sdkmanager --uninstall`)
4. Move `~/.gradle` to another drive
5. Only then touch `Downloads`, and always ask first

## Note

The Windows desktop build pulls in the full Firebase C++ SDK, which is several
GB and is not needed for the Android build. If disk is tight, prefer the Android
emulator for UI work and skip the Windows desktop build entirely.