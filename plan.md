# Plan — IslandAds

Status: Phases 0–2 complete. Planning continues; see section 14 for the
post-launch backlog.

## 1. Concept

A mobile map app of Antigua where businesses are listed, promoted, and kept up
to date. Built on Google Maps features but made distinct and personal to
Antigua. The core problem it solves: most Antigua businesses are bad at
maintaining their own advertising — outdated hours, dead socials, no search
presence. We own that upkeep for them.

Use case is advertising, not personal live location tracking. Users browse
places; we do not track individuals.

Primary revenue: businesses pay for placement. Premium subscribers hold a
Featured slot, ordered by earned popularity rather than by bid. Secondary:
international promotion with personalized marketing.

## 2. Decisions made

| Area | Decision |
| --- | --- |
| Name | IslandAds |
| Platform | Mobile app, both iOS and Android |
| Geography | Antigua only for now |
| Pricing | $50/mo basic, $100/mo premium, per business |
| Featured slot | Reserved for premium subscribers, unlimited capacity, positioned by the ranking system. No bidding. |
| Free trial | 3 days |
| Sales | Closed in person by a team member |
| Payment | Business pays by direct transfer. No app store cut. |
| Non-payment | Delist the business, after a grace period |
| Industries | All industries open, incl. online-only as its own category |
| Content flow | Business submits info → team implements → business self-updates via admin role, or texts the team on WhatsApp |
| Reviews | In app, from day one. Signed-in users only. Verified visit required. |
| Accounts | Required. Personalise reviews, track visits. |
| Trials | 3 days, both tiers. No conversion → listing removed. |
| Listings | 5–10 target businesses before launch |
| Map | Google Maps pins |
| Backend | Supabase, linked and live |
| Team | 4 people |
| Funding | Company bank account; earnings split equally between the four |
| Ranking | Earned by popularity, not bought |
| Competition | Businesses currently doing their own ads |

## 3. Pricing detail

**Basic — $50/mo**
- Map pin and listing
- Name, category, photos, hours, phone/WhatsApp
- Reviews
- Standard map position

**Premium — $100/mo**
- Everything in basic
- A spot in the Featured area (unlimited capacity)
- Promotional banner or highlighted card
- Offer/deal badge with a redemption code
- Priority in search

**Featured area**
- Premium subscribers only. No cap, so no artificial scarcity and no overflow.
- Order decided by the ranking system, not by bid.
- Premium buys the slot. Ranking decides the order inside it.

**Spotlight board — 10 slots**
- Second-tier rotating area, 10 slots.
- Serves the least-recently-featured first. Rotates weekly.
- Exists because a new premium subscriber scores zero and would sit last.

**Free trial**
- 3 days, both tiers. Used as a closing tool.
- No conversion → listing removed. A demo, not a free listing.

## 4. Feature set

**Core**
- Map of Antigua, all paying businesses as pins
- Category filters (8 categories, all industries)
- Business detail: description, photos, menu or services, hours, price range
- Click to call, click to WhatsApp with a prefilled message
- Open-now calculation, in Antigua time
- Offers / deals

**Reviews**
- Star rating and written reviews
- Business replies
- Report, dispute, and opt-out
- Business-verified visits only

**Business admin**
- Claim and verify a listing
- Edit hours, photos, menu, description, offers, specials, tags
- Analytics: views, calls, WhatsApp taps, review count
- Visit verification queue

**Billing**
- Direct transfer, tracked internally
- Lapsed → grace period → removed

## 5. Ranking model

Rank is earned, not bought. Governs search order and the Featured order.

```
rating   45%   Bayesian average, prior mean 3.8, weight 5
volume   25%   log(review count + 1) / log(61)
engaged  30%   log(views + 5*(calls + taps) + 1) / log(3001)
total           100 * (0.45*rating + 0.25*volume + 0.30*engagement)
```

Ties break on review count. Premium buys a Featured slot; ranking decides the
order inside it. Nobody buys a rating.

Businesses are shown their own position and what would move them — "you're 3rd
of 9 restaurants, and 4 more reviews would move you up." That keeps the
paid-versus-earned promise visible and gives owners something to act on.

## 6. Accounts and reviews

- Users sign in. No anonymous accounts.
- Reviews require a verified visit (section 7).
- Businesses reply, dispute, and may opt out entirely.
- Reviews go live immediately, moderated after the fact.

**Business verification is not a trust guarantee — it is a filter.** See
section 7; this is the most important design risk in the product.

## 7. Review integrity — the honest problem

The current design lets a business approve its own reviewers. That means a
business can approve the happy customers and quietly decline the rest, and its
rating drifts upward without anyone lying.

This is not a bug to be engineered away — it is structural. Any scheme where the
reviewed party gates the review will be gamed by any business with enough
patience to work out the pattern. Say so plainly in the sales pitch rather than
implying the ratings are clean.

Four mitigations, in order of how much they help:

1. **Require a reason when declining.** Cheap, and it changes the incentive
   from "silently drop the two-star reviews" to "write down why you dropped
   them". A pattern of thin reasons is visible to the team.
2. **Show the team "approved 9 of 10 requests" per business.** The team can
   audit any business whose approval rate looks selective.
3. **Team audits declines.** The moderation queue shows declined requests
   alongside their reason. Spot-checking is cheap when there are 10–50
   businesses.
4. **Verified visits as the primary gate.** See below.

A fifth, if the fourth works well enough to retire the approval queue:

5. **Show the approval rate publicly on the listing.** "Verified from 40
   visits, 31 reviews." Makes selective approval a visible cost. Only
   defensible once visit verification is trustworthy.

## 8. Visit verification — QR code at the till

The plan calls visits "tracked per user" without saying how. The demo used a
manual "Log a visit" tap, which is worthless: anyone can tap it, so it verifies
nothing.

**QR code at the till is the mechanism.** Each business has a rotating code.
The customer scans it from the app while at the business; the scan records the
visit.

Why it is better than the approval queue:
- The customer is physically present. No collusion needed.
- The business cannot selectively grant approval; it just shows the code.
- It scales without the business doing any work, which matters because owners
  will not maintain a queue.

Complications to design around:
- **Shared devices.** A till tablet is one device that many customers use.
  Verification needs the customer's own signed-in account, so either
  (a) a per-visit short code the customer enters, or
  (b) staff scan the customer's code and confirm, which reintroduces a human
  step. Option (a) keeps the queue empty; option (b) is easier to explain.
  **Decide before building.**
- **Code rotation.** A static printed QR lets one customer generate fake
  visits. Rotate per business per day, or per business per hour.
- **No signal.** Scanning must work offline and sync later.
- The scan also becomes the stamp-card hook later (section 14).

Keep the approval queue as a fallback for businesses that cannot display a QR
code, but treat it as the weaker path and audit it harder.

## 9. Data accuracy — the actual product

The pitch is that we maintain the listings. That makes accuracy features load
bearing, not nice to have.

- **"Closed today" one-tap state.** Hurricane season, public holidays, Carnival.
  A temporary closure that still shows "Open" costs a customer a wasted trip and
  costs us the argument.
- **Last verified date** on every listing, and a **"report wrong info"** button
  for users.
- **Nudge businesses that have not updated in 60 days.** The team chases, since
  the team owns accuracy.
- **Stale-listings report** for the team.
- **WhatsApp updates.** A business texts "closed today" or new hours and the
  team applies it. Many owners will never open an admin screen; this is how they
  actually will interact. Needs a dedicated number and a parsing routine.
- **Listing completeness score** so the team can see which listings are thin.

## 10. Retaining businesses

Businesses cancel when they cannot see results. A dashboard they never open does
not count.

- **Monthly WhatsApp results summary** to each business owner. "214 views, 18
  calls, 6 taps." Plain text, no login. This is the single highest-value
  retention feature.
- **Push notification when a review request arrives.** Otherwise the
  verification queue sits unseen and reviews never happen, which kills the
  ranking loop.
- **Pre-built listings.** Build a business's listing before pitching, then show
  it on the phone: "this is already yours." Makes the 3-day trial real from the
  first meeting.
- **Referral reward.** A free month when a business refers another. Sales is the
  bottleneck; this spreads it.

## 11. Practical details that drive use

- **Tags and filters:** cash only, accepts cards, accepts US$, parking,
  family-friendly, wheelchair access. "Cash only" is the most common surprise
  for a visitor. Cheap for the team to enter.
- **EC$ and US$** pricing display.
- **Full international phone numbers** (country code), for visitors roaming.
- **Directions button** opening the phone's maps app.
- **Free-text "how to find us"** — "past the roundabout, opposite the market".
  Island addresses are not street addresses.
- **Daily specials.** Restaurants post "catch of the day" or "sold out". Gives
  locals a reason to check back. Posted via WhatsApp by the team.
- **Request a quote** (trades): short form with a photo, lands with the
  business. Calling a plumber cold is awkward; this makes the trades category
  useful.
- **Request a slot** (tours, salons): date and time request delivered on
  WhatsApp. No booking system to build.
- **Share to WhatsApp** as a rich preview card. Most word of mouth runs there.
- **WhatsApp button prefilled**: "Hi, I found you on IslandAds", tagged with the
  listing so the business knows where the customer came from.
- **Offer codes.** Each offer shows a short code the customer says at the till.
  This is the offer redemption tracking that proves the app brings in people,
  which is what supports renewals.

## 12. Offline and reach

- **Cache listings.** Poor signal is normal. The app must work when roaming is
  off, especially for visitors.
- **Public web page per listing.** A simple link a business can put in its
  Instagram or Facebook bio. Opens the listing, offers the app download.
  Gives businesses the search presence they lack, and drives installs without
  paying for ads.
- **Location is used only while browsing and never stored.** This is what keeps
  the no-tracking promise in section 1 honest for "offers near me".

## 13. Build plan: scaffolding to release

Each phase ends in something demonstrable. Do not start the next until the
previous runs on a real phone.

### Phase 0 — Decisions and paperwork ✅
- Company registered, bank account open, equal-split agreement in writing
- Apple Developer and Google Play accounts
- Stack: Flutter, cross-platform

### Phase 1 — Scaffold ✅
- Flutter project, iOS + Android
- Project structure, design system ported 1:1 from the prototype
- CI workflow

### Phase 2 — Auth and accounts ✅
- Sign up, sign in, sign out, password reset, Google sign-in
- Three roles with route guards
- Supabase live: schema, RLS, role-escalation protection verified
- **Outstanding:** email confirmation blocks sign-up (SMTP rate-limited);
  Google sign-in untested end-to-end; no team admin accounts exist yet

### Phase 3 — Map core (weeks 4–5)
- Google Maps SDK, centred on Antigua
- Pins from the database, pan/zoom, tap → preview card
- Category filters, all 8 categories
- Open-now calculation
- Settle the hand-drawn SVG vs real tiles question first

### Phase 4 — Business listings (weeks 6–7)
- Listing screen: photos, description, menu/services, hours, price, location
- Click to call, click to WhatsApp with prefilled message
- **Directions button and "how to find us" field**
- **Tags**: cash only, accepts cards, accepts US$, parking, accessibility
- **"Closed today" toggle** — hurricane season and Carnival make this urgent
- **Last verified date, "report wrong info" button**
- Team backend for creating and editing listings

### Phase 5 — Discovery (week 8)
- Featured rail on the map screen, order from ranking score
- Search and sort
- Offers section and badges
- **Offer codes**
- **Share to WhatsApp**
- **Public web page per listing** (server-rendered, for social bios)

### Phase 6 — Reviews and visits (weeks 9–11)
- Rating and written review submission
- **QR-based visit verification** — rotating codes, offline-capable
- Business reply, dispute, opt-out
- **Require a reason when declining a request**
- Report button; team moderation queue
- **Team audit view: approval rate and decline reasons per business**
- **Push notification when a review request arrives**

### Phase 7 — Business admin and billing (weeks 12–14)
- Claim and verify a listing
- Edit hours, photos, menu, description, offers, specials
- **Daily specials posting**
- **Request a quote** (trades) and **request a slot** (tours, salons), both
  delivered on WhatsApp
- Analytics: views, calls, taps, review count
- **Rank explainer**: position within category and what would move it
- Subscription state set by the team when a transfer lands
- Grace period, then removal
- Spotlight board: 10 rotating slots

### Phase 8 — Ranking (week 15)
- Score from rating volume/average and engagement
- Recomputed on a schedule, not per request
- Drives Featured order and search priority

### Phase 9 — Seed content and field testing (weeks 16–17)
- Onboard the first 5–10 businesses; verify listings in person
- **Pre-built listings for the sales pipeline**
- **WhatsApp intake**: a number businesses text for hours changes and closures
- 3-day trials with the seed businesses
- Bulk import for the first listings; photo cleanup on upload

### Phase 10 — Release (weeks 18–19)
- TestFlight beta, Play Store internal testing
- Privacy policy and store assets
- Store submission; plan for review delays
- Soft launch

### Phase 11 — Public launch and growth (post-launch)
- Sales beyond the seed group, industry by industry
- **Monthly WhatsApp results summary**
- **Referral reward**
- Barbuda expansion, international promotion
- The section 14 backlog, in order

## 14. Post-launch backlog

**Add before launch** (the ones not already in the phases)
- Storm banner: team-run notice during hurricane season, linking to the
  official weather service, plus a "reopened after the storm" status
- Curated collections: team-written lists such as "Best pepperpot" or
  "Open on Sunday". This is local knowledge Google does not have, and it is
  shareable, which is most of the value.
- Open-late and Open-Sunday filters. On a small island these beat a general
  open-now filter.

**Getting users to open it**
- **Essentials layer.** A free, team-maintained set of places that are not paid
  listings: pharmacies, fuel stations, ATMs, the hospital. Locals would open the
  app for these on an ordinary day.
  **This conflicts with the rule that only paying businesses appear — decide it
  deliberately, not by drift.** See section 15.
- Events: Carnival, Sailing Week, Shirley Heights on a Sunday evening. Gives
  businesses a reason to post offers around real dates.

**Later**
- Saved places and trip lists for tourists
- Digital stamp card ("10th coffee free"), tied to the QR check-in
- Photos in reviews
- Pre-trip mode: international visitors browse and save before they arrive.
  Connects to the international promotion in section 1.

## 15. Open decisions

- **The essentials layer is a real contradiction.** The current promise is that
  the app only shows paying businesses, which is part of why a listing is worth
  paying for. A free essentials layer gives locals a daily reason to open the
  app and improves retention, but it weakens the exclusivity claim. Pick a
  position on purpose: either it is a small, clearly-labelled "essential
  places" set, or it does not happen. Do not let it grow by accident until paid
  businesses ask why they pay for a listing next to free ones.
- **QR verification method.** Customer scans, or staff scans the customer's
  code. Decide before Phase 6 (section 8).
- **Hand-drawn SVG map or real Google Maps tiles?** The prototype hand-draws the
  island. It looks distinctive but cannot pan, zoom, or show a user.
- Custom map pins, or hue-tinted default markers?
- Bundle the three prototype fonts, or accept system fallbacks?
- Revenue split: equal, but who covers refunds, bad debt, and the chasing?
- Who holds the Apple and Google credentials?
- App store billing was dropped in favour of transfer, so someone marks
  subscriptions active by hand. Automate from a bank feed or accept the manual
  step, and name who owns it.
- Public web pages: which host, and does the domain go on them or on the app
  download page?

## 16. Principles

- Original design, minimal AI-generated look. Local credibility is the product.
- Listings must be accurate and current — that is the whole pitch.
- Keep the paid/earned distinction honest and visible.
- Do not claim the reviews are clean. They are verified visits filtered by the
  business, and the app says so.