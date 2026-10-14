-- Email auto-confirmation: off by default.
--
-- `20261011230100_auto_confirm_dev_only.sql` confirmed every signup, so anyone
-- could create an account on an address they do not own and it would be marked
-- confirmed. The name said "dev only" but nothing enforced that: the trigger
-- ran in production too. That is a launch blocker.
--
-- Real SMTP is the fix, and it is a dashboard change we cannot make from here.
-- Deleting the trigger outright would also lock the team out of testing sign-up
-- until SMTP is configured, which is how these things get quietly left broken.
--
-- So the behaviour is kept but gated on a row that defaults to off. Production
-- is safe by default, and development opts in with one deliberate update.
--
--   -- development:
--   update public.dev_flags set auto_confirm_email = true where id = true;
--
--   -- production, before launch:
--   update public.dev_flags set auto_confirm_email = false where id = true;
--
-- Also drops the security banner from the app's sign-in screen, which existed
-- only because this trigger was on unconditionally.

drop trigger if exists auto_confirm_on_signup on auth.users;

drop function if exists public.auto_confirm_new_user();

-- ---------------------------------------------------------------------------
-- Dev flags
-- ---------------------------------------------------------------------------

create table if not exists public.dev_flags (
  id                  boolean primary key default true,
  auto_confirm_email  boolean not null default false,
  note                text
);

comment on table public.dev_flags is
  'Development conveniences that must never be left on in production. Read by '
  'the auto-confirm trigger; nothing else depends on it.';

comment on column public.dev_flags.auto_confirm_email is
  'Confirms every signup without an email link. OFF in production. Turn on for '
  'local testing only, and off again before any shared or public build.';

-- Seeded off. Deliberately not `on` "because we are still building": the whole
-- point is that the safe state is the one you get without asking.
insert into public.dev_flags (id, auto_confirm_email, note)
values (true, false, 'auto-confirm off by default; enable locally, disable before launch')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- The gated trigger
-- ---------------------------------------------------------------------------

create or replace function public.auto_confirm_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- No-ops unless someone has explicitly turned it on. Reading the flag means
  -- enabling it is a visible database change rather than a side effect of some
  -- other migration.
  if not exists (
    select 1 from public.dev_flags
    where id = true and auto_confirm_email
  ) then
    return new;
  end if;

  new.email_confirmed_at = coalesce(new.email_confirmed_at, now());
  return new;
end;
$$;

create trigger auto_confirm_on_signup
  after insert on auth.users
  for each row execute function public.auto_confirm_new_user();

-- ---------------------------------------------------------------------------
-- Who can flip it
-- ---------------------------------------------------------------------------
-- Nobody through the API. `dev_flags` is not exposed to `anon` or
-- `authenticated`, so the flag cannot be turned on by anyone with the
-- publishable key. Changing it requires the service role or the SQL editor.

alter table public.dev_flags enable row level security;

revoke all on public.dev_flags from anon, authenticated;