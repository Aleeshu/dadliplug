-- subscription_status accepted anything, and anything wrong was invisible.
--
-- `subscription_status` is `text not null default 'delisted'` with no CHECK
-- constraint, and the app parses it with `SubscriptionTier.fromName`, which
-- falls back to `delisted` for anything it does not recognise.
--
-- Those two facts combine badly: writing 'Active' instead of 'active', or
-- 'subscribed', or any other reasonable-looking word, silently delists a
-- paying business. The listing disappears from the app, no query errors, and
-- nothing is logged. The business's owner sees it gone and has no idea why.
--
-- Found while seeding the demo listings, which set it to 'active' and then
-- rendered as "No businesses listed yet".
--
-- Constraining it to the tier vocabulary means a bad value is rejected at the
-- point of writing it, by whoever is writing it, rather than discovered later
-- by a customer who cannot find the shop.

-- ---------------------------------------------------------------------------
-- Repair first
-- ---------------------------------------------------------------------------
-- Has to happen before the constraint is added, or adding it fails on the very
-- rows this migration exists to clean up.

-- Anything outside the tier vocabulary has always resolved to `delisted` in the
-- app, so recording it as `delisted` changes nothing a customer can see. It
-- only makes the stored value honest.
update public.businesses
set subscription_status = 'delisted'
where subscription_status not in (
  'growing', 'basic', 'featured', 'trial', 'overdue', 'delisted'
);

-- The demo seed landed before this constraint and set 'active', so those two
-- rows were just demoted above. Put them back to the tier they are actually on.
update public.businesses b
set subscription_status = b.tier
where b.name in ('IslandAds Demo Kitchen', 'IslandAds Demo Salon');

-- ---------------------------------------------------------------------------
-- Then constrain
-- ---------------------------------------------------------------------------

alter table public.businesses
  add constraint businesses_subscription_status_check
  check (subscription_status in (
    'growing', 'basic', 'featured', 'trial', 'overdue', 'delisted'
  ));

comment on column public.businesses.subscription_status is
  'Authoritative subscription state, same vocabulary as tier. Constrained to '
  'that vocabulary because the app resolves an unrecognised value to '
  'delisted, which would hide a paying business with no error anywhere.';