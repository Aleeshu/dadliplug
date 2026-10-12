# Build Environment

Read this before running any Flutter command on this machine. There is a real
trap here that will waste an afternoon if you hit it cold.

## The problem

This machine's Windows username contains a space: `wilheim leeshu`. Flutter's
native-assets build hook shells out through `cmd.exe` **without quoting the
project path**, so any build from a directory with a space in it fails with:

```
'C:\Users\wilheim' is not recognized as an internal or external command
Target build_hooks failed: Error: Building native assets failed.
```

It shows up as `Execution failed for task ':app:compileFlutterBuildDebug'`,
which looks like a Gradle or dependency problem. It is not. It is a space.

It affects `flutter test` and `flutter build` equally. It is a bug in the hook
runner, not in our code.

## What is fixed

`PUB_CACHE` has been set to `C:\pubcache` (no spaces), which removes one of the
two space-bearing paths. Confirm with:

```powershell
$env:PUB_CACHE
```

If it is empty or points somewhere with a space, set it:

```powershell
[Environment]::SetEnvironmentVariable("PUB_CACHE","C:\pubcache","User")
```

## What is not fixed

The project path itself still contains a space, so **builds must run from a
space-free directory**. The project cannot simply be moved, because the team
works in `Documents\advertizing ap` and moving it would break everyone's
references.

Working approach: build from a mirror.

```powershell
$env:PUB_CACHE = "C:\pubcache"
$src = "C:\Users\wilheim leeshu\Documents\advertizing ap\app"
$dst = "C:\antigua-app-build"

if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
robocopy $src $dst /E /XD build .dart_tool .idea /NFL /NDL /NJH /NJS /NP

Set-Location $dst
flutter pub get
flutter analyze
flutter test
flutter build apk --debug

# APK lands at $dst\build\app\outputs\flutter-apk\app-debug.apk
```

Always edit in the real project directory, then re-mirror to build. Never edit
in `C:\antigua-app-build` — it gets overwritten on every mirror.

## Cheaper alternative

`flutter analyze` and `dart format` work fine from the project directory. Only
`flutter test` and `flutter build` need the mirror. That covers most of the
edit loop:

```powershell
Set-Location "C:\Users\wilheim leeshu\Documents\advertizing ap\app"
flutter analyze        # works
dart format lib        # works
```

## CI is unaffected

GitHub Actions runners have no spaces in their paths, so `flutter test` and
`flutter build` run cleanly there. This is a local-machine problem only. The
workflow is in `.github/workflows/flutter.yml`.

## If this ever needs a real fix

Upstream: the native assets hook should quote the paths it passes to the
subprocess. Worth reporting to the Flutter issue tracker if the team hits this
on more machines. Until then, the mirror is the workaround.