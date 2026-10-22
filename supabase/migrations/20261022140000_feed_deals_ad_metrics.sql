-- Business Plan 2 (2026-10-22): proof that a subscription works, deals that
-- bring people in, and ads that spread on WhatsApp.
--
-- 1. More of what an owner needs to see: an ad being opened (not only shown),
--    shared, and someone asking for directions.
-- 2. Dadliplug Deals: a resident claims an offer and gets their own code; the
--    business redeems that code at the till. One code per person per deal,
--    each redeemable once, so a redemption count means real visits. Offers
--    also carry the business's terms.

-- ---------------------------------------------------------------------------
-- 1. New engagement kinds
-- ---------------------------------------------------------------------------

alter table public.engagement_events drop constraint if exists engagement_events_kind_check;
alter table public.engagement_events add constraint engagement_events_kind_check
  check (kind in ('view', 'call', 'whatsapp', 'ad_view', 'redemption',
                  'ad_open', 'ad_share', 'directions'));

alter table public.engagement_events drop constraint if exists engagement_ad_view_has_ad;
alter table public.engagement_events add constraint engagement_ad_view_has_ad
  check ((kind in ('ad_view', 'redemption', 'ad_open', 'ad_share')) = (ad_id is not null));

-- Same rules as before (owner and team taps do not count; a signed-in
-- customer counts once per kind per hour), with the new kinds accepted.
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
  v_needs_ad boolean := p_kind in ('ad_view', 'ad_open', 'ad_share');
begin
  if p_kind not in ('view', 'call', 'whatsapp', 'ad_view', 'ad_open', 'ad_share', 'directions') then
    return false;
  end if;

  if v_uid is not null and coalesce(public.administers(p_business_id), false) then
    return false;
  end if;

  if v_needs_ad and not exists (
    select 1 from public.business_ads
    where id = p_ad_id and business_id = p_business_id
  ) then
    return false;
  end if;
  if not v_needs_ad then
    p_ad_id := null;
  end if;

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

  perform set_config('islandads.counter_write', 'on', true);
  if p_kind = 'view' then
    update public.businesses set views = views + 1 where id = p_business_id;
  elsif p_kind = 'call' then
    update public.businesses set calls = calls + 1 where id = p_business_id;
  elsif p_kind = 'whatsapp' then
    update public.businesses set whatsapp_taps = whatsapp_taps + 1 where id = p_business_id;
  elsif p_kind = 'ad_view' then
    update public.business_ads set views = views + 1 where id = p_ad_id;
  end if;
  perform set_config('islandads.counter_write', 'off', true);
  return true;
end;
$$;

grant execute on function public.record_engagement(uuid, text, uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Deals
-- ---------------------------------------------------------------------------

alter table public.business_ads
  add column if not exists offer_terms text
    check (offer_terms is null or length(offer_terms) <= 200);

create table if not exists public.deal_claims (
  id          uuid primary key default gen_random_uuid(),
  ad_id       uuid not null references public.business_ads (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  -- Read aloud at the till: no 0/O or 1/I to confuse.
  code        text not null unique check (code ~ '^[A-HJ-NP-Z2-9]{6}$'),
  claimed_at  timestamptz not null default now(),
  redeemed_at timestamptz,
  redeemed_by uuid references auth.users (id) on delete set null,
  unique (ad_id, user_id)
);

alter table public.deal_claims enable row level security;

-- A resident sees their own claims; the business sees claims on its offers.
drop policy if exists deal_claims_read on public.deal_claims;
create policy deal_claims_read on public.deal_claims for select
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.business_ads a
       where a.id = ad_id and coalesce(public.administers(a.business_id), false)
    )
  );
revoke insert, update, delete on public.deal_claims from anon, authenticated;

-- Claim an offer: returns the resident's code, the same one on every call.
create or replace function public.claim_deal(p_ad uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_ad public.business_ads;
  v_code text;
  v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if v_uid is null then
    raise exception 'Sign in to claim a deal' using errcode = '42501';
  end if;

  select * into v_ad from public.business_ads where id = p_ad;
  if not found or v_ad.offer_code is null then
    raise exception 'This is not a deal' using errcode = 'P0002';
  end if;
  if v_ad.starts_at > now() or (v_ad.ends_at is not null and v_ad.ends_at <= now()) then
    raise exception 'This deal has ended' using errcode = '22023';
  end if;
  if coalesce(public.administers(v_ad.business_id), false) then
    raise exception 'You cannot claim your own deal' using errcode = '42501';
  end if;

  select code into v_code from public.deal_claims where ad_id = p_ad and user_id = v_uid;
  if v_code is not null then
    return v_code;
  end if;

  loop
    v_code := '';
    for i in 1..6 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;
    begin
      insert into public.deal_claims (ad_id, user_id, code) values (p_ad, v_uid, v_code);
      return v_code;
    exception when unique_violation then
      -- Another resident has this code, or this resident claimed in a race.
      select code into v_code from public.deal_claims where ad_id = p_ad and user_id = v_uid;
      if v_code is not null then
        return v_code;
      end if;
    end;
  end loop;
end;
$$;

-- The business redeems a code at the till. Returns the deal's title so the
-- screen can say what was redeemed.
create or replace function public.redeem_deal(p_code text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_claim public.deal_claims;
  v_ad public.business_ads;
begin
  select * into v_claim from public.deal_claims
   where code = upper(btrim(p_code)) for update;
  if not found then
    raise exception 'No deal has that code' using errcode = 'P0002';
  end if;

  select * into v_ad from public.business_ads where id = v_claim.ad_id;
  if not coalesce(public.administers(v_ad.business_id), false) then
    -- Same message as an unknown code: a business cannot probe other
    -- businesses' codes.
    raise exception 'No deal has that code' using errcode = 'P0002';
  end if;
  if v_claim.redeemed_at is not null then
    raise exception 'Already redeemed on %', to_char(v_claim.redeemed_at at time zone 'America/Antigua', 'Mon DD at HH12:MI AM')
      using errcode = '23505';
  end if;

  update public.deal_claims
     set redeemed_at = now(), redeemed_by = auth.uid()
   where id = v_claim.id;
  insert into public.engagement_events (business_id, ad_id, kind, user_id)
  values (v_ad.business_id, v_ad.id, 'redemption', v_claim.user_id);
  return v_ad.title;
end;
$$;

revoke all on function public.claim_deal(uuid) from public;
revoke all on function public.redeem_deal(text) from public;
grant execute on function public.claim_deal(uuid) to anon, authenticated;
grant execute on function public.redeem_deal(text) to anon, authenticated;

-- Terms on the demo offers, so the feature shows.
update public.business_ads set offer_terms = 'Monday to Thursday, 4 to 7pm. One per person.'
 where offer_code = 'SUNSET15';
update public.business_ads set offer_terms = 'Under-12s with a paying adult. Book on WhatsApp.'
 where offer_code = 'KIDSFREE';
