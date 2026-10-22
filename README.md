# Dadliplug

*Plug into local.* A mobile map and directory of businesses in Antigua and
Barbuda. Businesses pay a monthly plan to be listed and promoted; the team keeps
every listing accurate; customers find what is open, read verified reviews and
message businesses on WhatsApp. Rank is earned, never bought.

The full plan, with every phase and decision, is `plan.md`. Earlier code and
docs call the app **IslandAds**; it was renamed Dadliplug on 2026-10-15.

## Status (2026-10-22)

8 of 13 phases complete, 4 in progress, 1 not started. The table in
`plan.md` section 13 is the source of truth.

| Phase | Status |
| --- | --- |
| 0–5 Decisions, scaffold, auth, map, listings, discovery | ✅ |
| 6 Reviews and visits | ✅ code; two-phone check pending |
| 7 Business admin and billing | Nearly: moving and customising the map pin |
| 8 Ranking | ✅ |
| 9 Validate the business model | Tools built; owner interviews to do |
| 10 Seed content and field testing | Tools built; onboarding to do |
| 11 Release | Store requirements built; accounts, legal review, submission to do |
| 12 Public launch | Not started |

## What is built

**Customers:** Google map of every listing with category, open-now, open-late
and open-Sunday filters; search and sort by earned rank or distance; listings
with photos, hours, menu, offers and codes, daily specials, events and
announcements; call, WhatsApp, directions inside the app; request a quote,
slot or viewing on WhatsApp; save and follow; verified reviews after a QR
check-in at the till; Featured page, weekly Spotlight, the team's curated
collections, per-category leaderboards; storm notices; guest browsing.

**Businesses:** claim a listing; edit it; post ads, offers, announcements,
events and daily specials; monthly report; rank explainer with weekly
movement; reply to and dispute reviews; visit QR code; plan and billing
status; message the team on WhatsApp.

**Team:** listings backend, pre-built (hidden) listings with a private
preview link, verify in person, bulk import, billing with trials and holds,
moderation (reviews, claims), ranking and Spotlight screens, notices and
collections, leads with the Phase 9 answers.

**Store requirements:** delete account in the app, hide a reviewer, report
content, privacy policy and terms (in the app and on the web).

## Structure

```
plan.md                     master plan, phases, decisions
app/                        Flutter app, Android + iOS (com.dadliplug.app)
  lib/core/                 config, routing, theme
  lib/models/               Business, Review, User, categories
  lib/services/             repositories, ranking, billing, opening hours
  lib/features/             one folder per screen area
  assets/legal/             privacy policy, terms, account deletion (Markdown)
  test/                     unit and widget tests
supabase/
  migrations/               schema, RLS, functions, pg_cron jobs
  functions/listing/        public listing page and owner preview
  functions/push/           Firebase Cloud Messaging sender
backend/README.md           the Supabase project: ref, region, how to apply migrations
workers/listing-page/       Cloudflare Worker: /l/<id>, /p/<token>, legal pages
ops/                        manual team processes (onboarding, moderation); to write up
scripts/
  build-apk.ps1             Android build with dart-defines from .env
  import_listings.py        CSV -> pre-built listings, checked first
  check_anon_guards.py      every guarded function refuses anonymous callers
docs/
  handover.md               how everything fits; read first
  build-environment.md      the space-in-the-path workaround
  android-signing.md        app id, fingerprints, the upload key
  ios-release.md            Apple, Google and Firebase steps to TestFlight
  validation/               owner interview guide, pricing decision rules
  design/, business/, legal/
builds/                     compiled APKs (gitignored)
```

## Stack

Flutter (Riverpod, go_router, google_maps_flutter) · Supabase (Postgres with
Row Level Security, security-definer functions, pg_cron, Edge Functions,
Storage) · Firebase Cloud Messaging · Cloudflare Workers.

## Setup

Configuration lives in `.env` at the repo root (gitignored; see
`.env.example`) and reaches the app as dart-defines:

| Key | Purpose |
| --- | --- |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Backend (the anon key is public by design) |
| `GOOGLE_MAPS_API_KEY` | The map, Android and iOS |
| `GOOGLE_SIGN_IN_WEB_CLIENT_ID` | Google sign-in (server client) |
| `GOOGLE_SIGN_IN_CLIENT_ID` / `GOOGLE_SIGN_IN_IOS_CLIENT_ID` | Google sign-in per platform |
| `SUPPORT_EMAIL` | Contact line on legal pages and About |
| `TEAM_WHATSAPP` | "Tell the team on WhatsApp" for owners |

Never in the repo: `.env`, `app/android/app/google-services.json`,
`app/android/key.properties` and the upload keystore, Firebase admin keys.
Without Supabase keys the app runs on in-memory mock auth.

## Building

The Windows username has a space, which breaks Gradle and native builds, so
builds run from a space-free mirror (`docs/build-environment.md`):

```powershell
.\scripts\build-apk.ps1 -Mirror C:\antigua-app            # debug APK -> builds\
.\scripts\build-apk.ps1 -Mirror C:\antigua-app -Release   # signed with the upload key
```

A build takes about 30 minutes on this machine. Do not run the emulator
(`antigua_api35`) during a build: together they run out of memory.

**iOS** builds only on a Mac. GitHub Actions builds it on every push to
`main` (`.github/workflows/flutter.yml`, unsigned until there is an Apple
Developer account). See `docs/ios-release.md`.

## Checks

- `flutter analyze` must report no issues; `flutter test` must pass
  (278 tests).
- After any migration that adds or changes a guarded function:
  `python scripts/check_anon_guards.py`.
- CI (GitHub Actions) runs format, analyze, tests, and Android and iOS
  builds on every push to `main`.

## Pricing

EC$25 Growing, EC$50 Basic, EC$100 Featured per month, paid by bank transfer;
3-day trial on any plan; 7-day hold before a lapsed listing is hidden. Still
to be tested with owners (Phase 9, `docs/validation/pricing-test.md`).
