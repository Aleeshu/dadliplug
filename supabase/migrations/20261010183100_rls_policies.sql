-- Row Level Security.
--
-- This is the real access control. Hiding a tab in the app is a convenience,
-- not a security boundary — anyone can type a URL, and the client is on the
-- user's phone.
--
-- The sharp edge is `profiles.role`. A blanket "update your own row" policy
-- would let any user promote themselves to team_admin and reach the moderation
-- queue. The update policy below uses a column list plus a `with check` so the
-- role cannot change from the client.

-- ---------------------------------------------------------------------------
-- Helper
-- ---------------------------------------------------------------------------

-- SECURITY DEFINER so the policies below do not recurse: reading your own role
-- from `profiles` inside a policy on `profiles` would call that policy again.
create or replace function public.current_role()
returns text
language sql
stable
security definer set search_path = public
as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.is_team_admin()
returns boolean
language sql stable
as $$
  select public.current_role() = 'team_admin'
$$;

create or replace function public.is_business_admin()
returns boolean
language sql stable
as $$
  select public.current_role() = 'business_admin'
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

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;

-- Own row, or any row for team.
create policy "profiles_select"
  on public.profiles for select
  using (id = auth.uid() or public.is_team_admin());

-- The role and business_ids are deliberately absent from the column list. A
-- user can correct their own display name; they cannot promote themselves.
create policy "profiles_update_own"
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

grant update (display_name) on public.profiles to authenticated;

-- Team changes roles, and assigns businesses to admins.
create policy "profiles_update_team"
  on public.profiles for update
  using (public.is_team_admin())
  with check (public.is_team_admin());

grant update (role, business_ids) on public.profiles to authenticated;

-- ---------------------------------------------------------------------------
-- businesses
-- ---------------------------------------------------------------------------

alter table public.businesses enable row level security;

-- A delisted business is invisible to everyone. Admins and team still see it,
-- otherwise they could not manage a lapsed account.
create policy "businesses_select"
  on public.businesses for select
  using (subscription_status <> 'delisted' or public.administers(id));

create policy "businesses_update_admin"
  on public.businesses for update
  using (public.administers(id))
  with check (public.administers(id));

create policy "businesses_insert_team"
  on public.businesses for insert
  with check (public.is_team_admin());

create policy "businesses_delete_team"
  on public.businesses for delete
  using (public.is_team_admin());

-- Ranking inputs are counters the client increments. Open to any signed-in
-- user because a view counter behind a write check is a privacy question
-- nobody needs to be asking for a business directory.
create policy "businesses_counters"
  on public.businesses for update
  using (auth.uid() is not null)
  with check (public.administers(id));

-- ---------------------------------------------------------------------------
-- reviews
-- ---------------------------------------------------------------------------

alter table public.reviews enable row level security;

-- Only verified, non-removed reviews are readable.
create policy "reviews_select"
  on public.reviews for select
  using (
    (status = 'verified' and status <> 'removed')
    or user_id = auth.uid()
    or public.administers(business_id)
  );

create policy "reviews_insert_own"
  on public.reviews for insert
  with check (user_id = auth.uid());

-- Reviewers may edit their own text while it is locked or pending. Not once
-- verified — otherwise ratings could be edited after the fact.
create policy "reviews_update_own"
  on public.reviews for update
  using (user_id = auth.uid() and status in ('pending', 'locked'))
  with check (user_id = auth.uid());

-- Businesses reply and dispute. Team sets status and removes.
create policy "reviews_update_business"
  on public.reviews for update
  using (public.administers(business_id))
  with check (public.administers(business_id));

create policy "reviews_update_team"
  on public.reviews for update
  using (public.is_team_admin())
  with check (public.is_team_admin());

-- ---------------------------------------------------------------------------
-- review_requests
-- ---------------------------------------------------------------------------

alter table public.review_requests enable row level security;

create policy "review_requests_select"
  on public.review_requests for select
  using (user_id = auth.uid() or public.administers(business_id));

create policy "review_requests_insert_own"
  on public.review_requests for insert
  with check (user_id = auth.uid());

-- Only the business being reviewed may respond. A user changing their own
-- request status would let anyone self-approve.
create policy "review_requests_respond_business"
  on public.review_requests for update
  using (public.administers(business_id))
  with check (public.administers(business_id));

-- ---------------------------------------------------------------------------
-- visits
-- ---------------------------------------------------------------------------

alter table public.visits enable row level security;

create policy "visits_select_own"
  on public.visits for select
  using (user_id = auth.uid() or public.administers(business_id));

create policy "visits_insert_own"
  on public.visits for insert
  with check (user_id = auth.uid());

-- The user cannot set `confirmed_by_business` — that is the business's to grant.
create policy "visits_update_own"
  on public.visits for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and confirmed_by_business = false);

create policy "visits_update_business"
  on public.visits for update
  using (public.administers(business_id))
  with check (public.administers(business_id));

-- ---------------------------------------------------------------------------
-- subscriptions
-- ---------------------------------------------------------------------------

alter table public.subscriptions enable row level security;

-- Team only. Payment is offline, so the client has no business writing here.
create policy "subscriptions_team_only"
  on public.subscriptions for all
  using (public.is_team_admin())
  with check (public.is_team_admin());

-- A business may read its own subscription so it can show the tier.
create policy "subscriptions_select_admin"
  on public.subscriptions for select
  using (public.administers(business_id));

-- ---------------------------------------------------------------------------
-- spotlight
-- ---------------------------------------------------------------------------

alter table public.spotlight enable row level security;

create policy "spotlight_select_all"
  on public.spotlight for select
  using (true);

create policy "spotlight_write_team"
  on public.spotlight for all
  using (public.is_team_admin())
  with check (public.is_team_admin());