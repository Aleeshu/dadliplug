-- Initial schema for the Antigua Business Map.
--
-- Roles live here rather than in auth.users metadata because the team grants
-- them by hand and needs to query them alongside businesses. The role is the
-- sharpest edge in the whole schema — see the RLS migration, which stops a
-- user promoting themselves.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  email        text not null,
  display_name text,
  role         text not null default 'user'
                 check (role in ('user', 'business_admin', 'team_admin')),
  -- Which listings this user may edit. Empty for regular users.
  business_ids uuid[] not null default '{}',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on column public.profiles.role is
  'user | business_admin | team_admin. Granted by the team, never self-assigned.';

-- ---------------------------------------------------------------------------
-- businesses
-- ---------------------------------------------------------------------------

create table public.businesses (
  id                  uuid primary key default gen_random_uuid(),
  name                text not null,
  category            text not null,
  area                text,
  description         text not null default '',

  latitude            double precision,
  longitude           double precision,
  address             text,

  phone               text,
  whatsapp            text,
  website             text,
  price_range         text,

  -- Mon-Sun day numbers (1 = Monday, 7 = Sunday) plus one open/close pair.
  -- Fractional hours, so 9.5 is 9:30am.
  hours               jsonb not null default '{"days":[],"opensAt":9,"closesAt":17}',
  photos              jsonb not null default '[]',
  -- Food businesses list a menu; everything else lists services. One column
  -- because the rendering is identical.
  menu                jsonb not null default '[]',

  -- The promotional deal a premium business advertises.
  offer               text,
  accepts_reviews     boolean not null default true,

  tier                text not null default 'basic'
                        check (tier in ('basic', 'premium', 'trial', 'overdue', 'delisted')),
  subscription_status text not null default 'delisted',

  -- Ratings that arrived before launch, so a new listing is not shown as
  -- "0 reviews". Seeded by the team, never editable by the business.
  seeded_rating       numeric(3, 2) not null default 0,
  seeded_review_count integer not null default 0,

  views               integer not null default 0,
  calls               integer not null default 0,
  whatsapp_taps       integer not null default 0,

  -- Week index this business last held a Spotlight slot. Lowest is served
  -- first, so the ten slots rotate and everyone gets a turn.
  last_spotlight_week integer not null default -1,

  search_tsv tsvector generated always as (
    to_tsvector(
      'english',
      coalesce(name, '') || ' ' || coalesce(area, '') || ' ' ||
      coalesce(description, '') || ' ' || coalesce(menu::text, '')
    )
  ) stored,

  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- A pin needs a location, but online-only businesses have none.
create index businesses_category_idx on public.businesses (category);
create index businesses_status_idx on public.businesses (subscription_status);
create index businesses_search_idx on public.businesses using gin (search_tsv);
create index businesses_spotlight_idx on public.businesses (last_spotlight_week);

-- ---------------------------------------------------------------------------
-- reviews
-- ---------------------------------------------------------------------------

create table public.reviews (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references public.businesses (id) on delete cascade,
  user_id      uuid not null references auth.users (id) on delete cascade,
  rating       integer not null check (rating between 1 and 5),
  body         text not null default '',
  status       text not null default 'locked'
                 check (status in ('pending', 'verified', 'locked', 'removed')),
  reply        text,
  replied_at   timestamptz,
  is_reported  boolean not null default false,
  is_disputed  boolean not null default false,
  created_at   timestamptz not null default now(),

  -- One review per person per business. Doubles as the guard against someone
  -- submitting repeatedly to inflate a rating.
  unique (business_id, user_id)
);

create index reviews_business_idx on public.reviews (business_id, status);
create index reviews_moderation_idx on public.reviews (is_reported, is_disputed)
  where is_reported or is_disputed;

-- ---------------------------------------------------------------------------
-- review_requests
-- ---------------------------------------------------------------------------

-- A customer asks to review; the business confirms they were a customer. The
-- approval is what makes bought ratings structurally hard, because a fake
-- reviewer needs the business's cooperation.
create table public.review_requests (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  business_id  uuid not null references public.businesses (id) on delete cascade,
  status       text not null default 'pending'
                 check (status in ('pending', 'approved', 'declined')),
  requested_at timestamptz not null default now(),
  responded_at timestamptz,

  unique (user_id, business_id)
);

create index review_requests_business_idx
  on public.review_requests (business_id, status);

-- ---------------------------------------------------------------------------
-- visits
-- ---------------------------------------------------------------------------

-- Evidence that someone actually went somewhere. Powers "your places" and the
-- review gate.
create table public.visits (
  id                      uuid primary key default gen_random_uuid(),
  user_id                 uuid not null references auth.users (id) on delete cascade,
  business_id             uuid not null references public.businesses (id) on delete cascade,
  visited_at              timestamptz not null default now(),
  confirmed_by_business   boolean not null default false,
  -- The calendar day of the visit, in Antigua time, as a stored column rather
  -- than an index expression. `timestamptz::date` is not IMMUTABLE because it
  -- depends on the session timezone, so Postgres refuses it in a unique index.
  -- Antigua is UTC-4 year round with no daylight saving, so the offset is
  -- fixed and hard-coding it is correct rather than a shortcut.
  visit_date             date generated always as
                           (((visited_at at time zone 'UTC') - interval '4 hours')::date)
                           stored
);

create index visits_user_idx on public.visits (user_id, visited_at desc);

-- One visit per person per business per day. Without this, someone could inflate
-- their own visit count by tapping repeatedly.
create unique index visits_one_per_day_uniq
  on public.visits (user_id, business_id, visit_date);

-- ---------------------------------------------------------------------------
-- subscriptions
-- ---------------------------------------------------------------------------

-- Tracked internally because payment is by transfer, not through the app.
create table public.subscriptions (
  business_id uuid primary key references public.businesses (id) on delete cascade,
  tier        text not null check (tier in ('basic', 'premium')),
  started_at  timestamptz not null default now(),
  renews_at   timestamptz,
  ended_at    timestamptz,
  is_active   boolean not null default true,
  -- Who marked it active, since payment is offline and someone does it by hand.
  marked_by   uuid references auth.users (id)
);

-- ---------------------------------------------------------------------------
-- spotlight
-- ---------------------------------------------------------------------------

create table public.spotlight (
  week        integer not null,
  business_id uuid not null references public.businesses (id) on delete cascade,
  rank        integer not null,
  primary key (week, business_id)
);

create index spotlight_week_idx on public.spotlight (week, rank);

-- ---------------------------------------------------------------------------
-- updated_at
-- ---------------------------------------------------------------------------

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

create trigger businesses_touch before update on public.businesses
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- profile creation
-- ---------------------------------------------------------------------------

-- Creating the profile in a trigger means sign-up never writes to two tables
-- and can never leave an account without one.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name)
  values (
    new.id,
    coalesce(new.email, ''),
    new.raw_user_meta_data ->> 'display_name'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();