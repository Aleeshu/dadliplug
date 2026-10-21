-- Phase 7 billing: trial -> paid -> overdue (held) -> delisted.
--
-- plan.md section 3: a 3-day trial on every tier with every paid tool; on
-- expiry the listing is held for 7 days and the owner can pay at any point and
-- pick up where they left off. The same applies to a paid month that lapses.
-- Payment is a bank transfer the team records by hand (section 15,
-- "subscription marking"), so every payment is logged with who marked it.
--
-- Decisions taken here (plan.md section 15 left them open):
--   * Held listings stay visible, marked overdue: the existing app rule
--     ("we warn before we delist") and the promise that the owner can pick up
--     where they left off both point that way.
--   * After the hold a listing is delisted (hidden), not deleted. Deleting a
--     business's data is a deliberate team act, not something a timer does.
--   * `tier` keeps the plan the business is on; `subscription_status` is the
--     state. A held Featured business is status 'overdue', tier 'featured',
--     so paying restores exactly what it had.

alter table public.businesses
  add column if not exists trial_ends_at timestamptz,
  add column if not exists paid_until   timestamptz,
  add column if not exists hold_until   timestamptz;

-- The billing dates are as protected as the status itself: an owner moving
-- their own paid_until forward would be a free month.
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

  if coalesce(current_setting('islandads.counter_write', true), 'off') = 'on'
     or coalesce(current_setting('islandads.billing_write', true), 'off') = 'on' then
    return new;
  end if;

  if new.tier is distinct from old.tier
     or new.subscription_status is distinct from old.subscription_status
     or new.trial_ends_at is distinct from old.trial_ends_at
     or new.paid_until is distinct from old.paid_until
     or new.hold_until is distinct from old.hold_until
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

-- ---------------------------------------------------------------------------
-- Payments ledger
-- ---------------------------------------------------------------------------

create table if not exists public.payments (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  tier        text not null check (tier in ('growing', 'basic', 'featured')),
  months      integer not null check (months between 1 and 24),
  amount_ec   numeric(10, 2) not null check (amount_ec >= 0),
  reference   text not null check (length(btrim(reference)) > 0),
  paid_until  timestamptz not null,
  recorded_by uuid not null references auth.users (id),
  recorded_at timestamptz not null default now()
);

create index if not exists payments_business_idx
  on public.payments (business_id, recorded_at desc);

alter table public.payments enable row level security;

-- The team sees all; an owner sees their own receipts.
drop policy if exists payments_read on public.payments;
create policy payments_read on public.payments for select
  using (public.administers(business_id));

-- Writes only through record_payment().
revoke insert, update, delete on public.payments from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Team actions
-- ---------------------------------------------------------------------------

create or replace function public.record_payment(
  p_business uuid,
  p_tier text,
  p_months integer,
  p_amount_ec numeric,
  p_reference text
)
returns timestamptz
language plpgsql security definer set search_path = public
as $$
declare
  v_from timestamptz;
  v_until timestamptz;
begin
  if not public.is_team_admin() then
    raise exception 'Only the team records payments' using errcode = '42501';
  end if;

  -- A payment made while still paid-up extends from the current end date,
  -- so paying early never loses days. Otherwise it runs from today.
  select greatest(coalesce(paid_until, now()), now()) into v_from
  from public.businesses where id = p_business;
  if v_from is null then
    raise exception 'No such business' using errcode = 'no_data_found';
  end if;
  v_until := v_from + make_interval(months => p_months);

  insert into public.payments
    (business_id, tier, months, amount_ec, reference, paid_until, recorded_by)
  values
    (p_business, p_tier, p_months, p_amount_ec, btrim(p_reference), v_until, auth.uid());

  perform set_config('islandads.billing_write', 'on', true);
  update public.businesses
  set tier = p_tier,
      subscription_status = p_tier,
      paid_until = v_until,
      trial_ends_at = null,
      hold_until = null
  where id = p_business;

  return v_until;
end;
$$;
grant execute on function public.record_payment(uuid, text, integer, numeric, text) to authenticated;

-- Start the 3-day trial on a plan: every tool of that plan, then the hold.
create or replace function public.start_trial(p_business uuid, p_tier text default 'featured')
returns timestamptz
language plpgsql security definer set search_path = public
as $$
declare
  v_end timestamptz := now() + interval '3 days';
begin
  if not public.is_team_admin() then
    raise exception 'Only the team starts trials' using errcode = '42501';
  end if;
  if p_tier not in ('growing', 'basic', 'featured') then
    raise exception 'Unknown plan' using errcode = 'check_violation';
  end if;

  perform set_config('islandads.billing_write', 'on', true);
  update public.businesses
  set tier = p_tier,
      subscription_status = 'trial',
      trial_ends_at = v_end,
      hold_until = null
  where id = p_business;
  return v_end;
end;
$$;
grant execute on function public.start_trial(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- The daily step
-- ---------------------------------------------------------------------------

-- Trial or paid period over -> overdue, held for 7 days.
-- Hold over -> delisted. Listings with no dates (set up before billing
-- existed) are left alone rather than suddenly expired.
create or replace function public.advance_subscriptions()
returns table (held integer, delisted integer)
language plpgsql security definer set search_path = public
as $$
declare
  v_held integer;
  v_delisted integer;
begin
  -- The scheduler runs with no user; anyone else must be the team.
  if auth.uid() is not null and not public.is_team_admin() then
    raise exception 'Team only' using errcode = '42501';
  end if;

  perform set_config('islandads.billing_write', 'on', true);

  update public.businesses
  set subscription_status = 'overdue',
      hold_until = now() + interval '7 days'
  where (subscription_status = 'trial' and trial_ends_at < now())
     or (subscription_status in ('growing', 'basic', 'featured')
         and paid_until is not null and paid_until < now());
  get diagnostics v_held = row_count;

  update public.businesses
  set subscription_status = 'delisted'
  where subscription_status = 'overdue'
    and hold_until is not null and hold_until < now();
  get diagnostics v_delisted = row_count;

  return query select v_held, v_delisted;
end;
$$;
grant execute on function public.advance_subscriptions() to authenticated;

-- Every day at 00:05 Antigua time (04:05 UTC).
create extension if not exists pg_cron;
select cron.unschedule(jobid) from cron.job where jobname = 'advance-subscriptions';
select cron.schedule(
  'advance-subscriptions',
  '5 4 * * *',
  $$select public.advance_subscriptions()$$
);
