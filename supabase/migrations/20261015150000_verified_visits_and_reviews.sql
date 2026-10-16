-- Phase 6: verified visits by QR at the till, and reviews only behind them.
--
-- Closes three holes that made "verified" meaningless. With the publishable
-- key, a signed-in user could:
--   1. insert a review already marked 'verified' (the status trigger only ran
--      on UPDATE, and the insert policy checked nothing but user_id);
--   2. update their own pending review to 'verified' (the trigger allowed any
--      move *to* 'verified');
--   3. insert a visit already marked confirmed_by_business.
-- Every write now goes through a function that applies the rules.

-- ---------------------------------------------------------------------------
-- Lock direct writes
-- ---------------------------------------------------------------------------

drop policy if exists "reviews_insert_own" on public.reviews;
drop policy if exists "reviews_update_own" on public.reviews;

drop policy if exists "visits_insert_own" on public.visits;
drop policy if exists "visits_update_own" on public.visits;
drop policy if exists "visits_update_business" on public.visits;

-- A request is always created pending; only the business answers it.
drop policy if exists "review_requests_insert_own" on public.review_requests;
create policy "review_requests_insert_own"
  on public.review_requests for insert
  with check (user_id = auth.uid() and status = 'pending');

-- Reviews: outside the team, status, rating, text and authorship never change
-- by direct update. A business may only reply and flag a dispute.
create or replace function public.protect_review_status()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if public.is_team_admin() then
    return new;
  end if;

  if new.status is distinct from old.status
     or new.rating is distinct from old.rating
     or new.body is distinct from old.body
     or new.user_id is distinct from old.user_id
     or new.business_id is distinct from old.business_id
     or new.is_reported is distinct from old.is_reported then
    raise exception 'Only a reply or a dispute can be changed here'
      using errcode = '42501';
  end if;

  if new.reply is distinct from old.reply then
    new.replied_at := now();
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Rotating visit codes
-- ---------------------------------------------------------------------------

-- One secret per business. Never readable by anyone: the code is derived
-- from it per Antigua day, so yesterday's code (a photo of the till QR,
-- say) stops working at midnight.
create table if not exists public.visit_secrets (
  business_id uuid primary key references public.businesses (id) on delete cascade,
  secret      text not null default encode(extensions.gen_random_bytes(16), 'hex')
);
alter table public.visit_secrets enable row level security;
revoke all on public.visit_secrets from anon, authenticated;

create or replace function public.visit_code_for(p_business uuid, p_day date)
returns text
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_secret text;
begin
  insert into public.visit_secrets (business_id) values (p_business)
  on conflict (business_id) do nothing;
  select secret into v_secret from public.visit_secrets where business_id = p_business;
  -- Six hex characters: no O/I/L to confuse with 0/1, and 16.7 million
  -- possibilities against a code that only lives for one day.
  return upper(substr(encode(hmac(p_day::text, v_secret, 'sha256'), 'hex'), 1, 6));
end;
$$;
revoke all on function public.visit_code_for(uuid, date) from public, anon, authenticated;

-- Antigua's calendar day for an instant. UTC-4, no daylight saving.
create or replace function public.antigua_day(p_at timestamptz)
returns date
language sql immutable
as $$ select ((p_at at time zone 'UTC') - interval '4 hours')::date $$;

-- Today's code, for the business to show at the till.
create or replace function public.current_visit_code(p_business uuid)
returns text
language plpgsql security definer set search_path = public
as $$
begin
  if not public.administers(p_business) then
    raise exception 'Only the business can show its visit code'
      using errcode = '42501';
  end if;
  return public.visit_code_for(p_business, public.antigua_day(now()));
end;
$$;
grant execute on function public.current_visit_code(uuid) to authenticated;

-- Whether the caller runs this business (not merely a team admin, who
-- administers everything). Owners cannot check in or review themselves.
create or replace function public.owns_business(p_business uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and p_business = any (business_ids)
  )
$$;

-- A customer checks in with the code they scanned or typed.
--
-- p_scanned_at lets a scan made with no signal sync later: the code is
-- checked against the day it was scanned, within the last three days.
create or replace function public.check_in(
  p_business uuid,
  p_code text,
  p_scanned_at timestamptz default now()
)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_day date;
begin
  if v_uid is null then
    raise exception 'Sign in to check in' using errcode = '42501';
  end if;
  if p_scanned_at > now() + interval '5 minutes'
     or p_scanned_at < now() - interval '3 days' then
    raise exception 'That check-in is too old to count'
      using errcode = 'check_violation';
  end if;
  if public.owns_business(p_business) then
    raise exception 'You cannot check in at your own business'
      using errcode = '42501';
  end if;

  v_day := public.antigua_day(p_scanned_at);
  if upper(btrim(coalesce(p_code, ''))) <> public.visit_code_for(p_business, v_day) then
    raise exception 'That code does not match this business today'
      using errcode = 'check_violation';
  end if;

  insert into public.visits (user_id, business_id, visited_at, confirmed_by_business)
  values (v_uid, p_business, p_scanned_at, true)
  on conflict (user_id, business_id, visit_date)
  do update set confirmed_by_business = true;

  return 'ok';
end;
$$;
grant execute on function public.check_in(uuid, text, timestamptz) to authenticated;

-- ---------------------------------------------------------------------------
-- Reviews
-- ---------------------------------------------------------------------------

-- The only way to write a review. It is verified on arrival because the gate
-- is checked here: a confirmed visit, or a request the business approved.
create or replace function public.submit_review(
  p_business uuid,
  p_rating integer,
  p_body text
)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'Sign in to review' using errcode = '42501';
  end if;
  if p_rating is null or p_rating not between 1 and 5 then
    raise exception 'A rating is 1 to 5 stars' using errcode = 'check_violation';
  end if;
  if length(coalesce(p_body, '')) > 2000 then
    raise exception 'Keep the review under 2000 characters'
      using errcode = 'check_violation';
  end if;
  if public.owns_business(p_business) then
    raise exception 'You cannot review your own business' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.businesses where id = p_business and accepts_reviews
  ) then
    raise exception 'This business does not take reviews'
      using errcode = 'check_violation';
  end if;
  if not exists (
    select 1 from public.visits
    where user_id = v_uid and business_id = p_business and confirmed_by_business
  ) and not exists (
    select 1 from public.review_requests
    where user_id = v_uid and business_id = p_business and status = 'approved'
  ) then
    raise exception 'Check in at the business before reviewing it'
      using errcode = 'check_violation';
  end if;
  if exists (
    select 1 from public.reviews where user_id = v_uid and business_id = p_business
  ) then
    raise exception 'You have already reviewed this business'
      using errcode = 'unique_violation';
  end if;

  insert into public.reviews (business_id, user_id, rating, body, status)
  values (p_business, v_uid, p_rating, btrim(coalesce(p_body, '')), 'verified')
  returning id into v_id;
  return v_id;
end;
$$;
grant execute on function public.submit_review(uuid, integer, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Reports
-- ---------------------------------------------------------------------------

create table if not exists public.review_reports (
  review_id  uuid not null references public.reviews (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  reason     text not null check (length(btrim(reason)) > 0),
  created_at timestamptz not null default now(),
  primary key (review_id, user_id)
);
alter table public.review_reports enable row level security;
drop policy if exists review_reports_team on public.review_reports;
create policy review_reports_team on public.review_reports for select
  using (public.is_team_admin());

-- Any signed-in user may report a review once; it goes to the team queue.
create or replace function public.report_review(p_review uuid, p_reason text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in to report' using errcode = '42501';
  end if;
  if length(btrim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Say what is wrong with it' using errcode = 'check_violation';
  end if;
  insert into public.review_reports (review_id, user_id, reason)
  values (p_review, auth.uid(), btrim(p_reason))
  on conflict (review_id, user_id) do nothing;
  update public.reviews set is_reported = true where id = p_review;
end;
$$;
grant execute on function public.report_review(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Declining a request needs a reason (plan.md section 7, mitigation 1)
-- ---------------------------------------------------------------------------

alter table public.review_requests add column if not exists decline_reason text;
alter table public.review_requests drop constraint if exists review_requests_decline_reason;
alter table public.review_requests add constraint review_requests_decline_reason
  check (status <> 'declined' or length(btrim(coalesce(decline_reason, ''))) >= 5);

create or replace function public.respond_to_review_request(
  p_request uuid,
  p_approve boolean,
  p_reason text default null
)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_business uuid;
begin
  select business_id into v_business from public.review_requests where id = p_request;
  if v_business is null or not public.administers(v_business) then
    raise exception 'Not your request to answer' using errcode = '42501';
  end if;
  if not p_approve and length(btrim(coalesce(p_reason, ''))) < 5 then
    raise exception 'Give a reason for declining' using errcode = 'check_violation';
  end if;
  update public.review_requests
  set status = case when p_approve then 'approved' else 'declined' end,
      decline_reason = case when p_approve then null else btrim(p_reason) end,
      responded_at = now()
  where id = p_request;
end;
$$;
grant execute on function public.respond_to_review_request(uuid, boolean, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Team audit (plan.md section 7, mitigation 2)
-- ---------------------------------------------------------------------------

create or replace function public.review_audit()
returns table (
  business_id uuid,
  business_name text,
  requests bigint,
  approved bigint,
  declined bigint,
  checked_in_visits bigint,
  reviews bigint,
  recent_decline_reasons text[]
)
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_team_admin() then
    raise exception 'Team only' using errcode = '42501';
  end if;
  return query
  select
    b.id,
    b.name,
    (select count(*) from public.review_requests r where r.business_id = b.id),
    (select count(*) from public.review_requests r where r.business_id = b.id and r.status = 'approved'),
    (select count(*) from public.review_requests r where r.business_id = b.id and r.status = 'declined'),
    (select count(*) from public.visits v where v.business_id = b.id and v.confirmed_by_business),
    (select count(*) from public.reviews rv where rv.business_id = b.id and rv.status = 'verified'),
    array(
      select r.decline_reason from public.review_requests r
      where r.business_id = b.id and r.status = 'declined'
      order by r.responded_at desc nulls last limit 5
    )
  from public.businesses b
  order by b.name;
end;
$$;
grant execute on function public.review_audit() to authenticated;
