-- Content the businesses post: advertisements, announcements, events.
-- Plus follows/bookmarks, which the customer navigation needs.
--
-- All three content tables are business-owned and customer-read. The split is
-- deliberate and matches plan.md section 6a: customers can only view what the
-- business shows, so there is no customer insert path onto any of these.

-- ---------------------------------------------------------------------------
-- Advertisements
-- ---------------------------------------------------------------------------
-- The literal pitch: an app businesses advertise in. Dated so the team and the
-- owner can both see whether an ad is still running, and so views per ad can be
-- reported at month end.

create table if not exists public.business_ads (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  title       text not null,
  body        text not null default '',
  image_url   text,
  link_url    text,
  starts_at   timestamptz not null default now(),
  ends_at     timestamptz,
  views       integer not null default 0,
  created_at  timestamptz not null default now(),

  constraint business_ads_title_present check (length(btrim(title)) > 0)
);

create index if not exists business_ads_business_idx
  on public.business_ads (business_id, starts_at desc);

create index if not exists business_ads_live_idx
  on public.business_ads (starts_at, ends_at)
  where ends_at is null;

-- ---------------------------------------------------------------------------
-- Announcements
-- ---------------------------------------------------------------------------
-- One-way broadcast from a business. Read receipts so an owner knows a message
-- was actually seen rather than merely posted.

create table if not exists public.business_announcements (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  title       text not null,
  body        text not null default '',
  created_at  timestamptz not null default now(),

  constraint business_announcements_title_present check (length(btrim(title)) > 0)
);

create index if not exists business_announcements_recent_idx
  on public.business_announcements (created_at desc);

create table if not exists public.announcement_reads (
  announcement_id uuid not null
    references public.business_announcements (id) on delete cascade,
  user_id        uuid not null references auth.users (id) on delete cascade,
  read_at        timestamptz not null default now(),

  primary key (announcement_id, user_id)
);

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
-- Gives locals a reason to open the app in a given week. Carnival, sailing week
-- and Shirley Heights are the obvious first entries.

create table if not exists public.business_events (
  id            uuid primary key default gen_random_uuid(),
  business_id   uuid not null references public.businesses (id) on delete cascade,
  title         text not null,
  body          text not null default '',
  starts_at     timestamptz not null,
  ends_at       timestamptz,
  location_note text,
  created_at    timestamptz not null default now(),

  constraint business_events_title_present check (length(btrim(title)) > 0),
  -- An event that ends before it starts is a data-entry mistake, and would
  -- sort into the past immediately.
  constraint business_events_order check (ends_at is null or ends_at >= starts_at)
);

create index if not exists business_events_upcoming_idx
  on public.business_events (starts_at);

-- ---------------------------------------------------------------------------
-- Follows and bookmarks
-- ---------------------------------------------------------------------------
-- One table serves both. A customer follows a business to get its
-- announcements, and that same relationship is the bookmark. Splitting them
-- would mean two lists to reconcile and no way to tell a followed business
-- from a merely saved one.

create table if not exists public.business_follows (
  user_id     uuid not null references auth.users (id) on delete cascade,
  business_id uuid not null references public.businesses (id) on delete cascade,
  created_at  timestamptz not null default now(),

  primary key (user_id, business_id)
);

create index if not exists business_follows_business_idx
  on public.business_follows (business_id);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.business_ads enable row level security;
alter table public.business_announcements enable row level security;
alter table public.announcement_reads enable row level security;
alter table public.business_events enable row level security;
alter table public.business_follows enable row level security;

-- Anyone can read the content of a live listing; only an administrator of that
-- listing may write it. `administers()` already existed from the initial RLS
-- migration and is the single definition of "may this person edit this
-- business" — the team role and the owner's `profiles.business_ids` entry.
--
-- Reused rather than redefined on purpose. A second, near-identical ownership
-- helper would be a second answer to the same question, and the two would
-- eventually disagree.
create or replace function public.can_read_business_content(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.administers(p_business_id)
      or exists (
        select 1 from public.businesses b
        where b.id = p_business_id and b.tier <> 'delisted'
      );
$$;

drop policy if exists ads_read on public.business_ads;
create policy ads_read on public.business_ads for select
  using (public.can_read_business_content(business_id));

drop policy if exists ads_insert on public.business_ads;
create policy ads_insert on public.business_ads for insert
  with check (public.administers(business_id));

drop policy if exists ads_update on public.business_ads;
create policy ads_update on public.business_ads for update
  using (public.administers(business_id))
  with check (public.administers(business_id));

drop policy if exists ads_delete on public.business_ads;
create policy ads_delete on public.business_ads for delete
  using (public.administers(business_id));

drop policy if exists announcements_read on public.business_announcements;
create policy announcements_read on public.business_announcements for select
  using (public.can_read_business_content(business_id));

drop policy if exists announcements_insert on public.business_announcements;
create policy announcements_insert on public.business_announcements for insert
  with check (public.administers(business_id));

drop policy if exists announcements_update on public.business_announcements;
create policy announcements_update on public.business_announcements for update
  using (public.administers(business_id))
  with check (public.administers(business_id));

drop policy if exists announcements_delete on public.business_announcements;
create policy announcements_delete on public.business_announcements for delete
  using (public.administers(business_id));

drop policy if exists reads_own on public.announcement_reads;
create policy reads_own on public.announcement_reads for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists events_read on public.business_events;
create policy events_read on public.business_events for select
  using (public.can_read_business_content(business_id));

drop policy if exists events_insert on public.business_events;
create policy events_insert on public.business_events for insert
  with check (public.administers(business_id));

drop policy if exists events_update on public.business_events;
create policy events_update on public.business_events for update
  using (public.administers(business_id))
  with check (public.administers(business_id));

drop policy if exists events_delete on public.business_events;
create policy events_delete on public.business_events for delete
  using (public.administers(business_id));

-- Follows are private. Only the follower sees what they saved.
drop policy if exists follows_own on public.business_follows;
create policy follows_own on public.business_follows for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());