-- Phase 4: Business listing details, accuracy tracking, and wrong info reporting.

-- 1. Add fields to businesses
alter table public.businesses
  add column if not exists how_to_find_us   text,
  add column if not exists tags              text[] not null default '{}',
  add column if not exists is_closed_today   boolean not null default false,
  add column if not exists last_verified_at  timestamptz not null default now();

comment on column public.businesses.how_to_find_us is
  'Informal island directions (e.g. past the roundabout, opposite the market).';
comment on column public.businesses.tags is
  'Practical amenities (e.g. cash_only, accepts_cards, accepts_usd, parking, wheelchair_accessible).';
comment on column public.businesses.is_closed_today is
  'Emergency 1-tap temporary closure (hurricane season, Carnival, public holidays).';
comment on column public.businesses.last_verified_at is
  'Timestamp when the listing was last verified by team or business.';

-- 2. Create listing_reports table for "Report wrong info"
create table if not exists public.listing_reports (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references public.businesses (id) on delete cascade,
  user_id      uuid references auth.users (id) on delete set null,
  reason       text not null,
  details      text not null default '',
  status       text not null default 'pending'
                 check (status in ('pending', 'resolved', 'dismissed')),
  created_at   timestamptz not null default now()
);

create index if not exists listing_reports_business_idx
  on public.listing_reports (business_id, status);

-- 3. Row Level Security for listing_reports
alter table public.listing_reports enable row level security;

-- Anyone (including signed-in or anonymous users) can submit a report
create policy "listing_reports_insert_any"
  on public.listing_reports for insert
  with check (true);

-- Only team admins can read or update reports
create policy "listing_reports_select_team"
  on public.listing_reports for select
  using (public.is_team_admin());

create policy "listing_reports_update_team"
  on public.listing_reports for update
  using (public.is_team_admin())
  with check (public.is_team_admin());
