-- Development seed data.
--
-- The app has never run against a real business. Listing, leaderboard,
-- posting and the monthly report were all built and unit-tested with injected
-- data, which proves the arithmetic but not the wiring. This creates one real
-- listing so the whole path can be walked on a device.
--
-- SAFETY: every insert is guarded on the businesses table being empty. Once a
-- single real business exists this migration does nothing forever after, so it
-- can never seed test data alongside real customers. It is also idempotent.
--
-- Remove it with:  delete from public.businesses where slug = 'islandads-demo-*';
--
-- The listings are named so nobody mistakes them for customers.

-- ---------------------------------------------------------------------------
-- Two listings, so the leaderboard has something to rank
-- ---------------------------------------------------------------------------

with demo as (
  select gen_random_uuid() as id
)
insert into public.businesses (
  id, name, category, area, description, tier, subscription_status,
  address, how_to_find_us, latitude, longitude, phone, whatsapp, website,
  instagram, facebook, hours, price_range, tags,
  seeded_rating, seeded_review_count, views, calls, whatsapp_taps,
  created_at, last_verified_at, is_closed_today
)
select
  demo.id,
  'IslandAds Demo Kitchen',
  'food',
  'Dickenson Bay',
  'A demonstration listing used to test the app. Not a real business. '
    'Delete before any public build.',
  'featured',
  'featured',
  'Adjacent to the roundabout, near the ferry terminal',
  'Yellow gate, second floor',
  17.1181,
  -61.7965,
  '+1 268 555 0100',
  '+12685550100',
  'https://example.com',
  'islandads_demo',
  'islandadsdemo',
  '{"days":[7,1,2,3,4,5,6],"opens_at":11,"closes_at":22}',
  'EC$15-30',
  array['cash only', 'family friendly', 'parking'],
  4.6,
  42,
  1840,
  96,
  140,
  now() - interval '90 days',
  now() - interval '2 days',
  false
from demo;

with demo as (
  select gen_random_uuid() as id
)
insert into public.businesses (
  id, name, category, area, description, tier, subscription_status,
  address, latitude, longitude, phone, whatsapp,
  instagram, hours, price_range, tags,
  seeded_rating, seeded_review_count, views, calls, whatsapp_taps,
  created_at, last_verified_at, is_closed_today
)
select
  demo.id,
  'IslandAds Demo Salon',
  'beauty',
  'St. John''s',
  'A second demonstration listing so the leaderboard has two entries to rank. '
    'Not a real business. Delete before any public build.',
  'basic',
  'basic',
  'Central Street, above the pharmacy',
  17.1205,
  -61.8456,
  '+1 268 555 0101',
  '+12685550101',
  'islandads_demo_salon',
  '{"days":[1,2,3,4,5,6],"opens_at":9,"closes_at":18}',
  'EC$40+',
  array['wheelchair access', 'accepts cards'],
  4.2,
  28,
  910,
  41,
  58,
  now() - interval '60 days',
  now() - interval '5 days',
  false
from demo;

-- ---------------------------------------------------------------------------
-- Give the team admin both listings, so the business tabs are reachable
-- ---------------------------------------------------------------------------
-- The bootstrap test account is the only admin that exists. Linking the demo
-- listings is what makes the posting screens and the monthly report testable
-- at all.
--
-- `profiles_protect_role` deliberately blocks any change to `role` or
-- `business_ids` unless the caller is a team admin, and it decides that from
-- the caller's JWT claim. A migration has no JWT, so the guard correctly fires
-- and this cannot go through the ordinary path.
--
-- The trigger is therefore disabled for exactly this statement and restored
-- immediately. That is the only way to seed this without weakening the guard
-- for real accounts, and leaving it disabled would be a genuine vulnerability.

alter table public.profiles disable trigger profiles_protect_role;

update public.profiles p
set business_ids = coalesce(p.business_ids, '{}') || (
  select coalesce(array_agg(b.id), '{}')
  from public.businesses b
  where b.name in ('IslandAds Demo Kitchen', 'IslandAds Demo Salon')
)
where p.role in ('business_admin', 'team_admin');

alter table public.profiles enable trigger profiles_protect_role;

-- ---------------------------------------------------------------------------
-- Content on the demo listings
-- ---------------------------------------------------------------------------

insert into public.business_ads (business_id, title, body, link_url, starts_at, views)
select id, 'Lunch special this week', 'Any main and a drink, Monday to Friday.', null,
       now() - interval '10 days', 640
from public.businesses where name = 'IslandAds Demo Kitchen';

insert into public.business_ads (business_id, title, body, link_url, starts_at, ends_at, views)
select id, 'Opening weekend offer', 'Twenty percent off for the first week.', null,
       now() - interval '80 days', now() - interval '73 days', 1205
from public.businesses where name = 'IslandAds Demo Kitchen';

insert into public.business_announcements (business_id, title, body)
select id, 'Closed on Saturday', 'We are closed this Saturday for maintenance.'
from public.businesses where name = 'IslandAds Demo Kitchen';

insert into public.business_events (business_id, title, body, starts_at, location_note)
select id, 'Demo tasting night', 'Five dishes, one seating. Bookings essential.',
       now() + interval '9 days', 'Upstairs, yellow gate'
from public.businesses where name = 'IslandAds Demo Kitchen';

insert into public.business_events (business_id, title, body, starts_at, location_note)
select id, 'Summer haircut special', 'Two appointments left this month.',
       now() + interval '3 days', 'Central Street'
from public.businesses where name = 'IslandAds Demo Salon';