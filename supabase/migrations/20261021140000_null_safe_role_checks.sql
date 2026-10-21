-- SECURITY: role checks returned NULL for anonymous callers.
--
-- current_role() is a lookup on profiles by auth.uid(). For a caller with no
-- session it finds nothing and returns NULL, so is_team_admin() returned
-- NULL = 'team_admin' = NULL, and administers() returned NULL OR false = NULL.
--
-- In plpgsql, `if not public.is_team_admin() then raise ...` with NULL is
-- `if NULL`, which is false: the guard did not fire. So with only the
-- publishable key, anyone could call start_trial and record_payment (found
-- by probing them, 2026-10-21: start_trial succeeded), read a business's till
-- visit code through current_visit_code, approve or decline review requests
-- through respond_to_review_request, record offer redemptions, and read the
-- team's review audit.
--
-- Row Level Security and the update triggers were not affected: a NULL there
-- fails closed. Fixed at the root so every caller of these helpers is safe,
-- including any written later: they now return strictly true or false.

create or replace function public.is_team_admin()
returns boolean
language sql stable
as $$
  select coalesce(public.current_role() = 'team_admin', false)
$$;

create or replace function public.is_business_admin()
returns boolean
language sql stable
as $$
  select coalesce(public.current_role() = 'business_admin', false)
$$;

create or replace function public.administers(target uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select
    public.is_team_admin()
    or exists (
      select 1 from public.profiles
      where id = auth.uid() and target = any (business_ids)
    )
$$;

-- The daily billing step is for the scheduler (no request, no JWT) and the
-- team. It previously let any caller without a user id through, which
-- included anonymous API calls.
create or replace function public.advance_subscriptions()
returns table (held integer, delisted integer)
language plpgsql security definer set search_path = public
as $$
declare
  v_held integer;
  v_delisted integer;
begin
  if auth.jwt() is not null and not public.is_team_admin() then
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

-- Undo the probe that exposed this: an anonymous start_trial switched the
-- demo kitchen to a trial. Back to Featured with no billing dates, as it was.
-- A migration runs with no user, so it uses the trusted-write flag.
select set_config('islandads.billing_write', 'on', true);

update public.businesses
set subscription_status = 'featured',
    tier = 'featured',
    trial_ends_at = null,
    hold_until = null
where name = 'IslandAds Demo Kitchen'
  and subscription_status = 'trial';
