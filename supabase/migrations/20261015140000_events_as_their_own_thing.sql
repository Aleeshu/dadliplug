-- Events become their own listing, as in the Dadliplug design: an event has
-- its own picture, venue, tags, organiser and contact details, and its own
-- page. It is still posted by (and belongs to) a business, which stays
-- accountable for it, but the organiser shown can be someone else, e.g. a
-- festival committee using a venue's account.

alter table public.business_events
  add column if not exists image_url  text,
  add column if not exists latitude   double precision,
  add column if not exists longitude  double precision,
  add column if not exists tags       text[] not null default '{}',
  add column if not exists organizer  text,
  add column if not exists website    text,
  add column if not exists phone      text,
  -- Set by the team to put an event in Featured Events regardless of the
  -- posting business's plan.
  add column if not exists is_featured boolean not null default false;

-- Only the team decides what is featured. A business setting its own event
-- featured with the publishable key would be buying placement without paying.
create or replace function public.protect_event_featured()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if public.is_team_admin() then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.is_featured := false;
  elsif new.is_featured is distinct from old.is_featured then
    new.is_featured := old.is_featured;
  end if;
  return new;
end;
$$;

drop trigger if exists business_events_protect_featured on public.business_events;
create trigger business_events_protect_featured
  before insert or update on public.business_events
  for each row execute function public.protect_event_featured();

-- ---------------------------------------------------------------------------
-- Saved events
-- ---------------------------------------------------------------------------

create table if not exists public.event_saves (
  user_id    uuid not null references auth.users (id) on delete cascade,
  event_id   uuid not null references public.business_events (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, event_id)
);

alter table public.event_saves enable row level security;

drop policy if exists event_saves_own on public.event_saves;
create policy event_saves_own on public.event_saves for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, insert, delete on public.event_saves to authenticated;

-- The demo event gets the new details so the redesigned screens have
-- something real to show. Guarded on the demo name, as the seed is.
update public.business_events e
set tags = array['Food', 'Music'],
    organizer = coalesce(e.organizer, b.name),
    latitude = coalesce(e.latitude, b.latitude),
    longitude = coalesce(e.longitude, b.longitude)
from public.businesses b
where b.id = e.business_id and b.name like 'IslandAds Demo%';
