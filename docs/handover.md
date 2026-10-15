# Handover — IslandAds

Written for Claude Code picking this project up cold. Read this before changing
anything.

**State at handover:** 2026-10-14. Analyzer clean, 172 tests passing. Phases
0–3 complete, Phase 4 code complete. The map (now Google Maps), pin taps and
Google sign-in are confirmed on a phone. The business posting-to-report path
has **not** been walked on a device yet — see section 7.

---

## 1. What this is

A Flutter app listing businesses in Antigua on a map. Businesses pay a monthly
subscription for a listing; customers browse, bookmark and review. Backend is
Supabase. Android-first, iOS scaffolded.

The product pitch is **accuracy**: the team maintains listings so the
information stays true. That claim is load-bearing and shows up throughout the
code as a bias against inventing data.

`plan.md` is the source of truth for product decisions. It is long, and
section 18 lists what changed in the most recent revision. Read sections 2, 4,
6a and 15 first — they carry the decisions that are easiest to accidentally
undo.

---

## 2. Environment

This is the single biggest source of lost time. Get this wrong and you will
spend hours on a build that looks fine and does nothing.

| | |
|---|---|
| Repo path | `C:\Users\wilheim leeshu\Documents\advertizing ap` — **contains a space** |
| Build mirror | `C:\antigua-app` — no spaces, required for Gradle/Dart native builds |
| `PUB_CACHE` | `C:\pubcache` — must be set, no spaces |
| Flutter | on `PATH`; `flutter --version` to confirm |
| Supabase CLI | `C:\Users\wilheim leeshu\.supabase-cli` — must be added to `PATH` |
| Database password | in `.env` as `SUPABASE_DB_PASSWORD` |

### Never call `flutter build` directly

```powershell
# WRONG — silently produces an app with no credentials, mock auth, and a dead
# repository. It compiles, installs, runs, and shows "Could not load businesses".
.\scripts\build-apk.ps1

# RIGHT
powershell -ExecutionPolicy Bypass -File .\scripts\build-apk.ps1 -Mirror C:\antigua-app
```

`build-apk.ps1` reads the root `.env` and passes the values as `--dart-define`s.
Calling `flutter` yourself drops them. **This happened repeatedly** and cost a
full day of debugging a build that was never talking to Supabase.

Note `-ExecutionPolicy Bypass` — the machine blocks unsigned scripts.

### Tests and analysis

```powershell
Set-Location "C:\Users\wilheim leeshu\Documents\advertizing ap\app"
robocopy . "C:\antigua-app" /MIR /NFL /NDL /NJH /NJS /NP /XD build .dart_tool /XF *.lock
Set-Location "C:\antigua-app"; $env:PUB_CACHE="C:\pubcache"
flutter analyze
flutter test
```

**Always robocopy before running.** Analysing the real repo's `app/` works for
reading but not for building; analysing a stale mirror will show errors you
already fixed.

`flutter analyze` reports ~8 info-level lints (mostly `day: 1` defaults in test
fixtures). The bar is **zero errors and zero warnings** — infos are not worth
chasing.

### Device

Wireless debugging. **The port changes on every reconnect** — ask, or run
`adb devices`. Last seen: `192.168.1.165:39707`.

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb -s 192.168.1.165:<port> install -r "C:\antigua-app\build\app\outputs\flutter-apk\app-debug.apk"
```

`adb install` fails on paths containing spaces. Install from the mirror, not
from `builds\`.

Emulator fallback: AVD `antigua_api35`, booted with
`emulator -avd antigua_api35 -no-snapshot-load -no-boot-anim`. Boot takes ~60s
past `adb devices` reporting it online.

---

## 3. Database

Supabase project `ftenxsusyuiqatnvasny`. Migrations in `supabase/migrations/`,
applied with:

```powershell
$env:PATH = "C:\Users\wilheim leeshu\.supabase-cli;$env:PATH"
$env:SUPABASE_DB_PASSWORD = ((Get-Content .env | Where-Object { $_ -match '^SUPABASE_DB_PASSWORD=' }) -replace '^SUPABASE_DB_PASSWORD=','').Trim()
supabase db push --include-all --yes
```

Two things that will waste your time:

- **The password must go through the env var**, not `--password`. It contains
  characters the CLI's flag parser mangles.
- **After adding tables, PostgREST 404s for ~15–60s** until its schema cache
  reloads. It is not a failed migration. Check
  `supabase db push` says `upToDate: true` before assuming anything is wrong.

`supabase db dump` needs Docker and will fail without it. There is no psql.

---

## 4. Architecture

```
app/lib/
  core/       routing, theme, config
  features/   one folder per screen area
  services/   repositories and pure logic  ← the tests worth reading live here
  models/     plain data classes
  widgets/    shared components
```

Services hold the logic and are plain Dart where possible. `*_service.dart` files
with no Flutter dependency are the cheapest things in the project to test.

### Things that will look wrong but are deliberate

- **`Business.tier` and `businesses.subscription_status` are both present.**
  The app treats `subscription_status` as authoritative and `tier` as a
  fallback. They must use the same vocabulary or a business silently vanishes —
  see Known issues.
- **Reviews require a business-verified visit.** A business approves its own
  reviewers, which is gameable. `plan.md` §7 is honest about this and says so in
  the sales pitch. Do not quietly weaken it to raise review counts.
- **Empty states are a feature.** Several screens could show a plausible-looking
  list and deliberately do not. When a query fails, the error branch must render
  an error, never an empty list.
- **`AuthSession` is a `ChangeNotifier`.** It was not, and sign-out appeared to
  do nothing because nothing subscribed. See `docs/` git history, commit
  `e312348`.

### Testing gotchas

- **Never `await` a `MockAuthService` call inside `testWidgets`.** Its
  `Future.delayed` never elapses under fake async and the test deadlocks
  rather than failing. Use a synchronous fake service instead — see
  `test/auth_session_notification_test.dart`.
- **Google Maps is a PlatformView.** It cannot be instantiated in a widget
  test. `MapScreen.debugMapSurfaceOverride` substitutes a plain box.
  `test/map_layout_test.dart` shows the pattern.
- Assert **geometry, not pixels.** The map shipped visibly broken for a full
  session because nothing asserted where the recentre button was.

---

## 5. Current build state

| | |
|---|---|
| HEAD | see `git log` |
| Tests | 172 passing |
| Analyzer | 0 errors, 0 warnings, ~8 infos |
| APK | `builds/islandads-debug.apk` — built and installed on the phone |
| Signed-in account | `ahjahlwashere@gmail.com`, team admin, via phone wireless debugging |
| Also exists | `islandads.test@gmail.com` (plain user, unused) |

### Seeded demo data

Two listings exist so the app can be exercised:

- **IslandAds Demo Kitchen** — food, featured, Dickenson Bay. Has 2 ads, 1
  announcement, 1 event, social links.
- **IslandAds Demo Salon** — beauty, basic, St. John's. Has 1 event, social
  links.

Both are granted to the team admin's `profiles.business_ids`, which is what
makes the business tabs, posting screens and monthly report reachable at all.

The seed migration is guarded on `businesses` being empty, so it can never seed
test data alongside real customers. Remove with:

```sql
delete from public.businesses where name like 'IslandAds Demo%';
```

---

## 6. Known issues

Ordered by how much they matter.

### 6.1 Email auto-confirmation — LAUNCH BLOCKER

`mailer_autoconfirm` is **true** in GoTrue, so every signup is confirmed
without an email link. Anyone can register on an address they do not own.

This is a **dashboard setting**, not a database one. It cannot be fixed from the
CLI or a migration:

> Supabase Dashboard → Authentication → Sign In / Providers → Email → turn
> **off** "Auto Confirm User"

The database trigger *was* also auto-confirming and is now gated behind a
`dev_flags` row that defaults to off (`20261012150000`). That table is not
exposed to `anon` or `authenticated`, so it cannot be flipped with the
publishable key. For local testing:

```sql
update public.dev_flags set auto_confirm_email = true where id = true;
```

### 6.2 Seeded ratings were labelled "verified reviews" — fixed

`ratingLabel()` in `listing_screen.dart` now says "28 ratings from before
IslandAds" for team-entered numbers, and only calls reviews verified when they
passed the visit gate. Pinned by `test/phase4_closeout_test.dart`.

### 6.3 `subscription_status` typo silently delists a business

Found via the seed. The column is now CHECK-constrained to the tier vocabulary,
but the underlying trap remains for any new free-text field:
`SubscriptionTier.fromName` falls back to `delisted` for anything it does not
recognise. A value like `'Active'` removes a paying business from the app with
no error anywhere.

### 6.4 Pin taps — fixed, verified on a device

Pins are Google Maps markers with `consumeTapEvents` and their own `onTap`, so
a tap cannot fall through to the map's deselect. Confirmed on the phone.

### 6.5 Google sign-in — fixed, verified on a device

It had never completed, and the app reported every failure as "Something went
wrong", so there was nothing to go on. The failure is now logged
(`Google sign-in failed: ...` in logcat), which found three configuration
faults in turn, all outside the code:

1. `[16] Account reauth failed` — no Android OAuth client matching the package
   and debug SHA-1. Created one (`154710325721-kfofoa…`).
2. `provider_disabled` — Supabase's Google provider was off.
3. `Unacceptable audience in id_token` — Supabase's Client IDs must include the
   **Web** client id (`…-ndovs7n1…`), because that is the token's audience on
   Android. Both ids are listed, Web first. Skip nonce checks is on.

A release build signs with a different key, so it will fail at step 1 again
until its SHA-1 is added to an Android OAuth client.

### 6.6a Phase 4 close-out — fixed in code, not yet seen on a device

Migration `20261014120000_engagement_and_listing_guards.sql` plus app changes:

- **Engagement now counts.** Nothing ever incremented views, calls or taps.
  `record_engagement()` records them as timestamped events and bumps the
  counters; owners' and the team's own taps are excluded.
- **The monthly report is monthly.** It read lifetime counters, listed only ads
  that *started* that month, and used UTC midnight instead of Antigua midnight
  (04:00 UTC) as the boundary.
- **Owners could self-upgrade.** The row policy let an owner set their own
  `subscription_status`, counters and seeded rating with the publishable key.
  A trigger now refuses those from anyone but the team.
- **Antigua clock was 4h out on Antigua phones.** `AntiguaClock.now()`
  subtracted the offset from local time rather than UTC.
- **Business tabs had no listing.** Ads, Notices and Report needed
  `?business=` and the tab bar never passed it. The router now falls back to
  the last listing opened, then the account's first.
- **Team admins were locked out of business screens**, which were the only
  route to the demo listings' posting tools.
- **Team Listings tab** added: the team's create/edit backend (Phase 4).
- Also: leaderboard rows opened `/listing/` with no id and showed the 0–1 score
  as stars; demo seed hours/tags were in the wrong vocabulary; auto-confirm's
  gated trigger was AFTER INSERT so the dev flag did nothing; content RLS used
  `tier` while listings used `subscription_status`; Sunday never appeared as a
  next-open day; the editor had no hours controls and edited "the first
  business in the table" when given no id.

### 6.6 Map moved from MapLibre to Google Maps — verified on a device

All of it is in `features/map/island_ads_map.dart`. The key goes `.env` →
dart-define → `build.gradle.kts` (decodes Flutter's `dart-defines` Gradle
property) → `com.google.android.geo.API_KEY` in the manifest. A build with no
key shows "NO MAPS KEY" instead of the SDK's silent blank tiles.

- The key must allow **Maps SDK for Android** in its API restrictions. It
  allowed every other Maps API except that one, which gave a blank map and
  `Authorization failure` in logcat. First tiles can take a minute to appear.
- **Restrict the key** in Google Cloud (package name + SHA-1, Maps SDK for
  Android only) before release. It ships inside the APK.
- Impeller is still disabled from the MapLibre days. Try enabling it once the
  map is confirmed working on the phone.
- iOS reads `GMSApiKey` from Info.plist, which expands `$(GOOGLE_MAPS_API_KEY)`;
  nothing sets that build setting yet.
- The MapLibre-specific traps (selection-filter wire format, bounded camera
  blanking on tall screens) no longer apply. Camera bounds are back on.

---

## 7. What to do next

Ordered by value, not by ease.

1. **Turn off `mailer_autoconfirm`.** Five minutes, and it is the only thing
   standing between this and being unfit to ship. Check it took with
   `GET <SUPABASE_URL>/auth/v1/settings` (publishable key as `apikey`): it
   must say `"mailer_autoconfirm": false`.
2. **Walk the full business path on device**: post an ad, post an announcement,
   post an event, then open the monthly report and confirm the numbers match what
   was posted. The data layer and report arithmetic are unit-tested; the wiring
   between them has only been seen in pieces.
3. Then `plan.md` Phase 5.

Minor: the Demo Kitchen seed is labelled Dickenson Bay but its coordinates
(17.1181, -61.7965) put it inland near Osbourn.

### The thing that is not a code task

Every phase so far has been engineering. Not one has been a conversation with a
business owner. `plan.md` §16 is blunt about this: the largest risks in the plan
are commercial, and none of them are technical. Whether anyone will actually pay
EC$25/50/100 a month is unknown and cheap to find out.

---

## 8. Commit conventions

Messages are written as **what was wrong and why it mattered**, not what changed.
Where a bug was found the long way round, the message says so — several exist
because an earlier commit claimed a fix that only made a symptom smaller.

Examples worth imitating:

- *"MapLibre surface was collapsing because Stack passes loose constraints"* —
  names the mechanism.
- *"Sign-out appeared to do nothing; the session mutated and nothing subscribed"*
  — names why the obvious fix was wrong.

Do not write "fix bug" or "update files". The history is the only record of why
the non-obvious choices were made.