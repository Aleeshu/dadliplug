# Handover notes

For whoever picks this up next. Written because several of these cost hours to
find, and none of them are visible from the code.

## Do not collide

Two agents have edited this tree at once and clobbered each other's work.
**One agent edits at a time.** Check `git log` / `git status` before starting,
and commit before handing over. There was no git repo until recently — see
below.

## Current state

- Analyze: clean (6 info-level lints, no errors or warnings)
- Tests: 66 passing
- Builds: Android debug APK works
- Phases 1 and 2 complete. Phase 3 (map) mostly done. Phase 4 in progress.

## Traps

### 1. Never show invented businesses

An earlier version of the repository fell back to hardcoded sample listings
whenever the database returned nothing. Your database is empty at launch, so
the app displayed seven fabricated businesses with invented phone numbers and
ratings — and it looked entirely correct on screen.

**Empty must mean empty.** `docs`-level reasoning is in the comment above
`SupabaseBusinessRepository._visible`. There is a test
("an empty database yields an empty list") guarding it. Do not re-add sample
data as a fallback, and do not add a flag to enable it. If you need fixtures for
UI work, put them in a test.

### 2. Realtime is not enabled on Supabase

```
RealtimeSubscribeException: Please check Realtime is enabled ...
```

The listings stream fails until someone runs, in the Supabase SQL editor:

```sql
alter publication supabase_realtime add table public.businesses;
```

Until then `watchBusinesses()` catches the failure and falls back to a plain
REST fetch, so the app works — it just does not live-update. That fallback is
deliberate: the WebSocket is the first thing to drop on weak signal, and a
dropped stream must not mean an empty map.

### 3. Map tiles do not render on device

MapLibre draws its logo correctly and the surface exists, but the map area
stays blank — no tiles, no error in logcat. Verified: the style URL and
TileJSON are reachable from the device, `libmaplibre.so` ships in the APK,
network is fine, INTERNET is granted.

Already ruled out: missing API key (there is none needed with OpenFreeMap),
permissions, network, missing native lib, Impeller compositing (disabled as a
workaround — the logo does now render correctly, which it did not before).

Still to try: the device's GPU/driver, `cameraTargetBounds` conflicting with
`initialCameraPosition`, or the style failing silently. Worth testing on the
emulator versus the phone to see whether it is device-specific.

### 4. Spaces in the Windows path break builds

The username contains a space (`wilheim leeshu`). Flutter's native-assets hook
and CMake both pass paths to subprocesses **without quoting**, so anything that
compiles native code fails with a misleading Gradle error:

```
'C:\Users\wilheim leeshu' is not recognized as an internal or external command
```

Affects `flutter test`, `flutter build`, and the Windows/web builds. It is not a
code problem and CI is unaffected.

Workaround: build from a space-free mirror.

```powershell
$env:PUB_CACHE="C:\pubcache"
robocopy "<repo>\app" C:\antigua-app /E /XD build .dart_tool .idea /NFL /NDL /NJH /NJS /NP
Set-Location C:\antigua-app
flutter test
flutter build apk --debug --dart-define=...
```

`flutter analyze` and `dart format` work fine in the real directory.

Full detail in `docs/build-environment.md`.

### 5. Disk fills up silently

This machine has run out of disk mid-build, and the error does not mention
disk:

```
Flutter failed to write to a file at "...". The target device is full.
```

Keep 15 GB free. Safe to delete: `app/build`, `C:\antigua-app`, stale Temp dirs.
Do not touch `Downloads` (22 GB, the user's files) without asking. Detail in
`docs/disk-space.md`.

### 6. Build the APK correctly

```powershell
$env:PUB_CACHE="C:\pubcache"
Set-Location C:\antigua-app
flutter build apk --debug `
  --dart-define=SUPABASE_URL=https://ftenxsusyuiqatnvasny.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_... `
  --dart-define=GOOGLE_SIGN_IN_CLIENT_ID=... `
  --dart-define=GOOGLE_SIGN_IN_WEB_CLIENT_ID=...
adb install -r "<repo>\builds\islandads-debug.apk"
```

Without the defines the app falls back to mock auth. **Release builds throw
rather than fall back** — deliberate, because mock auth lets anyone sign in as
anyone.

Values live in `<repo>\.env` (gitignored). The `GOOGLE_MAPS_API_KEY` entry is
empty and unused; MapLibre + OpenFreeMap needs no key.

### 7. Reading the logs

The Dart error is logged as `E flutter`. Grepping for `FATAL` or
`AndroidRuntime` finds **nothing** for a Dart exception, which cost hours —
the app dies to a black screen with no crash signature.

```powershell
adb logcat -d | Select-String "flutter"
```

Phone connects over wireless ADB at `192.168.1.165:43533`; run
`adb connect` first, it does not persist across server restarts.

## Database

Supabase `antiguamap`, ref `ftenxsusyuiqatnvasny`, us-east-1. Migrations in
`supabase/migrations/`, applied via `supabase db push --include-all`.

Two migrations briefly created the same things twice (`closed_today` vs
`is_closed_today`, `info_reports` vs `listing_reports`) because two agents
wrote schema at once. Consolidated onto the phase 4 names. **Check for
duplicates before adding a column.**

Verified against the live database: RLS enabled on every table, and a signed-in
user **cannot** promote themselves to `team_admin`. That guard is a trigger, not
an RLS policy — a column-level `GRANT` does not work here because Supabase
grants table-wide `UPDATE` by default. Do not weaken it.

## Product decisions not to relitigate

- Rank is earned, never bought. Premium buys a Featured slot; ranking decides
  the order inside it.
- A business approving its own reviewers is a known weakness, not a bug to
  engineer away. See `plan.md` section 7. The app should say so rather than
  imply ratings are clean.
- Visits are verified by QR code at the till, not by a manual tap.
- No invented data, ever. Accuracy is the product.

## Before Phase 4 starts

- Commit the current tree. Nothing is committed and there is no history.
- Decide whether the map tile issue blocks Phase 4 or can run alongside it.
- Someone needs to create the first team admin accounts. `team_admin` is
  currently unreachable, so the Moderation, Billing, Ranking and Spotlight tabs
  cannot be opened.