-- Phase 4 close-out: engagement that actually counts, listing fields owners
-- cannot self-upgrade, and four bugs found reading the earlier migrations.

-- ---------------------------------------------------------------------------
-- 1. Engagement events
-- ---------------------------------------------------------------------------
-- The month-end report claimed to be monthly while reading the lifetime
-- counters on `businesses`, so "views this month" was really "views ever". And
-- nothing incremented those counters at all: the only write path was a policy
-- whose WITH CHECK required the caller to administer the listing, which is
-- exactly the person whose taps must not count.
--
-- Each view, call, WhatsApp tap and ad view is now an event row with a
-- timestamp, so a month is a range query. The counters on `businesses` are
-- still incremented alongside, because ranking reads them and should not have
-- to aggregate the event table on every map load.

create table if not exists public.engagement_events (
  id          bigint generated always as identity primary key,
  business_id uuid not null references public.businesses (id) on delete cascade,
  ad_id       uuid references public.business_ads (id) on delete cascade,
  kind        text not null check (kind in ('view', 'call', 'whatsapp', 'ad_view')),
  user_id     uuid references auth.users (id) on delete set null,
  occurred_at timestamptz not null default now(),

  constraint engagement_ad_view_has_ad check ((kind = 'ad_view') = (ad_id is not null))
);

create index if not exists engagement_events_business_idx
  on public.engagement_events (business_id, occurred_at);

create index if not exists engagement_events_ad_idx
  on public.engagement_events (ad_id, occurred_at)
  where ad_id is not null;

alter table public.engagement_events enable row level security;

-- Owners and the team read their own numbers. Nobody inserts directly: the
-- only write path is record_engagement() below, which applies the rules.
drop policy if exists engagement_select_admin on public.engagement_events;
create policy engagement_select_admin on public.engagement_events for select
  using (public.administers(business_id));

revoke insert, update, delete on public.engagement_events from anon, authenticated;

create or replace function public.record_engagement(
  p_business_id uuid,
  p_kind text,
  p_ad_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if p_kind not in ('view', 'call', 'whatsapp', 'ad_view') then
    return false;
  end if;

  -- An owner tapping their own number, or the team checking a listing, is not
  -- a customer. Counting them would let a business climb the rank by
  -- refreshing its own page (plan.md Phase 8, unique-user rule).
  if v_uid is not null and public.administers(p_business_id) then
    return false;
  end if;

  if p_kind = 'ad_view' and not exists (
    select 1 from public.business_ads
    where id = p_ad_id and business_id = p_business_id
  ) then
    return false;
  end if;

  -- A signed-in customer counts once per kind per listing per hour. Guests
  -- cannot be deduplicated without tracking them, which the plan rules out.
  if v_uid is not null and exists (
    select 1 from public.engagement_events
    where user_id = v_uid
      and business_id = p_business_id
      and kind = p_kind
      and ad_id is not distinct from p_ad_id
      and occurred_at > now() - interval '1 hour'
  ) then
    return false;
  end if;

  insert into public.engagement_events (business_id, ad_id, kind, user_id)
  values (p_business_id, p_ad_id, p_kind, v_uid);

  -- Lets the listing guard below tell this function's counter write apart
  -- from a client trying to set its own numbers. Transaction-local.
  perform set_config('islandads.counter_write', 'on', true);

  if p_kind = 'view' then
    update public.businesses set views = views + 1 where id = p_business_id;
  elsif p_kind = 'call' then
    update public.businesses set calls = calls + 1 where id = p_business_id;
  elsif p_kind = 'whatsapp' then
    update public.businesses set whatsapp_taps = whatsapp_taps + 1 where id = p_business_id;
  else
    update public.business_ads set views = views + 1 where id = p_ad_id;
  end if;

  perform set_config('islandads.counter_write', 'off', true);
  return true;
end;
$$;

grant execute on function public.record_engagement(uuid, text, uuid) to anon, authenticated;

-- The old counters policy let any signed-in user attempt an update and then
-- required them to administer the row, so it granted nothing a customer could
-- use and read as if it did.
drop policy if exists "businesses_counters" on public.businesses;

-- ---------------------------------------------------------------------------
-- 2. Fields an owner must not set
-- ---------------------------------------------------------------------------
-- `businesses_update_admin` lets an owner update their own row, and a row
-- policy cannot restrict columns. So an owner could set subscription_status to
-- 'featured' with the publishable key, or write their own view count and
-- seeded rating. Same trap as profiles.role; same fix, a trigger.

create or replace function public.protect_business_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(public.is_team_admin(), false) then
    return new;
  end if;

  if coalesce(current_setting('islandads.counter_write', true), 'off') = 'on' then
    return new;
  end if;

  if new.tier is distinct from old.tier
     or new.subscription_status is distinct from old.subscription_status
     or new.seeded_rating is distinct from old.seeded_rating
     or new.seeded_review_count is distinct from old.seeded_review_count
     or new.views is distinct from old.views
     or new.calls is distinct from old.calls
     or new.whatsapp_taps is distinct from old.whatsapp_taps
     or new.last_spotlight_week is distinct from old.last_spotlight_week
     or new.created_at is distinct from old.created_at
  then
    raise exception 'Only the team can change subscription, rating or counter fields'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists businesses_protect_fields on public.businesses;
create trigger businesses_protect_fields
  before update on public.businesses
  for each row execute function public.protect_business_fields();

-- Ad views are a counter too; an owner may edit and end their ads, not
-- inflate them.
create or replace function public.protect_ad_views()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.views is distinct from old.views
     and not coalesce(public.is_team_admin(), false)
     and coalesce(current_setting('islandads.counter_write', true), 'off') <> 'on'
  then
    raise exception 'Advertisement views are counted, not set'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists business_ads_protect_views on public.business_ads;
create trigger business_ads_protect_views
  before update on public.business_ads
  for each row execute function public.protect_ad_views();

-- ---------------------------------------------------------------------------
-- 3. Content visibility follows subscription_status
-- ---------------------------------------------------------------------------
-- The listing itself is hidden on `subscription_status`, but ads,
-- announcements and events were gated on `tier`. A business delisted for
-- non-payment with a stale tier kept its adverts publicly readable.

create or replace function public.can_read_business_content(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.administers(p_business_id)
      or exists (
        select 1 from public.businesses b
        where b.id = p_business_id and b.subscription_status <> 'delisted'
      );
$$;

-- ---------------------------------------------------------------------------
-- 4. The gated auto-confirm trigger never fired usefully
-- ---------------------------------------------------------------------------
-- 20261012150000 created it AFTER INSERT. Assigning to NEW in an after trigger
-- is discarded, so turning dev_flags.auto_confirm_email on did nothing. Moved
-- to BEFORE INSERT. The flag still defaults to off, so production behaviour is
-- unchanged; this only makes the documented dev switch work.

drop trigger if exists auto_confirm_on_signup on auth.users;
create trigger auto_confirm_on_signup
  before insert on auth.users
  for each row execute function public.auto_confirm_new_user();

-- The ungated function from 20261011230100 is no longer referenced.
drop function if exists public.auto_confirm_email();

-- ---------------------------------------------------------------------------
-- 5. Demo seed rows written in the wrong vocabulary
-- ---------------------------------------------------------------------------
-- The seed wrote hours as opens_at/closes_at; the app reads opensAt/closesAt,
-- so both demos fell back to 9am-5pm. Tags were written as prose
-- ('cash only') rather than the keys the app knows ('cash_only'), so they
-- rendered as raw text. Only the two named demo rows are touched.

update public.businesses
set hours = jsonb_build_object(
      'days', hours -> 'days',
      'opensAt', coalesce(hours -> 'opensAt', hours -> 'opens_at'),
      'closesAt', coalesce(hours -> 'closesAt', hours -> 'closes_at')
    )
where name in ('IslandAds Demo Kitchen', 'IslandAds Demo Salon')
  and hours ? 'opens_at';

update public.businesses
set tags = array['cash_only', 'family_friendly', 'parking']
where name = 'IslandAds Demo Kitchen';

update public.businesses
set tags = array['accessibility', 'accepts_cards']
where name = 'IslandAds Demo Salon';

notify pgrst, 'reload schema';
