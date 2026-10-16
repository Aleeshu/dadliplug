-- Phase 5: offers with redemption codes, and follow-alert opt-in.
--
-- An offer is an advertisement with a code. The customer says the code at the
-- till; the business records the redemption. Redemptions are the number that
-- proves the app brought someone in (plan.md section 11), so they feed the
-- monthly report alongside ad views.

-- ---------------------------------------------------------------------------
-- Offer codes
-- ---------------------------------------------------------------------------

alter table public.business_ads add column if not exists offer_code text;

-- Short, unambiguous, sayable at a noisy till: capitals and digits only.
alter table public.business_ads drop constraint if exists business_ads_offer_code_format;
alter table public.business_ads add constraint business_ads_offer_code_format
  check (offer_code is null or offer_code ~ '^[A-Z0-9]{4,10}$');

-- Offer codes are a Featured perk (plan.md section 3), including during the
-- trial so a business sees what it would buy. Enforced here, not only in the
-- app, so a Basic listing cannot add one with the publishable key.
create or replace function public.guard_offer_code()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.offer_code is null or public.is_team_admin() then
    return new;
  end if;
  if not exists (
    select 1 from public.businesses b
    where b.id = new.business_id
      and b.subscription_status in ('featured', 'trial')
  ) then
    raise exception 'Offer codes are part of the Featured plan'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists business_ads_guard_offer_code on public.business_ads;
create trigger business_ads_guard_offer_code
  before insert or update of offer_code on public.business_ads
  for each row execute function public.guard_offer_code();

-- ---------------------------------------------------------------------------
-- Redemptions
-- ---------------------------------------------------------------------------

alter table public.engagement_events drop constraint if exists engagement_events_kind_check;
alter table public.engagement_events add constraint engagement_events_kind_check
  check (kind in ('view', 'call', 'whatsapp', 'ad_view', 'redemption'));

alter table public.engagement_events drop constraint if exists engagement_ad_view_has_ad;
alter table public.engagement_events add constraint engagement_ad_view_has_ad
  check ((kind in ('ad_view', 'redemption')) = (ad_id is not null));

-- Recorded by the business, at the till. The opposite of record_engagement,
-- which excludes the owner's own taps: here only the owner (or the team) may
-- record, because only the business sees the code being said.
create or replace function public.record_redemption(p_ad_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_business uuid;
  v_code text;
begin
  select business_id, offer_code into v_business, v_code
  from public.business_ads where id = p_ad_id;

  if v_business is null then
    raise exception 'No such offer' using errcode = 'no_data_found';
  end if;
  if v_code is null then
    raise exception 'This advertisement has no offer code'
      using errcode = 'check_violation';
  end if;
  if not public.administers(v_business) then
    raise exception 'Only the business can record a redemption'
      using errcode = 'insufficient_privilege';
  end if;

  insert into public.engagement_events (business_id, ad_id, kind, user_id)
  values (v_business, p_ad_id, 'redemption', auth.uid());
end;
$$;

revoke all on function public.record_redemption(uuid) from public, anon;
grant execute on function public.record_redemption(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Follow alerts
-- ---------------------------------------------------------------------------

-- Opt-in, per business. Saving a business does not by itself sign anyone up
-- to be notified; the bell on the listing does. Push delivery comes later
-- (needs Firebase); until then this drives the in-app "Following" feed.
alter table public.business_follows
  add column if not exists notify boolean not null default false;

-- Followers may change their own row (the bell). The existing policies cover
-- insert/select/delete; update was never needed before.
drop policy if exists follows_update_own on public.business_follows;
create policy follows_update_own on public.business_follows for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
