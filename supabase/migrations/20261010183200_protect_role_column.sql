-- Guard the columns RLS cannot protect.
--
-- Why this exists: a row-level UPDATE policy can restrict WHICH ROW a user
-- touches, but not WHICH COLUMN. `with check (id = auth.uid())` passes whether
-- they change their display name or promote themselves to team_admin.
--
-- The obvious fix — `grant update (display_name)` — does not work, because
-- Supabase grants table-wide UPDATE on public.* to `authenticated` by default.
-- A column grant adds to that, it does not subtract from it.
--
-- So the role change is blocked here instead, at the row itself.

create or replace function public.protect_profile_role()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  -- Only a team admin may change roles or reassign businesses.
  if (new.role is distinct from old.role
      or new.business_ids is distinct from old.business_ids)
    and not public.is_team_admin()
  then
    raise exception 'Only a team admin can change role or assigned businesses'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

create trigger profiles_protect_role
  before update on public.profiles
  for each row execute function public.protect_profile_role();

-- Reviews move through states, and only the team sets 'removed'. Letting a
-- business set it would let them bury a bad review by editing their own row.
create or replace function public.protect_review_status()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.status is distinct from old.status
    and not public.is_team_admin()
    and new.status <> 'verified'
  then
    raise exception 'Only a team admin can change review status'
      using errcode = '42501';
  end if;

  -- A reviewer cannot rewrite a verified rating after the fact.
  if new.rating is distinct from old.rating and old.status = 'verified' then
    raise exception 'A verified rating cannot be changed'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

create trigger reviews_protect_status
  before update on public.reviews
  for each row execute function public.protect_review_status();

-- Drop the grants that were meant to restrict columns but do not. They imply a
-- protection that is not there, which is worse than not having them.
revoke update on public.profiles from authenticated;
grant update (display_name) on public.profiles to authenticated;

-- Admin counters and subscription status move without going through the app,
-- because payment is a bank transfer someone records by hand. The client never
-- writes these directly, so they are revoked outright.
revoke update on public.subscriptions from authenticated;