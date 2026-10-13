# IslandAds

A mobile map app of Antigua where businesses are listed, promoted, and kept up
to date. Businesses pay for placement. See `plan.md` for the full plan.

## Status

Phase 2 complete. Scaffolding, design system, and auth are in place. Map,
listing, and dashboard screens are still stubs.

## Structure

```
plan.md                    master plan and build phases
docs/
  build-environment.md     READ THIS before running flutter on this machine
  previewing-ui.md         how to see the UI, emulator setup
  disk-space.md            the disk-full trap and what is safe to delete
  design/design-system.md  colours, type, spacing — source of truth
  business/business-rules.md ranking, subscriptions, reviews
  legal/                   entity, profit split, privacy policy
app/                       Flutter app, iOS + Android
  lib/core/                config, routing, theme
  lib/models/              Business, Review, User, categories
  lib/services/            auth, ranking, opening hours, filtering
  lib/features/            one folder per feature area
backend/                   Supabase schema, RLS policies (not yet created)
ops/                       onboarding, sales, moderation
builds/                    compiled APKs (gitignored)
```

## Backend

**Supabase, live.** Project `antiguamap`, schema and RLS applied, role-escalation
protection verified against the real database. See `backend/README.md`.

Local keys are in `.env` (gitignored). To run the app against Supabase:

```powershell
flutter run --dart-define=SUPABASE_URL=https://... --dart-define=SUPABASE_ANON_KEY=...
```

Without them the app falls back to in-memory mock auth, so it still runs.

**One thing blocking real sign-ups:** email confirmation is on and Supabase's
bundled SMTP is rate-limited. Turn it off in the dashboard for development.

## Decisions

See `plan.md` section 2. Short version: **EC$25 growing / EC$50 basic / EC$200
featured** per month (negotiable), unlimited featured Featured slots ordered by
earned ranking, 10 rotating Spotlight slots, 3-day trial with a 7-day hold on
expiry, guest browsing, business-verified reviews, payment by direct transfer,
Antigua only.

## Running it

**Check disk space first** — this machine has filled up during builds, and the
errors do not mention it. See `docs/disk-space.md`.

`flutter analyze` and `dart format` work from `app/`. Everything that compiles
native code (tests, builds, runs) needs the space-free mirror because of the
space in the Windows username — see `docs/build-environment.md`.

Android is the only target that currently builds reliably. There is an emulator
AVD (`antigua_api35`). See `docs/previewing-ui.md`.

## Next

Phase 3 — the map. Settle the hand-drawn SVG map vs Google Maps question first;
it is in the open questions at the bottom of `plan.md`.