-- Team admin bootstrap, and a NULL-safety fix to the role guard.
--
-- Two problems this resolves.
--
-- 1. Team admin lockout. `profiles_protect_role` (20261010183200) blocks any
--    role change by a non-admin, which is the point — but the `profiles` table
--    has no team_admin rows, so nobody can ever become one. A chicken-and-egg.
--
--    An earlier attempt at this claimed a SECURITY DEFINER function would
--    sidestep the trigger. It does not, and this was verified against the live
--    database: SECURITY DEFINER changes the *effective role*, not `auth.uid()`,
--    which still reads the caller's JWT claim. The trigger therefore saw
--    `is_team_admin() = false` and raised, exactly as it should. The RPC failed
--    on first call with "Only a team admin can change role".
--
--    The fix is a deliberate, documented one-shot window rather than a
--    privilege trick: while the island has no team admin at all, the first
--    signed-in user to change their own role becomes one. Once a team admin
--    exists the window closes permanently and the original guard is absolute
--    again. This is the same shape as the first-run setup of any admin tool,
--    and it is honest about being a bootstrap.
--
-- 2. NULL-safety in the guard. `current_role()` returns NULL when `auth.uid()`
--    is NULL, so `not is_team_admin()` evaluated to NULL rather than false.
--    In PL/pgSQL a NULL condition is treated as false, so the trigger silently
--    did nothing instead of raising. A real request always carries a JWT so
--    this was not reachable from the app — but a guard that disappears when a
--    claim is missing is not a guard.

-- ---------------------------------------------------------------------------
-- 1. NULL-safe role guard
-- ---------------------------------------------------------------------------

create or replace function public.protect_profile_role()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.role is distinct from old.role
     or new.business_ids is distinct from old.business_ids
  then
    -- `is_team_admin()` can be NULL when there is no JWT claim. Coalescing to
    -- false means an unattributable write is denied rather than waved through.
    if coalesce(public.is_team_admin(), false) then
      return new;
    end if;

    -- The bootstrap window. See the note at the top of this file.
    if new.role = 'team_admin'
       and public.bootstrap_open()
       and auth.uid() is not null
       and new.id = auth.uid()
    then
      return new;
    end if;

    raise exception 'Only a team admin can change role or assigned businesses'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. The bootstrap window
-- ---------------------------------------------------------------------------

-- True only while the island has no team admin whatsoever.
--
-- Narrow on purpose:
--   * no team admin exists at all — not "the caller is not one"
--   * the caller is promoting *themselves*, so an RPC cannot name an arbitrary
--     account and hand it the highest privilege in the app
--
-- The moment a team admin exists this returns false forever, because nobody
-- can then remove one without already being one.
create or replace function public.bootstrap_open()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select not exists (
    select 1 from public.profiles where role = 'team_admin'
  );
$$;

comment on function public.bootstrap_open() is
  'True only while no team_admin exists. Lets the first signed-in user promote '
  'themselves so the island is not permanently locked out of its own moderation '
  'tools. Closes permanently once the first admin exists.';

-- ---------------------------------------------------------------------------
-- 3. Concurrent callers
-- ---------------------------------------------------------------------------

-- Two people opening the app on the same morning could both pass the check.
-- An advisory lock makes promotion serial: whoever gets the lock first wins,
-- and the second sees the window closed and is denied.
create or replace function public.claim_team_admin()
returns boolean
language plpgsql
security definer set search_path = public
as $$
declare v_id uuid;
begin
  if auth.uid() is null then return false; end if;
  v_id := auth.uid();

  -- Serialise. Any contention waits, then re-checks after the winner commits.
  perform pg_advisory_xact_lock(hashtext('islandads_bootstrap_team_admin'));

  if not public.bootstrap_open() then return false; end if;

  update public.profiles set role = 'team_admin' where id = v_id;
  if not found then return false; end if;

  return true;
end;
$$;

grant execute on function public.claim_team_admin() to authenticated;

comment on function public.claim_team_admin() is
  'Promotes the calling user to team_admin, but only while none exists. Call '
  'once from the first team member''s account. Returns false afterwards.';

notify pgrst, 'reload schema';