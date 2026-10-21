-- Pre-launch requirements (plan.md Phase 11 and section 14c "add before
-- launch").

-- ---------------------------------------------------------------------------
-- 1. Delete my account
-- ---------------------------------------------------------------------------
-- Both stores require deleting an account from inside the app (Google Play
-- account deletion policy; App Store guideline 5.1.1(v)). Removing the auth
-- user cascades to the profile, reviews, visits, follows, saves, claims and
-- push tokens; engagement events and wrong-info reports keep their counts
-- with the user set to null.
--
-- Team admins are refused: payments and claim decisions name who recorded
-- them, and that audit trail must outlive the account. Another team member
-- removes the role first.

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  if coalesce(public.is_team_admin(), false) then
    raise exception 'A team account cannot delete itself. Ask another team member to remove your team role first.'
      using errcode = '42501';
  end if;
  delete from auth.users where id = v_uid;
end;
$$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Block a reviewer
-- ---------------------------------------------------------------------------
-- App Store guideline 1.2: an app with user-generated content must let a
-- user block abusive users. A block hides that person's reviews from the
-- blocker; reporting (already built) is what brings in the team.

create table if not exists public.user_blocks (
  user_id         uuid not null references auth.users (id) on delete cascade,
  blocked_user_id uuid not null references auth.users (id) on delete cascade,
  created_at      timestamptz not null default now(),
  primary key (user_id, blocked_user_id),
  check (user_id <> blocked_user_id)
);

alter table public.user_blocks enable row level security;

drop policy if exists user_blocks_own on public.user_blocks;
create policy user_blocks_own on public.user_blocks for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 3. Notices: the storm banner
-- ---------------------------------------------------------------------------
-- A team-run notice across the top of the app: a hurricane watch linking to
-- the Met Service, island-wide closures, "reopened after the storm".

create table if not exists public.app_notices (
  id         uuid primary key default gen_random_uuid(),
  kind       text not null default 'info' check (kind in ('storm', 'info')),
  title      text not null check (length(btrim(title)) between 1 and 80),
  body       text not null default '' check (length(body) <= 400),
  link_url   text check (link_url is null or link_url ~ '^https://'),
  starts_at  timestamptz not null default now(),
  ends_at    timestamptz,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at)
);

create index if not exists app_notices_live_idx on public.app_notices (starts_at, ends_at);

alter table public.app_notices enable row level security;

drop policy if exists app_notices_read on public.app_notices;
create policy app_notices_read on public.app_notices for select
  using (
    (starts_at <= now() and (ends_at is null or ends_at > now()))
    or coalesce(public.is_team_admin(), false)
  );

drop policy if exists app_notices_team on public.app_notices;
create policy app_notices_team on public.app_notices for all
  using (coalesce(public.is_team_admin(), false))
  with check (coalesce(public.is_team_admin(), false));

-- ---------------------------------------------------------------------------
-- 4. Curated collections
-- ---------------------------------------------------------------------------
-- Team-written lists such as "Best pepperpot" or "Open on Sunday": local
-- knowledge Google does not have, and shareable (plan.md 14c).

create table if not exists public.collections (
  id         uuid primary key default gen_random_uuid(),
  title      text not null check (length(btrim(title)) between 1 and 60),
  blurb      text not null default '' check (length(blurb) <= 300),
  cover_url  text,
  position   integer not null default 0,
  published  boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.collection_items (
  collection_id uuid not null references public.collections (id) on delete cascade,
  business_id   uuid not null references public.businesses (id) on delete cascade,
  note          text not null default '' check (length(note) <= 200),
  position      integer not null default 0,
  primary key (collection_id, business_id)
);

alter table public.collections enable row level security;
alter table public.collection_items enable row level security;

drop policy if exists collections_read on public.collections;
create policy collections_read on public.collections for select
  using (published or coalesce(public.is_team_admin(), false));
drop policy if exists collections_team on public.collections;
create policy collections_team on public.collections for all
  using (coalesce(public.is_team_admin(), false))
  with check (coalesce(public.is_team_admin(), false));

drop policy if exists collection_items_read on public.collection_items;
create policy collection_items_read on public.collection_items for select
  using (exists (
    select 1 from public.collections c
     where c.id = collection_id
       and (c.published or coalesce(public.is_team_admin(), false))
  ));
drop policy if exists collection_items_team on public.collection_items;
create policy collection_items_team on public.collection_items for all
  using (coalesce(public.is_team_admin(), false))
  with check (coalesce(public.is_team_admin(), false));

-- Two starter collections from the demo listings, so Home shows the feature.
do $$
declare c1 uuid; c2 uuid;
begin
  if not exists (select 1 from public.collections) then
    insert into public.collections (title, blurb, position, published)
    values ('A day on the water',
            'Boat trips, beaches and a sundowner, all bookable from the app.',
            0, true)
    returning id into c1;
    insert into public.collections (title, blurb, position, published)
    values ('Treat yourself',
            'Hair, nails and a proper lunch: the team''s picks for a day off.',
            1, true)
    returning id into c2;

    insert into public.collection_items (collection_id, business_id, note, position)
    select c1, id, '', row_number() over (order by name)
      from public.businesses
     where category in ('entertainment', 'food') and subscription_status <> 'delisted';
    insert into public.collection_items (collection_id, business_id, note, position)
    select c2, id, '', row_number() over (order by name)
      from public.businesses
     where category in ('health_beauty', 'food', 'shopping') and subscription_status <> 'delisted';
  end if;
end;
$$;
