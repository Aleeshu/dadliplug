# Plan — IslandAds (app name: Dadliplug)

Status: Phases 0–3 complete, Phase 4 code complete, Phase 5 in progress.
Planning continues; see section 14 for the post-launch backlog.

## 1. Concept

A mobile map app of Antigua where businesses advertise, are listed, promoted,
and kept up to date. The core problem it solves: most Antigua businesses are
bad at maintaining their own advertising — outdated hours, dead socials, no
search presence. We own that upkeep for them, and they own the content.

**The pitch is advertising, not discovery.** The app exists so businesses can
get their message out more efficiently than a Facebook post reaches. The map,
the categories, and the leaderboard are what make that reach land: an
advertisement only works if people nearby can find it.

Customers and businesses share one app but get different navigation, because
they are doing different things. Customers browse, search, bookmark, and
review. Businesses post advertisements and announcements, run events, and read
their numbers. Customers may browse as guests.

Use case is advertising, not personal live location tracking. Users browse
places and see what is near them; we do not track individuals.

Primary revenue: monthly subscriptions from businesses. Featured subscribers
hold a Featured slot, ordered by earned popularity rather than by bid.
Secondary: international promotion with personalized marketing.

## 2. Decisions made

### Currency — corrected

**All prices in this document are in Eastern Caribbean dollars (EC$).** This was
previously written as US dollars, which made our pricing look 3–5x the local
market when it is in fact inside it. Corrected after confirming with the
business owner that the published figures are EC$.

| Tier | EC$ | ~US$ |
| --- | --- | --- |
| Growing | **EC$25** | ~$9 |
| Basic | **EC$50** | ~$19 |
| Featured | **EC$100** | ~$37 |
| Typical small business ad (external estimate) | EC$10–25 | — |
| Typical monthly subscription (external estimate) | EC$49–99 | — |

Growing and Basic sit deliberately at or below the local range. Featured is
twice Basic and is the only tier that buys visibility, so the price gap does
the work of segmenting instead of a feature checklist.

Note the history: Featured was briefly **EC$200** while the tiers were being
first written out, and has been brought back to **EC$100**. Twice Basic is a
large enough step to read as a real decision without making the top tier feel
out of reach for the Antigua businesses this is aimed at. It is untested and
belongs in the Phase 9 conversations.

Revenue logic, in the owner's words: the goal is gross income, not monthly
income per subscriber. Keep it affordable, keep it negotiable, and the numbers
add up. That is why pricing sits where it does rather than at a maximum.

Antiguan businesses do not yet see marketing as necessary. Price is therefore
part of the pitch, not a concession.

| Area | Decision |
| --- | --- |
| Name | IslandAds (beta) — *Island Advertisements* is the working name |
| Platform | Mobile app, both iOS and Android |
| Geography | Antigua only for now |
| Pricing | **EC$25/mo growing, EC$50/mo basic, EC$100/mo featured**, per business. Negotiable. |
| Featured slot | Reserved for featured subscribers, unlimited capacity, positioned by the ranking system. No bidding. Plus a verified badge. |
| Free trial | 3 days, every tier, all paid tools unlocked |
| Trial expiry | Listing is **held for 7 days** before anything is deleted. Owner can pay in that window and pick up exactly where they left off. |
| Non-payment | Same 7-day hold, then the listing is terminated. Written into the terms. |
| Sales | Closed in person by a team member |
| Payment | Business pays by direct transfer. No app store cut. |
| Industries | All industries open, incl. online-only as its own category |
| Content flow | Business signs in, edits their own listing directly. The team maintains and updates on their behalf as the fallback for owners who will not use the tools. |
| Reviews | In app, from day one. Signed-in users only. Verified visit required. |
| Accounts | Customers may browse as a **guest**. Sign-in is required only to review, bookmark, follow, or run a business. |
| Onboarding | First screen asks: **are you a business, or a customer?** |
| Listings | 5–10 target businesses before launch |
| Map | Google Maps (moved from MapLibre/OpenFreeMap on 2026-10-14). Free tier covers mobile map loads; restrict the key before launch |
| Backend | Supabase, linked and live |
| Team | 4 people |
| Funding | Company bank account; earnings split equally between the four |
| Ranking | Earned by popularity, not bought |
| Competition | Businesses currently doing their own ads |

## 3. Pricing detail

Three tiers. All prices EC$, per business, per month. All negotiable — see the
currency note in section 2.

**Growing — EC$25/mo**
- Map pin and listing
- Name, category, photos, hours, phone/WhatsApp
- Reviews
- Standard map position
- Social links
- Bio / menu / facts
- Announcements and events calendar
- **No pin customisation.** The default pin only.

Target: small and online-only businesses that want presence and recognition
without a commitment. The cheapest rung on the ladder, and the one that makes
"get in touch and be one of the first to appear" a real offer rather than a
promise.

**Basic — EC$50/mo**
- Everything in Growing
- **Customisable pin image**, to make the pin itself attract a click
- Pin movable by the business at any time
- Views analytics
- Monthly reports

Target: a stable business that is doing fine and wants more customers coming
through the door. The workhorse tier, and the one most likely to be the default
in the sales pitch.

**Featured — EC$100/mo**
- Everything in Basic
- A place on the separate **Featured page**, filtered out from other results
  and recommended to customers
- **Verified badge** next to the business name
- Promotional banner or highlighted card
- Offer/deal badge with a redemption code

Target: the already-successful business that wants to elevate its marketing and
talk to its customers directly. At 2x Basic the jump has to be worth it, so
Featured has to carry visible weight rather than extra list items.

**Featured page**
- Featured subscribers only, filtered out of other lists so they cannot crowd
  ordinary results.
- Order decided by the ranking system, not by bid.
- The verified badge is the trust signal: it says the business pays for a
  listing, not that its reviews are clean. Never present it as an endorsement
  of quality.

**Spotlight board — 10 slots**
- Second-tier rotating area, 10 slots.
- Serves the least-recently-featured first. Rotates weekly.
- Exists because a new featured subscriber scores zero and would sit last.

**Free trial**
- 3 days, **every tier**, with all paid tools unlocked. The point is to prove
  the tools work, not to give away a listing.
- On expiry the listing is **held for 7 days**, not deleted. The owner can pay
  at any point in that window and resume with all their data intact.
- After 7 days the listing and its content are terminated.
- This rule applies identically to anyone who later misses a payment. It goes
  in the terms and conditions, stated plainly rather than buried.

## 4. Feature set

**Consumer-facing**
- Map of Antigua, all active businesses as pins
- Category filters: the design's nine — Food & Drink, Shopping, Services,
  Health & Beauty, Entertainment, Automotive, Real Estate, Education, Other
  (replaced the prototype's eight on 2026-10-15). A business with no location
  has no pin and no leaderboard place, whatever its category
- **Near me** — businesses sorted by the viewer's own location. Not a
  locator app; it exists so someone standing in Dickenson Bay is told what is
  around them.
- Business profile: description/bio, photos, menu or services, hours, price
  range, phone, email, location, social links, announcements, events, and the
  advertisements the business has posted
- Click to call, click to WhatsApp with a prefilled message
- Open-now calculation, in Antigua time
- Offers / deals with redemption codes
- **Bookmarks** — save a business
- **Follow** a business — get notified when it posts an announcement
- **Leaderboards** per category — "Top 10 Food businesses by popularity"
- **Browse as a guest.** No account required to look. Sign-in is only needed to
  review, bookmark, follow, or run a business.

**Reviews**
- Star rating and written reviews
- Business replies
- Report, dispute, and opt-out
- Business-verified visits only

**Advertisements**
- Businesses post advertisements to their own profile: image, text, and a
  link out
- Ads are dated, so the team and the business can see whether an ad is still
  live
- This is the literal pitch — *"an app solely made for businesses to advertise
  in Antigua"*. The directory is the top of the funnel; the ads are what a
  business renews for. Track views per ad, because that is the number in the
  month-end report.

**Announcements and bulletin board**
- One-way broadcast from business to customers: notices, closures, offers
- Customers who follow a business get notified
- Read receipts, so a business knows an announcement was actually seen

**Events calendar**
- Businesses post upcoming events
- A customer-facing calendar aggregating events across businesses
- Gives locals a reason to open the app on a given week. Carnival, sailing week
  and Shirley Heights are the obvious first entries.

**Business admin**
- Claim and verify a listing
- Edit everything on the profile: hours, photos, menu, description, socials,
  offers, specials, tags
- Move and customise the map pin
- Post advertisements, announcements, events
- **Views analytics** — views on the pin, views per advertisement, calls,
  WhatsApp taps, review count
- **Monthly report** — issued at the end of each month: views gained per
  advertisement, and a breakdown of one through five star ratings. Written to
  show growth over time, not just a total
- Visit verification queue

**Billing**
- Direct transfer, tracked internally
- Lapsed → **7-day hold** → terminated, with the data intact until the end

## 5. Ranking model

Rank is earned, not bought. Governs search order and the Featured order.

```
rating   45%   Bayesian average, prior mean 3.8, weight 5
volume   25%   log(review count + 1) / log(61)
engaged  30%   log(views + 5*(calls + taps) + 1) / log(3001)
total           100 * (0.45*rating + 0.25*volume + 0.30*engagement)
```

Ties break on review count. Featured buys a Featured slot; ranking decides the
order inside it. Nobody buys a rating.

Businesses are shown their own position and what would move them — "you're 3rd
of 9 restaurants, and 4 more reviews would move you up." That keeps the
paid-versus-earned promise visible and gives owners something to act on.

### Leaderboards — two audiences, same ranking

A per-category leaderboard ("Top 10 Food businesses by popularity") built from
this same score. Two reasons it exists, and they pull in opposite directions:

- **For customers:** separates the good from the great, using reviews from
  people who actually went. This is the feature that makes the review gate
  worth the inconvenience.
- **For businesses:** shows competitors what they are doing to win customers.

That second audience is the sharp edge. The stated goal is for businesses to
keep each other honest — inactivity falls behind and competition intensifies.
But a leaderboard that punishes a new listing for having no reviews yet makes
the app hostile to exactly the small business Growing targets.

Resolve it the same way as everywhere else in the product: show the score and
the mechanics, not just the rank. "5 of 9 restaurants" with the inputs visible
is motivating; a bare "you are 9th" is discouraging and will read as
discouragement dressed up as meritocracy. Fresh listings stay off the board for
a 30-day grace period (decided; see Phase 8).

## 6. Accounts and reviews

- **Customers may browse as a guest.** No account to look at businesses, read
  profiles, or see the leaderboards.
- **Sign-in is required to review, bookmark, follow, or run a business.**
  Guests can read everything and act on nothing, which is the intended
  incentive to sign up.
- Sign-in is via Google account or email and password (both are built; see Phase 2).
- Reviews require a verified visit (section 8).
- Businesses reply, dispute, and may opt out entirely.
- Reviews go live immediately, moderated after the fact.
- **The opening screen asks whether the visitor is a business or a customer**,
  because the two get entirely different navigation (section 6a). Guessing
  wrong and landing a customer inside a business dashboard is the worst
  possible first impression, and most Antigua businesses have never used a
  directory before.

**Business verification is not a trust guarantee — it is a filter.** See
section 7; this is the most important design risk in the product.

## 6a. Roles and navigation

Two audiences, two tab sets. This is a structural split, not a preference:
a business owner manages a listing, a customer browses, and cramming both into
one tab bar makes both worse.

**Business tabs:** Home · Profile · Reviews · Announcements · Ads
**Customer tabs:** Home · Categories · Map · Saved · More (Dadliplug design,
2026-10-15). Events and the Bulletin Board live under More. The Bulletin Board
is business posts only; user posts (For Sale, Jobs, Lost & found) wait until
there is moderation and report-a-post for them.

Shared surface (profile, reviews, announcements) behaves differently by role:

| | Business | Customer |
| --- | --- | --- |
| Profile | Edit everything | View only |
| Reviews | Reply, dispute, opt out, read the verification queue | Write a review |
| Announcements | Post, see read receipts | Read, follow businesses |
| Ads | Post, see views per ad | View |
| Billing | Tier, trial countdown, reports | — |

- **Customers can only view what the business shows.** There is no customer
  edit path onto a business profile.
- **Paying businesses get an admin role** scoped to *their own listing only*.
  An admin role that could edit another business's profile would be a
  trust problem from day one, and RLS should enforce that scope rather than
  relying on the UI to hide the buttons.

### Trial as onboarding

A new business signs in with Google, picks a tier, and gets 3 days with every
paid tool unlocked — pin customisation, ads, analytics, the lot. The trial is
also how the team builds the listing: most trial businesses will not fill in a
full profile, so the team fills it in and hands it over, which is the fastest
path to a live listing that does not look empty.

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
- **Guest browsing** — customers read listings, profiles and leaderboards with
  no account. Sign-in is only required to review, bookmark, follow or run a
  business
- **Opening choice** — first screen asks business or customer, before sign-in.
  Continue stays disabled until something is picked
- **Two tab sets** per section 6a: customer gets Home/Bookmarks/Calendar/Notices,
  business gets Home/Profile/Reviews/Notices/Ads. "Notices" is the in-app label
  for Announcements
- **Outstanding:** Google sign-in untested end-to-end; no team admin accounts
  exist yet; email auto-confirmation is still on (see section 15)

**Sign-in verified.** A real account was created through GoTrue signup: signup
returns a session, sign-in returns valid access and refresh tokens, an
`auth.identities` row exists (the thing the old SQL-created account lacked), the
profile trigger fires, and RLS permits the owner to read their own row while
correctly hiding it from anonymous requests. `claim_team_admin` correctly
refuses a second user because the bootstrap window closes permanently once a
team admin exists.

That exercise found a real bug: sign-out called Supabase successfully and
logged it, but the profile screen went on rendering the signed-in account,
because `AuthSession` mutated in place and nothing had subscribed to it. The
session is now a `ChangeNotifier` and the affected screens rebuild. Fixed and
verified on device.

**Still outstanding:** Google sign-in has never been completed on a device.
Email sign-in works; the Google account chooser opens and has not been carried
through to a confirmed session.

### Phase 3 — Map core (weeks 4–5) ✅
- Google Maps, centred on Antigua (originally MapLibre; switched 2026-10-14)
- Pins from the database, pan/zoom, tap → preview card
- Category filters, all 8 categories
- Open-now calculation
- Layout verified on device; the map renders behind the empty state rather than
  being replaced by it

### Phase 4 — Business listings (weeks 6–7)
- Listing screen: photos, description/bio, menu/services, hours, price, location
- **Social links on the profile** — Instagram, Facebook, TikTok, website, plus a
  separate WhatsApp business line. Handles stored bare so nothing can render as
  anything but a link
- **Live advertisements at the top of the listing**, dated, ended ones hidden
  but not deleted
- **Most recent announcement**, so a closure notice reaches someone who never
  opens the Notices tab
- **Upcoming events only** — a listing advertising last month reads as
  unmaintained
- Click to call, click to WhatsApp with prefilled message
- **Directions button and "how to find us" field**
- **Tags**: cash only, accepts cards, accepts US$, parking, accessibility
- **"Closed today" toggle** — hurricane season and Carnival make this urgent
- **Last verified date, "report wrong info" button**
- Team backend for creating and editing listings
- **Posting screens** for advertisements, announcements and events, with
  client-side validation so a bad field is named rather than surfacing as a
  constraint violation. Ending an ad sets an end date rather than deleting it,
  so its view count survives for the report it feeds
- **Monthly report**: views per advertisement, listing views, calls, WhatsApp
  taps, visits, and a one-to-five star breakdown. Month boundaries computed in
  Antigua time, not device time, so a phone set elsewhere cannot split a month
  and silently drop a day of a paying customer's numbers. Only verified reviews
  count
- **Team backend**: a Listings tab for the team to create any listing, set its
  plan, and open the same business tools an owner gets
- **Engagement counting**: views, calls, WhatsApp taps and ad views recorded as
  timestamped events, owners' own taps excluded, so the report is genuinely
  monthly
- **Code complete.** Two demo listings are seeded and the database side is
  verified live. **Remaining:** walk the whole posting-to-report path on a
  device (handover section 7).

### Phase 5 — Discovery (week 8)
- Featured rail on the map screen, order from ranking score ✅
- **Featured page** and **verified badge** ✅ — badge explained as a paid
  placement, never an endorsement; what "verified" should mean is still open
  (section 15)
- Search and sort ✅ — Best (earned rank), Near me, Top rated, A–Z. Featured
  businesses stay in search results at their earned place
- **Near me**, using the viewer's own location ✅ — coarse, asked only when
  chosen, never stored
- **Bookmarks and follow**, with notification opt-in ✅ — Save (heart) plus a
  per-business bell; alerts show in-app (Home bell badge, Bulletin Board
  "Following"). **Push waits on a Firebase project**
- Offers section and badges ✅ — Offers screen, Home "Latest Offers", OFFER tag
- **Offer codes** ✅ — an ad with a code is an offer; Featured/trial only,
  enforced by the database; the business taps "Redeemed +1" and redemptions
  show in the monthly report
- **Share to WhatsApp** ✅ (with the public page link, for a preview card)
- **Public web page per listing** ✅ — `https://dadliplug-listing.listing-page.workers.dev/l/<id>`.
  Rendered by `supabase/functions/listing`; served as HTML by the Cloudflare
  Worker in `workers/listing-page` (Supabase alone serves it as text/plain).
  Share to WhatsApp now includes it, so WhatsApp shows a preview card
- **Events as their own listing** (Dadliplug design): picture, venue, tags,
  organiser, website, phone, own page, Save Event; calendar with event days

### Phase 6 — Reviews and visits (weeks 9–11) — in progress
- Rating and written review submission ✅ — only through `submit_review()`,
  which requires a checked-in visit (or an approved request)
- **QR-based visit verification** ✅ — decided 2026-10-15: the **customer
  scans the till QR** (section 8, option a). Code rotates at Antigua midnight;
  typed-code fallback; offline scans queue and sync within 3 days
- Business reply, dispute ✅; opt-out uses the existing `accepts_reviews`
- **Require a reason when declining a request** ✅ (5+ characters, enforced
  by the database)
- Report button; team moderation queue ✅
- **Team audit view: approval rate and decline reasons per business** ✅
- **Push notification when a review request arrives** — waits on Firebase
- Fixed on the way in: a signed-in user could insert a review already marked
  verified, promote their own review to verified, or insert a visit already
  confirmed. All writes now go through database functions
- **Remaining:** see these on a device end to end (show QR → scan → review →
  reply → report → moderate)

### Phase 7 — Business admin and billing (weeks 12–14)
- Claim and verify a listing
- Edit hours, photos, menu, description, offers, specials, socials
- **Move and customise the map pin** (Basic and above; Growing keeps the default
  pin, and the team corrects its position on request)
- **Posting advertisements**, with views counted per ad
- **Announcements**, with read receipts
- **Events calendar**, per business and aggregated for customers
- **Daily specials posting**
- **Request a quote** (trades) and **request a slot** (tours, salons), both
  delivered on WhatsApp
- Analytics: views, calls, taps, review count
- **Monthly report**, issued at month end: views per ad plus a 1–5 star breakdown
- **Rank explainer**: position within category and what would move it
- **Three-tier subscription state** (Growing / Basic / Featured) set by the team
  when a transfer lands ✅ — Team tools -> Billing; each payment logged with who
  recorded it and the transfer reference
- **3-day trial with a 7-day hold on expiry**, data preserved until the hold ends ✅
  — advanced daily by pg_cron. Decided: held listings stay visible (overdue);
  after the hold they are hidden, not deleted
- Spotlight board: 10 rotating slots
- **Scope check (proposed, not decided):** this phase carries ads, announcements,
  events, quotes, slots, reports, billing and Spotlight in three weeks. Quote and
  slot requests, read receipts, the events calendar and Spotlight are the
  candidates to move past launch if the weeks do not hold.

### Phase 8 — Ranking (week 15)
- Score from rating volume/average and engagement
- **Per-category leaderboard**, "Top 10 Food businesses by popularity"
- **One-month grace period, decided.** A listing stays off the board for 30 days
  after it goes live. Ranked honestly a new listing has no reviews and no views,
  so it sits dead last and the board measures who signed up first. That punishes
  exactly the small and online businesses Growing targets, and contradicts the
  intent of showing competition rather than seniority. A month gives a business
  time to be found and visited; after that a low position means something.
  Businesses are told when they will appear rather than being silently absent.
- **Online-only businesses are not ranked at all** — no pin, no walk-in traffic,
  so the comparison is meaningless
- **A category with nothing eligible gets no board**, rather than an empty
  "Top 10"
- **Featured buys a slot and a badge, never a position.** Covered by a test
- **Rank inputs count unique users.** Exclude owner and team devices from views,
  calls and taps, or a business can tap its own number to climb.
- Recomputed on a schedule, not per request
- Drives search order and the order inside the Featured page

### Phase 9 — Validate the business model (week 16)
- **Start now, not at week 16.** Run these alongside the build, because every
  phase before this one is engineering and the answers can change what gets built.
  This phase is where the pricing test is closed out and the decisions are made.
- Twenty conversations with business owners: how do they advertise today, what
  frustrates them, what do they pay, what would they pay us.
- Test pricing in EC$ against the real answer, not against our assumption.
- Confirm whether owners want the team maintaining their listing or want to
  edit it themselves.
- Decide the essentials-layer question (section 15) with real reactions rather
  than on paper.

Placed here deliberately. Every phase before it has been engineering, and not
one has been commercial. Launching at Phase 10 with pricing and positioning
already fixed and unvalidated is the risk this phase exists to remove.

### Phase 10 — Seed content and field testing (week 17)
- Onboard the first 5–10 businesses; verify listings in person
- **Pre-built listings for the sales pipeline**
- **WhatsApp intake**: a number businesses text for hours changes and closures
- 3-day trials with the seed businesses
- Bulk import for the first listings; photo cleanup on upload

### Phase 11 — Release (weeks 18–19)
- TestFlight beta, Play Store internal testing
- Privacy policy and store assets; check obligations under Antigua's data
  protection law before collecting accounts and reviews
- **Check before submitting:** whether Google sign-in means the iOS app must also
  offer Sign in with Apple (guideline 4.8); the user-generated-content rules for
  reviews (reporting, blocking, a moderation contact); and whether unlocking paid
  tiers after an outside bank transfer is allowed (guidelines 3.1.1 and 3.1.3)
- Store submission; plan for review delays
- Soft launch

### Phase 12 — Public launch and growth (post-launch)
- Sales beyond the seed group, industry by industry
- **Monthly WhatsApp results summary**
- **Referral reward**
- Barbuda expansion, international promotion
- The section 14 backlog, in order

## 14. Post-launch backlog

### 14a. Adjacent markets

External advice suggests these follow naturally once business advertising works.
All are plausible; none are committed.

| Market | Why it fits | Watch out for |
| --- | --- | --- |
| Local events | Carnival, Sailing Week, Sunday at Shirley Heights. Gives businesses a reason to post around real dates. | Needs a calendar someone maintains. |
| Jobs and recruitment | Recruiters post repeatedly, so revenue is recurring. High competition from Facebook groups. | Moderation burden; scam postings. |
| Property rentals | Antigua has heavy turnover; listings expire fast. | Same. |
| Classifieds | Sell, services, things. Broadens beyond "businesses". | Dilutes the map. Needs its own tab or it buries the core. |

**Do not add these on day one.** Each needs its own moderation process, and
moderation is the scarce resource, not code.

### 14b. "What's happening today" feed

A single answer to "what's on in Antigua today", assembled from business offers,
events, and the curated collections in 14c. This is the strongest
retention idea in the external advice, because it is the only version that
gives a *user* a reason to open the app on a day when no business is advertising.

It depends on listings actually being current, which makes it a strong forcing
function for the whole "we maintain the accuracy" promise.

### 14c. Other backlog items

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

**Later**
- Saved places and trip lists for tourists
- Digital stamp card ("10th coffee free"), tied to the QR check-in
- Photos in reviews
- Pre-trip mode: international visitors browse and save before they arrive.
  Connects to the international promotion in section 1.

## 15. Open decisions

### Conflicts worth deciding on purpose

Three points where the external write-up disagrees with what we have already
chosen. None are accidents; each was decided at some point, and each deserves
a second look rather than a quiet drift.

**1. Who writes the listing?**

The advice is that businesses should post their own ads — upload a photo, pick
a category, publish. Our plan sits between the two: the team builds the first
version of a listing during the trial and maintains it for owners who will not use
the tools, and the business can edit directly (section 2, Content flow).

We keep the team's role because it is the product. The pitch is "we keep your
information up to date", and a self-serve editor hands that back to the
business and lets it rot. It also lets us fix things businesses will never fix
themselves. The cost is that we are a bottleneck for onboarding.

If onboarding becomes the constraint that stops growth, revisit — but do not
drift into it, because the accuracy promise is what is being sold. Phase 9 tests
which one owners actually want.

**2. Free first, charge later?**

The advice is to make listings free and introduce payment once businesses see
value. We charge from day one, with a 3-day trial.

Free-first maximises sign-ups and delays the only hard problem we have —
whether businesses will pay — which is exactly the thing we need to learn early.
Charging early gets that answer in week one. Keep charging.

**3. Build a website first to prove demand?**

The advice is to prove the idea with a simple site before investing in an app.

We are past that point and the app is largely built. The underlying question is
still live though: **have we asked twenty business owners anything?** Until we
have, we are building before knowing there is demand, not in response to it. That is a real
risk and it is cheap to retire. See section 16.

### Unresolved

- **The essentials layer is a real contradiction.** The current promise is that
  the app only shows paying businesses, which is part of why a listing is worth
  paying for. A free essentials layer gives locals a daily reason to open the
  app and improves retention, but it weakens the exclusivity claim. Pick a
  position on purpose: either it is a small, clearly-labelled "essential
  places" set, or it does not happen. Do not let it grow by accident until paid
  businesses ask why they pay for a listing next to free ones.
- **QR verification method.** Customer scans, or staff scan the customer's
  code. Decide before Phase 6 (section 8).
- Hand-drawn SVG map or real tiles? Google Maps is in; the hand-drawn option
  in the prototype cannot pan or zoom.
- Bundle the three prototype fonts, or accept system fallbacks?
- Revenue split: equal, but who covers refunds, bad debt, and the chasing?
- Who holds the Apple and Google credentials?
- Public web pages: which host, and does the domain go on them or on the app
  download page?
- **Subscription marking.** Payment is by direct transfer, so someone marks
  subscriptions active by hand. Automate from a bank feed or accept the manual
  step, and name who owns it. (This was on the list earlier and dropped off.)
- **Featured and the earned-rank promise.** "Priority in search" has been removed
  from Featured so that ranking alone governs search order. A looser version of the
  problem remains: Featured placement earns more views, views feed the engagement
  score, so paid visibility can lift rank indirectly. Decide whether engagement
  from the Featured page counts.
- **What "verified" means.** The badge is sold to Featured subscribers, but
  section 16 asks who verifies a business is real. Customers will read "verified"
  as endorsed. Rename it, or make it mean an identity check and give it to every
  tier.
- **Visibility during trial and hold.** Is a listing visible to customers during
  the 3-day trial and the 7-day hold? And do pre-built listings need the owner's
  consent before they go live?
- **What Growing shows its owners.** Growing has no analytics or reports, yet
  section 10 says businesses cancel when they cannot see results. Online-only
  businesses, its stated target, get no pin and are not ranked. Decide what an
  online-only business is paying for.

## 16. The thing we have not done

Every phase so far has been engineering. Not one has been a conversation with
a business owner.

The external advice puts this first, and it is right. The largest risks in this
plan are all commercial, and none of them are technical:

- Will a barber on Dickenson Bay pay EC$50 a month?
- Will anyone pay **EC$100** for Featured, when Growing is EC$25? Twice Basic
  is still a new kind of expense for a business that has never been charged
  for marketing.
- Do they trust us to keep their listing right, or do they expect to control it?
- What do they pay Facebook today, and what would they pay us instead?
- Who verifies a business is real, and who pays for that check?
- Does anyone actually want to post advertisements here, or do they still
  advertise on Facebook because that is where their customers are?
- Will enough customers open the app for an advertisement to be worth paying for?
  At launch there is no audience, and a first monthly report that says 6 views
  does not renew anyone.
- How many paying businesses make this worth four people's time? As an
  illustration only, EC$1,000 a month each is EC$4,000 a month, about 80 Basic
  subscriptions, before costs.

Phase 9 closes out those twenty conversations, and they should start now. Phase 10
plans to onboard five to ten
businesses, and pre-built listings are on the list so a pitch can open with
"this is already yours" — which presupposes Phase 9 happened first, and a
conversation worth having rather than a demonstration.

The pricing correction in section 2 removed the largest *arithmetic* risk. It
did not remove the commercial one: nobody has confirmed an owner will pay even
the corrected price. That still needs a human to ask.

**This is the highest-value next step, and it is not a code task.**

## 17. Principles

- Original design, minimal AI-generated look. Local credibility is the product.
- Listings must be accurate and current — that is the whole pitch.
- Keep the paid/earned distinction honest and visible.
- Do not claim the reviews are clean. They are verified visits filtered by the
  business, and the app says so.

## 18. Changes in this revision

**Contradictions fixed**
- Section 6 pointed to section 7 for verified visits; it is section 8.
- Section 6 said sign-in is Google only; Phase 2 has email sign-in as well.
- Section 5 still said the leaderboard grace period was undecided; Phase 8 had
  already decided it (30 days).
- Section 15, conflict 1, said the team implements every listing, while section 2
  says the business edits directly and the team is the fallback. It now describes
  the position in section 2.
- Phase 7 said the map pin is movable on Growing; section 3 says Growing has the
  default pin only. Phase 7 now matches section 3.
- Section 15, conflict 3, had a sentence that did not make sense; reworded.
- Section 14c was titled "Everything else from section 14" and repeated the
  Events calendar from Phase 7; retitled, and the duplicate bullet removed.
- "Notices" in Phase 2 and "Announcements" elsewhere are now noted as the same
  thing.

**Judgment calls, reverse if you disagree**
- Removed "Priority in search" from Featured, because section 5 says ranking alone
  governs search order. If you want it back, change section 5 to say so.
- Phase 9 now says to start the owner conversations now rather than at week 16.
- Added a scope check to Phase 7 and a unique-user rule to Phase 8.
- Added store-review and data-protection checks to Phase 11, worded as things to
  check, not as confirmed requirements.

**Added as open decisions**
- Subscription marking (dropped from the list earlier), the indirect Featured
  loop, what "verified" means, visibility during trial and hold, what Growing
  shows its owners, and two new commercial questions in section 16: audience and
  how many paying businesses are needed.
