-- Phase 8: ranking.
--
-- 1. Live reviews count. Listing rows carried only the ratings imported before
--    launch, so a verified review written in the app moved nothing: not the
--    stars on a card, not the rank, not the leaderboard. Each listing now
--    carries the count and star total of its verified reviews, kept by a
--    trigger on reviews.
-- 2. A nightly rank snapshot ("recomputed on a schedule", plan.md Phase 8),
--    which gives the team and owners movement over time.
-- 3. The Spotlight board: ten slots, least-recently-featured first, rotated
--    every Monday (plan.md section 3).

-- ---------------------------------------------------------------------------
-- 1. Verified review totals on the listing
-- ---------------------------------------------------------------------------

alter table public.businesses
  add column if not exists review_count integer not null default 0,
  add column if not exists review_rating_sum integer not null default 0;

create or replace function public.refresh_review_totals(p_business uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config('islandads.counter_write', 'on', true);
  update public.businesses b
     set review_count = t.n,
         review_rating_sum = t.total
    from (
      select count(*)::integer as n, coalesce(sum(rating), 0)::integer as total
        from public.reviews
       where business_id = p_business and status = 'verified'
    ) t
   where b.id = p_business
     and (b.review_count, b.review_rating_sum) is distinct from (t.n, t.total);
  perform set_config('islandads.counter_write', 'off', true);
end;
$$;

revoke all on function public.refresh_review_totals(uuid) from public, anon, authenticated;

create or replace function public.reviews_refresh_totals()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform public.refresh_review_totals(old.business_id);
  end if;
  if tg_op in ('INSERT', 'UPDATE')
     and (tg_op = 'INSERT' or new.business_id is distinct from old.business_id) then
    perform public.refresh_review_totals(new.business_id);
  end if;
  return null;
end;
$$;

drop trigger if exists reviews_refresh_totals on public.reviews;
create trigger reviews_refresh_totals
  after insert or update of status, rating, business_id or delete on public.reviews
  for each row execute function public.reviews_refresh_totals();

-- Backfill.
do $$
declare r record;
begin
  for r in select id from public.businesses loop
    perform public.refresh_review_totals(r.id);
  end loop;
end;
$$;

-- The totals are counters: only the trigger sets them.
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
     or new.review_count is distinct from old.review_count
     or new.review_rating_sum is distinct from old.review_rating_sum
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
-- 2. The score, and a nightly snapshot of it
-- ---------------------------------------------------------------------------

-- The same formula as scoreBusiness() in app/lib/services/ranking_service.dart.
-- Change both or neither; test/ranking_parity_test.dart pins shared values.
create or replace function public.rank_score(
  p_seeded_rating double precision,
  p_seeded_count integer,
  p_live_sum integer,
  p_live_count integer,
  p_engagement bigint
)
returns integer
language sql
immutable
as $$
  with s as (
    select p_seeded_count + p_live_count as n,
           case when p_seeded_count + p_live_count = 0 then 0
                else (p_seeded_rating * p_seeded_count + p_live_sum)
                     / (p_seeded_count + p_live_count) end as avg
  )
  select round((100 * (
           0.45 * (((3.8 * 5 + avg * n) / (5 + n)) - 1) / 4
         + 0.25 * least(1, ln(1 + n) / ln(61))
         + 0.30 * least(1, ln(1 + p_engagement) / ln(3001))
         ))::numeric)::integer
    from s;
$$;

create table if not exists public.rank_snapshots (
  day         date not null,
  business_id uuid not null references public.businesses (id) on delete cascade,
  category    text not null,
  score       integer not null,
  position    integer not null,
  of_count    integer not null,
  primary key (day, business_id)
);

alter table public.rank_snapshots enable row level security;

-- An owner sees their own history; the team sees all.
drop policy if exists rank_snapshots_read on public.rank_snapshots;
create policy rank_snapshots_read on public.rank_snapshots for select
  using (coalesce(public.administers(business_id), false));
revoke insert, update, delete on public.rank_snapshots from anon, authenticated;

create or replace function public.snapshot_ranks()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_day date := (now() at time zone 'America/Antigua')::date;
  v_rows integer;
begin
  if auth.jwt() is not null and not coalesce(public.is_team_admin(), false) then
    raise exception 'Team only' using errcode = '42501';
  end if;

  delete from public.rank_snapshots where day = v_day;

  insert into public.rank_snapshots (day, business_id, category, score, position, of_count)
  select v_day, id, category, score,
         row_number() over (partition by category
                            order by score desc,
                                     seeded_review_count + review_count desc,
                                     name),
         count(*) over (partition by category)
    from (
      select b.*,
             public.rank_score(b.seeded_rating::double precision,
                               b.seeded_review_count, b.review_rating_sum,
                               b.review_count,
                               b.views + 5 * (b.calls + b.whatsapp_taps)) as score
        from public.businesses b
       where b.subscription_status <> 'delisted'
    ) scored;

  get diagnostics v_rows = row_count;

  -- A year of history is plenty for "how have I moved".
  delete from public.rank_snapshots where day < v_day - 400;
  return v_rows;
end;
$$;

grant execute on function public.snapshot_ranks() to anon, authenticated;

-- 00:20 Antigua, after the 00:05 billing run has settled who is listed.
select cron.unschedule('snapshot-ranks')
 where exists (select 1 from cron.job where jobname = 'snapshot-ranks');
select cron.schedule('snapshot-ranks', '20 4 * * *', $$select public.snapshot_ranks()$$);

-- ---------------------------------------------------------------------------
-- 3. Spotlight rotation
-- ---------------------------------------------------------------------------

-- Weeks counted from Monday 5 January 1970, island time.
create or replace function public.spotlight_week(p_at timestamptz default now())
returns integer
language sql
stable
as $$
  select (((p_at at time zone 'America/Antigua')::date - date '1970-01-05') / 7)::integer;
$$;

-- Ten slots. Featured-plan listings first (the board exists so a new Featured
-- subscriber, scoring zero, still gets seen); Basic fills any empty slots.
-- Within each, least recently spotlighted first, then score. Idempotent for
-- the week: re-running replaces the week's board rather than adding to it.
create or replace function public.rotate_spotlight()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_week integer := public.spotlight_week();
  v_rows integer;
begin
  if auth.jwt() is not null and not coalesce(public.is_team_admin(), false) then
    raise exception 'Team only' using errcode = '42501';
  end if;

  -- Undo this week's marks first, so a re-run does not count this week
  -- against the businesses already chosen for it.
  perform set_config('islandads.counter_write', 'on', true);
  update public.businesses b
     set last_spotlight_week = coalesce(
           (select max(s.week) from public.spotlight s
             where s.business_id = b.id and s.week < v_week), -1)
   where b.last_spotlight_week = v_week;
  delete from public.spotlight where week = v_week;

  insert into public.spotlight (week, business_id, rank)
  select v_week, id, row_number() over (order by band, last_spotlight_week, score desc, name)
    from (
      select b.id, b.name, b.last_spotlight_week,
             case b.tier when 'featured' then 0 else 1 end as band,
             public.rank_score(b.seeded_rating::double precision,
                               b.seeded_review_count, b.review_rating_sum,
                               b.review_count,
                               b.views + 5 * (b.calls + b.whatsapp_taps)) as score
        from public.businesses b
       where b.subscription_status <> 'delisted'
         and b.tier in ('featured', 'basic')
       order by band, b.last_spotlight_week, score desc, b.name
       limit 10
    ) chosen;
  get diagnostics v_rows = row_count;

  update public.businesses
     set last_spotlight_week = v_week
   where id in (select business_id from public.spotlight where week = v_week);
  perform set_config('islandads.counter_write', 'off', true);
  return v_rows;
end;
$$;

grant execute on function public.rotate_spotlight() to anon, authenticated;

-- Monday 00:10 Antigua.
select cron.unschedule('rotate-spotlight')
 where exists (select 1 from cron.job where jobname = 'rotate-spotlight');
select cron.schedule('rotate-spotlight', '10 4 * * 1', $$select public.rotate_spotlight()$$);

-- First board and first snapshot now, rather than waiting for the schedule.
select public.rotate_spotlight();
select public.snapshot_ranks();
