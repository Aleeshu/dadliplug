-- Book a Table (2026-10-28 redesign). A customer asks for a table; the
-- business confirms or declines; the customer can cancel. A business takes
-- bookings only if it switches them on (not every restaurant reserves).

alter table public.businesses
  add column if not exists accepts_bookings boolean not null default false;

create table if not exists public.bookings (
  id            uuid primary key default gen_random_uuid(),
  business_id   uuid not null references public.businesses (id) on delete cascade,
  customer_id   uuid not null references auth.users (id) on delete cascade,
  at            timestamptz not null,
  party_size    integer not null check (party_size between 1 and 30),
  name          text not null check (length(btrim(name)) between 1 and 80),
  phone         text not null check (length(btrim(phone)) between 5 and 30),
  note          text check (note is null or length(note) <= 300),
  status        text not null default 'pending'
                  check (status in ('pending', 'confirmed', 'declined', 'cancelled')),
  business_note text check (business_note is null or length(business_note) <= 300),
  created_at    timestamptz not null default now(),
  decided_at    timestamptz
);

create index if not exists bookings_business_idx on public.bookings (business_id, at);
create index if not exists bookings_customer_idx on public.bookings (customer_id, at desc);

alter table public.bookings enable row level security;

drop policy if exists bookings_read on public.bookings;
create policy bookings_read on public.bookings for select
  using (customer_id = auth.uid() or coalesce(public.administers(business_id), false));
revoke insert, update, delete on public.bookings from anon, authenticated;

create or replace function public.request_booking(
  p_business uuid,
  p_at timestamptz,
  p_party integer,
  p_name text,
  p_phone text,
  p_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Sign in to book' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.businesses
     where id = p_business and accepts_bookings
       and subscription_status <> 'delisted' and not is_prospect
  ) then
    raise exception 'This business is not taking bookings in the app' using errcode = '22023';
  end if;
  if p_at < now() + interval '30 minutes' then
    raise exception 'Choose a time at least 30 minutes from now' using errcode = '22023';
  end if;
  if p_at > now() + interval '60 days' then
    raise exception 'Bookings open up to 60 days ahead' using errcode = '22023';
  end if;
  if (select count(*) from public.bookings
       where business_id = p_business and customer_id = auth.uid()
         and status = 'pending') >= 3 then
    raise exception 'You already have 3 requests waiting with this business' using errcode = '22023';
  end if;
  insert into public.bookings (business_id, customer_id, at, party_size, name, phone, note)
  values (p_business, auth.uid(), p_at, p_party, btrim(p_name), btrim(p_phone),
          nullif(btrim(coalesce(p_note, '')), ''))
  returning id into v_id;
  return v_id;
end;
$$;

-- The business confirms or declines a pending booking.
create or replace function public.answer_booking(
  p_booking uuid,
  p_confirm boolean,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business uuid;
begin
  select business_id into v_business from public.bookings
   where id = p_booking and status = 'pending';
  if v_business is null or not coalesce(public.administers(v_business), false) then
    raise exception 'No such booking waiting' using errcode = 'P0002';
  end if;
  update public.bookings
     set status = case when p_confirm then 'confirmed' else 'declined' end,
         business_note = nullif(btrim(coalesce(p_note, '')), ''),
         decided_at = now()
   where id = p_booking;
end;
$$;

-- The customer cancels their own pending or confirmed booking.
create or replace function public.cancel_booking(p_booking uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.bookings
     set status = 'cancelled', decided_at = now()
   where id = p_booking
     and customer_id = auth.uid()
     and status in ('pending', 'confirmed');
  if not found then
    raise exception 'No such booking to cancel' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.request_booking(uuid, timestamptz, integer, text, text, text) from public;
revoke all on function public.answer_booking(uuid, boolean, text) from public;
revoke all on function public.cancel_booking(uuid) from public;
grant execute on function public.request_booking(uuid, timestamptz, integer, text, text, text) to anon, authenticated;
grant execute on function public.answer_booking(uuid, boolean, text) to anon, authenticated;
grant execute on function public.cancel_booking(uuid) to anon, authenticated;

-- The demo kitchen takes bookings, so the feature shows.
update public.businesses set accepts_bookings = true where name = 'IslandAds Demo Kitchen';
