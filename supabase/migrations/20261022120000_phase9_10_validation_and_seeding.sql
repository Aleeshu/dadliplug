-- Phase 9 (validate the business model) and Phase 10 (seed content and field
-- testing).
--
-- 1. business_leads: "Get your business listed". Doubles as the record of
--    the Phase 9 conversations: how an owner advertises today, what it costs
--    them, which plan they lean to, and whether they want the team to keep
--    their listing or to edit it themselves (plan.md section 15, decision 1).
-- 2. Pre-built listings (is_prospect): built by the team before the pitch,
--    hidden from the public, shown to the owner through a preview link.
-- 3. listing_verifications: who checked a listing, how, and when. "Verified
--    in person" is the product (plan.md section 9).

-- ---------------------------------------------------------------------------
-- 1. Leads
-- ---------------------------------------------------------------------------

create table if not exists public.business_leads (
  id              uuid primary key default gen_random_uuid(),
  business_name   text not null check (length(btrim(business_name)) between 1 and 80),
  category        text not null,
  area            text not null default '' check (length(area) <= 60),
  contact_name    text not null check (length(btrim(contact_name)) between 1 and 80),
  phone           text not null check (length(btrim(phone)) between 5 and 30),
  -- How they reach customers now: facebook, instagram, whatsapp_status,
  -- radio, flyers, word_of_mouth, nothing.
  advertises_on   text[] not null default '{}',
  -- Monthly marketing spend today, EC$ band: none, under_50, 50_150,
  -- 150_500, over_500.
  spend_band      text not null default 'none'
                    check (spend_band in ('none', 'under_50', '50_150', '150_500', 'over_500')),
  plan_interest   text not null default 'unsure'
                    check (plan_interest in ('growing', 'basic', 'featured', 'unsure')),
  -- Decision 1 in section 15: team-maintained or self-edited.
  maintenance     text not null default 'unsure'
                    check (maintenance in ('team', 'self', 'unsure')),
  note            text check (note is null or length(note) <= 500),
  source          text not null default 'app' check (source in ('app', 'interview', 'import')),
  status          text not null default 'new'
                    check (status in ('new', 'contacted', 'trial', 'paying', 'declined')),
  team_note       text check (team_note is null or length(team_note) <= 500),
  business_id     uuid references public.businesses (id) on delete set null,
  submitted_by    uuid references auth.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists business_leads_status_idx on public.business_leads (status, created_at desc);

alter table public.business_leads enable row level security;

-- Anyone may submit, signed in or not; only the team reads and works them.
-- The submitter is taken from the session, never from the client.
create or replace function public.stamp_lead()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not coalesce(public.is_team_admin(), false) then
    new.submitted_by := auth.uid();
    new.source := 'app';
    new.status := 'new';
    new.team_note := null;
    new.business_id := null;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists stamp_lead on public.business_leads;
create trigger stamp_lead before insert or update on public.business_leads
  for each row execute function public.stamp_lead();

drop policy if exists business_leads_insert on public.business_leads;
create policy business_leads_insert on public.business_leads for insert
  with check (true);
drop policy if exists business_leads_team on public.business_leads;
create policy business_leads_team on public.business_leads for all
  using (coalesce(public.is_team_admin(), false))
  with check (coalesce(public.is_team_admin(), false));

grant insert on public.business_leads to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Pre-built (prospect) listings
-- ---------------------------------------------------------------------------

alter table public.businesses
  add column if not exists is_prospect boolean not null default false,
  add column if not exists preview_token uuid not null default gen_random_uuid();

-- Hidden from everyone but the people who administer it (the team).
drop policy if exists "businesses_select" on public.businesses;
create policy "businesses_select"
  on public.businesses for select
  using (
    (subscription_status <> 'delisted' and not is_prospect)
    or coalesce(public.administers(id), false)
  );

-- Only the team decides what is public.
create or replace function public.protect_prospect_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(public.is_team_admin(), false) then
    return new;
  end if;
  if new.is_prospect is distinct from old.is_prospect
     or new.preview_token is distinct from old.preview_token then
    raise exception 'Only the team can publish a listing' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_prospect_fields on public.businesses;
create trigger protect_prospect_fields before update on public.businesses
  for each row execute function public.protect_prospect_fields();

-- What the owner sees through the preview link, before anything is public.
-- The token is the only key: unguessable, and replaced by the team at will.
create or replace function public.prospect_preview(p_token uuid)
returns table (
  name text, category text, area text, description text,
  phone text, whatsapp text, photos jsonb
)
language sql
stable
security definer
set search_path = public
as $$
  select b.name, b.category, b.area, b.description, b.phone, b.whatsapp,
         b.photos::jsonb
    from public.businesses b
   where b.preview_token = p_token
     and b.is_prospect;
$$;

revoke all on function public.prospect_preview(uuid) from public;
grant execute on function public.prospect_preview(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Verification log
-- ---------------------------------------------------------------------------

create table if not exists public.listing_verifications (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  method      text not null check (method in ('visit', 'phone', 'owner')),
  note        text check (note is null or length(note) <= 300),
  verified_by uuid references auth.users (id) on delete set null,
  verified_at timestamptz not null default now()
);

create index if not exists listing_verifications_business_idx
  on public.listing_verifications (business_id, verified_at desc);

alter table public.listing_verifications enable row level security;

drop policy if exists listing_verifications_read on public.listing_verifications;
create policy listing_verifications_read on public.listing_verifications for select
  using (coalesce(public.administers(business_id), false));
revoke insert, update, delete on public.listing_verifications from anon, authenticated;

create or replace function public.verify_listing(
  p_business uuid,
  p_method text,
  p_note text default null
)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_at timestamptz := now();
begin
  if not coalesce(public.is_team_admin(), false) then
    raise exception 'Only the team verifies listings' using errcode = '42501';
  end if;
  if p_method not in ('visit', 'phone', 'owner') then
    raise exception 'Unknown method' using errcode = '22023';
  end if;
  insert into public.listing_verifications (business_id, method, note, verified_by, verified_at)
  values (p_business, p_method, nullif(btrim(coalesce(p_note, '')), ''), auth.uid(), v_at);
  update public.businesses set last_verified_at = v_at where id = p_business;
  return v_at;
end;
$$;

revoke all on function public.verify_listing(uuid, text, text) from public;
grant execute on function public.verify_listing(uuid, text, text) to anon, authenticated;
