-- Three subscription tiers, in EC dollars.
--
-- plan.md previously carried two tiers (basic, premium) priced in US dollars.
-- The real pricing is EC$25 growing / EC$50 basic / EC$200 featured, which is
-- a different shape, not just different numbers: a new entry below basic, and
-- a rename of the top tier to match what the business actually sees.
--
-- The rename preserves any existing premium subscriptions rather than resetting
-- them, so nobody loses a paid slot through a schema change.

-- ---------------------------------------------------------------------------
-- Businesses
-- ---------------------------------------------------------------------------

alter table public.businesses drop constraint if exists businesses_tier_check;

update public.businesses set tier = 'featured' where tier = 'premium';

alter table public.businesses
  add constraint businesses_tier_check
  check (tier in ('growing', 'basic', 'featured', 'trial', 'overdue', 'delisted'));

alter table public.businesses alter column tier set default 'growing';

-- ---------------------------------------------------------------------------
-- Subscriptions
-- ---------------------------------------------------------------------------

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conrelid = 'public.subscriptions'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%premium%'
  ) then
    alter table public.subscriptions
      drop constraint subscriptions_tier_check;
  end if;
end $$;

update public.subscriptions set tier = 'featured' where tier = 'premium';

do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public'
               and table_name = 'subscriptions'
               and column_name = 'tier') then
    alter table public.subscriptions
      add constraint subscriptions_tier_check
      check (tier in ('growing', 'basic', 'featured', 'trial', 'overdue', 'delisted'));
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Leaderboard grace period
-- ---------------------------------------------------------------------------
-- A new listing has no reviews and no views, so ranked honestly it sits last
-- and the board measures who signed up first rather than who is good. Each
-- listing is held back for a month.
--
-- Stored as a column rather than computed in the query so the window is
-- auditable and adjustable without touching every client. Null created_at
-- means the age is unknown, which the client treats as brand new.

alter table public.businesses
  add column if not exists created_at timestamptz not null default now();

create index if not exists businesses_leaderboard_idx
  on public.businesses (category, created_at)
  where tier <> 'delisted';