-- Tier change (2026-10-22, Business Plan 2): the plans are now
--   Starter EC$25  (stored 'growing')  profile, 1 live advertisement
--   Growth  EC$50  (stored 'basic')    5 live advertisements, deals, tracking
--   Premium EC$100 (stored 'featured') unlimited ads, Featured page, Spotlight
-- The stored values are unchanged, so payments, billing and every guard keep
-- working; only the names people see changed (in the app).
--
-- A trial gets every paid tool. A listing on hold keeps what its plan
-- allows until the hold ends.

create or replace function public.plan_allows(p_business uuid, p_feature text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case p_feature
    when 'deals' then b.subscription_status = 'trial' or b.tier in ('basic', 'featured')
    else false
  end
  from public.businesses b
  where b.id = p_business and b.subscription_status <> 'delisted';
$$;

-- How many advertisements a listing may have running at once; null is no
-- limit.
create or replace function public.live_ad_limit(p_business uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select case
    when b.subscription_status = 'trial' then null
    when b.tier = 'featured' then null
    when b.tier = 'basic' then 5
    else 1
  end
  from public.businesses b
  where b.id = p_business;
$$;

-- Deals: Growth and Premium (were Premium only).
create or replace function public.guard_offer_code()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.offer_code is null or coalesce(public.is_team_admin(), false) then
    return new;
  end if;
  if not coalesce(public.plan_allows(new.business_id, 'deals'), false) then
    raise exception 'Deals are part of the Growth and Premium plans'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

-- Live-ad limit: counted over ads that have not ended, including ones
-- scheduled to start later, so a Starter cannot queue up ten.
create or replace function public.guard_live_ad_limit()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_limit integer;
  v_live integer;
begin
  if coalesce(public.is_team_admin(), false) then
    return new;
  end if;
  -- Ending an ad, or editing one that has ended, never hits the limit.
  if new.ends_at is not null and new.ends_at <= now() then
    return new;
  end if;
  if tg_op = 'UPDATE' and (old.ends_at is null or old.ends_at > now()) then
    return new;
  end if;

  v_limit := public.live_ad_limit(new.business_id);
  if v_limit is null then
    return new;
  end if;
  select count(*) into v_live
    from public.business_ads
   where business_id = new.business_id
     and id <> new.id
     and (ends_at is null or ends_at > now());
  if v_live >= v_limit then
    raise exception 'Your plan allows % running advertisement%. End one, or move up a plan.',
      v_limit, case when v_limit = 1 then '' else 's' end
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists business_ads_live_ad_limit on public.business_ads;
create trigger business_ads_live_ad_limit
  before insert or update of ends_at on public.business_ads
  for each row execute function public.guard_live_ad_limit();

grant execute on function public.live_ad_limit(uuid) to anon, authenticated;
grant execute on function public.plan_allows(uuid, text) to anon, authenticated;
