# Business model logic

The rules that decide who appears, in what order, and for how long. Ported from
the prototype's JS so behaviour does not drift between the prototype and the
app.

## Ranking

`services/ranking_service.dart`. The product promise is that rank is earned, not
bought, so this is the most sensitive code in the project.

```
rating   45%   Bayesian average, prior mean 3.8, weight 5
volume   25%   log(review count + 1) / log(61)
engaged  30%   log(views + 5*(calls + taps) + 1) / log(3001)
total           100 * (0.45*rating + 0.25*volume + 0.30*engaged)
```

Why each part:

- **Bayesian rating** stops one 5-star review outranking forty 4.8s. The prior
  mean is 3.8 rather than a neutral 3.0 because most businesses start with no
  reviews here, and a neutral prior would punish every new listing.
- **Logarithmic volume** saturates around 61 reviews. Linear volume would make
  review count dominate the other two terms entirely.
- **Engagement weighted 5x toward intent.** A view is weak; a tap or a call is
  someone deciding to go. Logarithmic so it cannot run away from rating.

Ties break on review count, so a tie does not reshuffle between refreshes.

Payment affects visibility, never score. There is a test asserting this.

## Engagement

Views, calls, WhatsApp taps and ad views are recorded through the
`record_engagement` database function, never written by the client directly.
It refuses taps from the listing's own admins and the team, and counts a
signed-in customer once per kind per listing per hour. Guests cannot be
deduplicated without tracking them, which the privacy rule below rules out.

Each event is stored with a timestamp in `engagement_events`, which is what
makes the monthly report monthly. The counters on `businesses` are kept in
step for ranking.

## Featured vs Spotlight

Two separate things, easy to confuse:

- **Featured** — Featured subscribers only, capacity unlimited. Featured buys
  the slot; ranking decides the order inside it.
- **Spotlight** — 10 rotating slots, open to any visible listing. Serves the
  least-recently-featured first, so businesses take turns.

Spotlight rotation exists because a new premium subscriber has a score of zero
and would sit last in a strict ranking. Rotation lets them be seen while the
featured board still reflects earned popularity.

## Subscription states

Prices are EC$ per month (`plan.md` section 2).

| State | Visible | Featured slot | Price |
| --- | --- | --- | --- |
| `growing` | yes | no | EC$25 |
| `basic` | yes | no | EC$50 |
| `featured` | yes | yes | EC$100 |
| `trial` | yes, 3 days | yes | — |
| `overdue` | yes, 7-day hold | no | — |
| `delisted` | no | no | — |

`subscription_status` is authoritative and only the team can change it. A
database trigger (`20261014120000`) refuses changes to status, tier, counters
and seeded ratings from anyone else, because a row-level policy cannot stop an
owner editing those columns on their own row.

Trial holds a Featured slot deliberately: a business needs to see what it is
paying for during the three days it is deciding.

`overdue` exists so a lapse is a warning before it is a delisting. Payment is
by transfer, so nothing reminds a business automatically — the team sets this
state. That means someone has to notice. Build a reminder, not just a toggle.

## Reviews

Only verified visits produce reviews. The mechanism is a QR code at the till —
the customer scans while physically present, and the code rotates so one person
cannot generate fake visits.

**The gate is not a trust guarantee.** A business still approves which
customers may review, which means it can approve the happy ones and decline the
rest. This is structural, not a bug: any scheme where the reviewed party gates
the review will be gamed. The app says so rather than implying the ratings are
clean.

Mitigations, in order of how much they help:
1. A reason is required when declining
2. The team sees "approved 9 of 10" per business
3. Declines sit in the moderation queue for audit
4. Verified visits do the real work; the queue is the fallback for businesses
   that cannot display a QR code

Removed and locked reviews never enter the rating. Seeded pre-launch ratings
are blended in so a business is not shown as "0 reviews" on day one.

## Data accuracy

The pitch is that the team maintains the listings, so accuracy features are the
product, not polish.

- "Closed today" one-tap state. Hurricane season, holidays, Carnival.
- Last-verified date and a "report wrong info" button on every listing.
- Businesses not updated in 60 days get chased by the team.
- Updates arrive by WhatsApp, because owners will not open an admin screen.

## Retention

Businesses cancel when they cannot see results. A monthly WhatsApp summary
("214 views, 18 calls") does more than a dashboard nobody opens. Review
requests push-notify the business, or the verification queue sits unseen and the
ranking loop dies.

## Privacy

Location is used only while the user is actively browsing and is never stored.
That is what keeps the "not a tracking app" promise honest for "offers near me".

## Opening hours

Always evaluated in **Antigua time (UTC-4, no DST)**, not device time. A phone
set to another country showing a business as closed would be a very visible
failure for an app whose job is "is this open right now".

Model is one open/close time plus a set of weekdays — most Antigua businesses
do not vary hours by day. Grows to per-day hours if a business needs it.

## Search

Matches on name, category, area, description, and menu items. Menu text matters:
somebody searching "seafood" should find the restaurant that lists it.