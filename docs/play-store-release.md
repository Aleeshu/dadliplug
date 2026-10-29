# Play Store release: version 1.0.0

## The file

`builds/dadliplug-release.aab`, built with:

```powershell
.\scripts\build-apk.ps1 -Bundle -Mirror C:\antigua-app
```

Signed with the upload key (`docs/android-signing.md`). Package
`com.dadliplug.app`, version 1.0.0 (version code 1). Every later upload needs a
higher version code: bump `version:` in `app/pubspec.yaml` (1.0.1+2, 1.0.2+3…).

## Before uploading

- [ ] `.env`: set `SUPPORT_EMAIL` and `TEAM_WHATSAPP`, then rebuild. They are
      built into the app (legal pages, About, "Tell the team on WhatsApp",
      "Choose plan").
- [ ] A lawyer has read `app/assets/legal/privacy.md` and `terms.md`
      (Data Protection Act 2013).
- [ ] Deploy the Worker (`workers/listing-page`, `npx wrangler deploy`) so
      these URLs are live; Play asks for them:
      - Privacy policy: `https://dadliplug-listing.listing-page.workers.dev/privacy`
      - Account deletion: `https://dadliplug-listing.listing-page.workers.dev/delete-account`
- [ ] Google Play Developer account (one-time US$25) in the name the app is
      sold under (plan.md 15: who holds the credentials).
- [ ] Turn on **Play App Signing** (the default). After the first upload, add
      Play's app-signing SHA-1 to the Android OAuth client (Google sign-in) and
      to the Maps key restriction (`docs/android-signing.md`).

## Store listing (draft)

**App name:** Dadliplug

**Short description (80 characters max):**
Antigua & Barbuda's local businesses, deals and events, on one map.

**Full description:**

> Dadliplug is Antigua and Barbuda's local promotion and discovery app.
>
> - Find businesses on the map: food, shops, salons, services, tours and more,
>   with what is open now, open late and open on Sunday.
> - See what is fresh: new ads, deals, today's specials and this week's events.
> - Claim deals and show your code at the till.
> - Book a table, request a quote or a slot, and message businesses in the app
>   or on WhatsApp.
> - Read reviews from people who actually visited: every review comes from a
>   QR check-in at the business.
> - The community bulletin board: jobs, items for sale, notices and
>   opportunities, checked by our team before they appear.
>
> For businesses: list your business, post ads and deals, see your views,
> clicks and enquiries every month, take bookings and messages, and move your
> pin to your door. Plans from EC$25 a month, with a free 3-day trial.
>
> Rank is earned, never bought: paid placements are always labelled.

**Category:** Maps & Navigation (or Lifestyle). **Tags:** local, deals,
directory.

**Graphics needed:** 512×512 icon (`app/assets/images/app_icon_source.png`
resized), 1024×500 feature graphic, at least 2 phone screenshots (Home, a
business page, the map, deals).

## App content answers

**Privacy policy:** the URL above.

**App access:** most of the app works without an account. Business and team
tools need sign-in. Give Google's reviewers a test business account (email and
password) that manages a demo listing, so they can see the business tools.

**Ads:** No. The app shows businesses' own promotions inside the app, not an
ad network. Answer "No, my app does not contain ads".

**Content rating:** user-generated content (reviews, board posts, messages)
with reporting and moderation; no violence, no gambling.

**Target audience:** 18 and over (businesses and adult customers). Not
designed for children.

**Data safety** (matches `privacy.md`):

| Data | Collected | Shared | Why | Optional |
| --- | --- | --- | --- | --- |
| Email address, name | Yes | No | Account | Yes (browsing needs no account) |
| Approximate location | No: used on the phone only, never sent | No | — | — |
| Photos | Yes, only those a user uploads | Shown publicly on the listing or post | App functionality | Yes |
| Messages (in-app) | Yes | No | App functionality | Yes |
| Reviews, board posts | Yes | Shown publicly | App functionality | Yes |
| App interactions (views, taps) | Yes | No | Analytics for businesses | No |
| Device ID (push token) | Yes | No | Notifications | Yes |

Data is encrypted in transit. Users can delete their account in the app
(Profile → Delete account) and on the web (`/delete-account`).

**Payments:** none in the app. Business plans are paid by bank transfer outside
the app.

## Rollout

1. Internal testing track first (the team's four accounts), then closed
   testing with seed businesses (plan.md Phase 10), then production.
2. Expect the first review to take several days.
