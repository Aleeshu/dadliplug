-- Claim and verify a listing (plan.md Phase 7).
--
-- Anyone signed in can say "this is my business". Nothing changes until the
-- team has checked it, by calling the number already on the listing (not the
-- one the claimant typed: anyone can type their own number). Approving makes
-- the claimant a business admin of that listing; nothing else does.

create table if not exists public.listing_claims (
  id            uuid primary key default gen_random_uuid(),
  business_id   uuid not null references public.businesses (id) on delete cascade,
  user_id       uuid not null references auth.users (id) on delete cascade,
  contact_name  text not null check (length(btrim(contact_name)) between 1 and 80),
  contact_phone text not null check (length(btrim(contact_phone)) between 5 and 30),
  role_at_business text not null check (length(btrim(role_at_business)) between 1 and 60),
  note          text check (note is null or length(note) <= 500),
  status        text not null default 'pending'
                  check (status in ('pending', 'approved', 'rejected')),
  decision_note text check (decision_note is null or length(decision_note) <= 300),
  decided_by    uuid references auth.users (id),
  decided_at    timestamptz,
  created_at    timestamptz not null default now()
);

-- One open claim per person per listing.
create unique index if not exists listing_claims_one_pending
  on public.listing_claims (business_id, user_id) where status = 'pending';
create index if not exists listing_claims_pending_idx
  on public.listing_claims (created_at) where status = 'pending';

alter table public.listing_claims enable row level security;

-- The claimant sees their own; the team sees all. Writes only via functions.
drop policy if exists listing_claims_read on public.listing_claims;
create policy listing_claims_read on public.listing_claims for select
  using (user_id = auth.uid() or coalesce(public.is_team_admin(), false));
revoke insert, update, delete on public.listing_claims from anon, authenticated;

create or replace function public.request_claim(
  p_business uuid,
  p_name text,
  p_phone text,
  p_role text,
  p_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  claim_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Sign in to claim a listing' using errcode = '42501';
  end if;
  if not exists (select 1 from public.businesses where id = p_business) then
    raise exception 'No such listing' using errcode = 'P0002';
  end if;
  if exists (
    select 1 from public.profiles
     where id = auth.uid() and p_business = any (business_ids)
  ) then
    raise exception 'You already manage this listing' using errcode = '23505';
  end if;
  if exists (
    select 1 from public.listing_claims
     where business_id = p_business and user_id = auth.uid()
       and status = 'pending'
  ) then
    raise exception 'Your claim is already with the team' using errcode = '23505';
  end if;

  insert into public.listing_claims
    (business_id, user_id, contact_name, contact_phone, role_at_business, note)
  values
    (p_business, auth.uid(), btrim(p_name), btrim(p_phone), btrim(p_role),
     nullif(btrim(coalesce(p_note, '')), ''))
  returning id into claim_id;
  return claim_id;
end;
$$;

create or replace function public.decide_claim(
  p_claim uuid,
  p_approve boolean,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  c public.listing_claims;
begin
  if not coalesce(public.is_team_admin(), false) then
    raise exception 'Only the team can decide a claim' using errcode = '42501';
  end if;

  select * into c from public.listing_claims where id = p_claim for update;
  if not found then
    raise exception 'No such claim' using errcode = 'P0002';
  end if;
  if c.status <> 'pending' then
    raise exception 'This claim was already decided' using errcode = '23505';
  end if;

  update public.listing_claims
     set status = case when p_approve then 'approved' else 'rejected' end,
         decision_note = nullif(btrim(coalesce(p_note, '')), ''),
         decided_by = auth.uid(),
         decided_at = now()
   where id = p_claim;

  if p_approve then
    -- The profile guard lets this through because the caller is the team.
    -- A team admin who claims keeps their role and gains the listing.
    update public.profiles
       set role = case when role = 'user' then 'business_admin' else role end,
           business_ids = case
             when c.business_id = any (business_ids) then business_ids
             else array_append(business_ids, c.business_id)
           end
     where id = c.user_id;
  end if;
end;
$$;

revoke all on function public.request_claim(uuid, text, text, text, text) from public;
revoke all on function public.decide_claim(uuid, boolean, text) from public;
grant execute on function public.request_claim(uuid, text, text, text, text) to authenticated, anon;
grant execute on function public.decide_claim(uuid, boolean, text) to authenticated, anon;
